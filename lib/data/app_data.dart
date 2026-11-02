import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/jalali.dart';
import '../services/notification_service.dart';
import 'models.dart';
import 'storage.dart';

/// وضعیت مرکزی اپلیکیشن (ChangeNotifier).
///
/// مسئولیت‌ها:
///  - نگهداری نوبت‌ها و تنظیمات روی [store] (لایه ذخیره‌سازی)
///  - همگام‌سازی یادآوری‌های نوتیفیکیشن با تغییرات داده
///  - محاسبات سبک آماری + کش مشتقات پرتکرار
///
/// فرمت فایل پشتیبان و رمزنگاری آن در `services/backup_service.dart` است.
class AppData extends ChangeNotifier {
  final AppStore store;

  AppData(this.store);

  List<Appt> get appts => store.appointments;
  BizSettings get settings => store.settings;

  /// نوتیفایر جداگانهٔ تم — فقط با تغییر واقعی تم فعال می‌شود تا
  /// کل MaterialApp (و ساخت هر دو تم) با هر تغییر داده بازسازی نشود.
  final ChangeNotifier theme = ChangeNotifier();

  // ---------------------------------------------------------------
  // کش مشتقات — با هر تغییر داده بی‌اعتبار می‌شود

  List<CustomerProfile>? _customersCache;

  /// گروه‌بندی مشتریان؛ کش‌شده تا در هر build بازمحاسبه نشود
  List<CustomerProfile> get customers =>
      _customersCache ??= _computeCustomers();

  List<CustomerProfile> _computeCustomers() {
    final groups = <String, List<Appt>>{};
    final names = <String, String>{};
    final phones = <String, String>{};
    for (final a in appts) {
      final hasPhone = a.phone.trim().isNotEmpty;
      final key = hasPhone ? 'p:${a.phone.trim()}' : 'n:${a.name.trim()}';
      groups.putIfAbsent(key, () => []).add(a);
      names[key] = a.name;
      if (hasPhone) phones[key] = a.phone.trim();
    }
    final out = <CustomerProfile>[];
    groups.forEach((key, list) {
      list.sort((a, b) {
        final c = b.dateKey.compareTo(a.dateKey);
        return c != 0 ? c : b.time.compareTo(a.time);
      });
      out.add(CustomerProfile(
        key: key,
        name: names[key] ?? '',
        phone: phones[key] ?? '',
        appts: list,
      ));
    });
    // بیشترین مراجعه اول
    out.sort((a, b) {
      final c = b.appts.length.compareTo(a.appts.length);
      if (c != 0) return c;
      return (b.lastVisit?.dateKey ?? 0).compareTo(a.lastVisit?.dateKey ?? 0);
    });
    return out;
  }

  CustomerProfile? customerByKey(String key) {
    for (final c in customers) {
      if (c.key == key) return c;
    }
    return null;
  }

  void _invalidate() {
    _customersCache = null;
  }

  // ---------------------------------------------------------------
  // نوبت‌ها

  void addAppt(Appt a) {
    store.appointments.add(a);
    _invalidate();
    unawaited(store.saveAppts());
    _syncReminder(a);
    _syncMorningSummary();
    notifyListeners();
  }

