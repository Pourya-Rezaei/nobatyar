import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'jalali.dart';
import 'notification_service.dart';
import 'storage.dart';

/// پرونده مشتری: همه نوبت‌های یک نفر (گروه‌بندی بر اساس شماره تماس یا نام)
class CustomerProfile {
  final String key;
  final String name;
  final String phone;
  final List<Appt> appts; // جدیدترین اول

  const CustomerProfile({
    required this.key,
    required this.name,
    required this.phone,
    required this.appts,
  });

  int get doneCount =>
      appts.where((a) => a.status == ApptStatus.done).length;

  int get totalSpent => appts
      .where((a) => a.status == ApptStatus.done)
      .fold<int>(0, (sum, a) => sum + (a.price ?? 0));

  Appt? get lastVisit {
    for (final a in appts) {
      if (a.status == ApptStatus.done) return a;
    }
    return null;
  }
}

/// وضعیت مرکزی اپلیکیشن؛ هر تغییری در داده‌ها همه صفحه‌ها را به‌روز می‌کند
class AppData extends ChangeNotifier {
  final AppStore store;

  AppData(this.store);

  List<Appt> get appts => store.appointments;
  BizSettings get settings => store.settings;

  // ---------------------------------------------------------------
  // نوبت‌ها

  void addAppt(Appt a) {
    store.appointments.add(a);
    unawaited(store.saveAppts());
    _syncReminder(a);
    _syncMorningSummary();
    notifyListeners();
  }

  void updateAppt(Appt a) {
    final i = store.appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) store.appointments[i] = a;
    unawaited(store.saveAppts());
    _syncReminder(a);
    _syncMorningSummary();
    notifyListeners();
  }

  void removeAppt(String id) {
    store.appointments.removeWhere((x) => x.id == id);
    unawaited(store.saveAppts());
    unawaited(NotificationService.instance.cancelApptReminder(id));
    _syncMorningSummary();
    notifyListeners();
  }

  void clearAll() {
    store.appointments.clear();
    unawaited(store.saveAppts());
    unawaited(NotificationService.instance.rescheduleAll(this));
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // تنظیمات

  void updateSettings(BizSettings s) {
    store.settings = s;
    unawaited(store.saveSettings());
    // تنظیمات یادآوری/نام/قیمت‌ها ممکن است متن و زمان یادآوری‌ها را تغییر دهد
    unawaited(NotificationService.instance.rescheduleAll(this));
    notifyListeners();
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
  // مشتریان

  /// گروه‌بندی نوبت‌ها بر اساس مشتری؛ کلید = شماره تماس یا نام
  List<CustomerProfile> get customers {
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
  // پشتیبان‌گیری و بازگردانی

  /// خروجی JSON کامل داده‌ها
  Map<String, dynamic> exportJson() => {
        'app': 'nobatyar',
        'format': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'appointments': appts.map((a) => a.toJson()).toList(),
      };

  /// بازگردانی از JSON پشتیبان؛ خروجی پیام خطا یا null در صورت موفقیت
  String? importJson(Map<String, dynamic> j) {
    if (j['app'] != 'nobatyar') return 'این فایل پشتیبان نوبت‌یار نیست.';
    final rawAppts = j['appointments'];
    if (rawAppts is! List) return 'ساختار فایل پشتیبان معتبر نیست.';
    final rawSettings = j['settings'];
    if (rawSettings is! Map<String, dynamic>) {
      return 'ساختار فایل پشتیبان معتبر نیست.';
    }

    final restored = <Appt>[];
    for (final e in rawAppts) {
      if (e is! Map<String, dynamic>) continue;
      final a = Appt.fromJson(e);
      if (a.id.isNotEmpty && a.dateKey > 0) restored.add(a);
    }

    store.appointments
      ..clear()
      ..addAll(restored);
    store.settings = BizSettings.fromJson(rawSettings);
    unawaited(store.saveAppts());
    unawaited(store.saveSettings());
    unawaited(NotificationService.instance.rescheduleAll(this));
    notifyListeners();
    return null;
  }
}