  void updateAppt(Appt a) {
    final i = store.appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) store.appointments[i] = a;
    _invalidate();
    unawaited(store.saveAppts());
    _syncReminder(a);
    _syncMorningSummary();
    notifyListeners();
  }

  void removeAppt(String id) {
    store.appointments.removeWhere((x) => x.id == id);
    _invalidate();
    unawaited(store.saveAppts());
    unawaited(NotificationService.instance.cancelApptReminder(id));
    _syncMorningSummary();
    notifyListeners();
  }

  void clearAll() {
    store.appointments.clear();
    _invalidate();
    unawaited(store.saveAppts());
    _resyncRemindersNow();
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // تنظیمات

  void updateSettings(BizSettings s) {
    final old = store.settings;
    store.settings = s;
    _invalidate(); // نام/خدمات/قیمت‌ها در متن‌ها دیده می‌شوند
    unawaited(store.saveSettings());
    if (s.themeMode != old.themeMode) theme.notifyListeners();
    // چیدمان دوبارهٔ اعلان‌ها با تأخیر کوتاه انجام می‌شود تا
    // تایپ پیوسته (مثلاً ویرایش نام کسب‌وکار) کار اضافه ایجاد نکند
    _scheduleResync();
    notifyListeners();
  }

  Timer? _resyncDebounce;

  void _scheduleResync() {
    _resyncDebounce?.cancel();
    _resyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(NotificationService.instance.rescheduleAll(this));
    });
  }

  void _resyncRemindersNow() {
    _resyncDebounce?.cancel();
    unawaited(NotificationService.instance.rescheduleAll(this));
  }

  @override
  void dispose() {
    _resyncDebounce?.cancel();
    theme.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // یادآوری‌ها

  void _syncReminder(Appt a) =>
      unawaited(NotificationService.instance.scheduleApptReminder(a, settings));

  void _syncMorningSummary() =>
      unawaited(NotificationService.instance.scheduleMorningSummary(this));

  // ---------------------------------------------------------------
  // آمار و درآمد

  /// نوبت‌های یک روز به ترتیب ساعت
  List<Appt> apptsOfDay(int dateKey) {
    final list = appts.where((a) => a.dateKey == dateKey).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// درآمد واقعی یک روز (جمع نوبت‌های انجام‌شده دارای قیمت)
  int dayIncome(int dateKey) => apptsOfDay(dateKey)
      .where((a) => a.status == ApptStatus.done)
      .fold<int>(0, (sum, a) => sum + (a.price ?? 0));

  /// درآمد موردانتظار یک روز (نوبت‌های انجام‌نشده دارای قیمت)
  int dayExpected(int dateKey) => apptsOfDay(dateKey)
      .where((a) =>
          a.status == ApptStatus.pending || a.status == ApptStatus.confirmed)
      .fold<int>(0, (sum, a) => sum + (a.price ?? 0));

  /// درآمد واقعی یک ماه شمسی (monthKey به شکل yyyymm)
  int monthIncome(int monthKey) => appts
      .where((a) =>
          a.status == ApptStatus.done &&
          a.price != null &&
          a.dateKey ~/ 100 == monthKey)
      .fold<int>(0, (sum, a) => sum + a.price!);

  /// تعداد نوبت‌های یک ماه شمسی
  int monthCount(int monthKey) =>
      appts.where((a) => a.dateKey ~/ 100 == monthKey).length;

  /// کل درآمد ثبت‌شده
  int get totalIncome => appts
      .where((a) => a.status == ApptStatus.done)
      .fold<int>(0, (sum, a) => sum + (a.price ?? 0));

  // ---------------------------------------------------------------
  // بلاک‌ها و اسلات‌ها

  /// بازه‌های زمانی قابل رزرو برای یک روز (با احتساب تعطیلی‌ها)
  List<int> slotsFor(Jalali date) {
    final s = settings;
    final out = <int>[];
    if (s.slot <= 0 || s.dayEnd <= s.dayStart) return out;
    for (var t = s.dayStart; t + s.slot <= s.dayEnd; t += s.slot) {
      if (!s.isBlocked(date, t, t + s.slot)) out.add(t);
    }
    return out;
  }

  // ---------------------------------------------------------------
  // پشتیبان‌گیری (ساخت/اعمال داده — فرمت و رمز در BackupService)

  /// نقشهٔ کامل داده‌ها برای خروجی پشتیبان
  Map<String, dynamic> backupMap() => {
        'app': 'nobatyar',
        'format': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'appointments': appts.map((a) => a.toJson()).toList(),
      };

  /// اعمال پشتیبانِ از پیش اعتبارسنجی‌شده (توسط BackupService.readBackup).
  /// داده‌های فعلی کاملاً جایگزین می‌شوند.
  void applyBackup(Map<String, dynamic> j) {
    final restored = <Appt>[];
    for (final e in j['appointments'] as List) {
      restored.add(Appt.fromJson(e as Map<String, dynamic>));
    }
    store.appointments
      ..clear()
      ..addAll(restored);
    store.settings =
        BizSettings.fromJson(j['settings'] as Map<String, dynamic>);
    _invalidate();
    unawaited(store.saveAppts());
    unawaited(store.saveSettings());
    _resyncRemindersNow();
    notifyListeners();
  }
}
