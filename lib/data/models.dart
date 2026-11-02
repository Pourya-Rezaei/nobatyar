import 'package:flutter/material.dart';

import '../core/jalali.dart';

/// وضعیت نوبت
enum ApptStatus { pending, confirmed, done, canceled }

extension ApptStatusX on ApptStatus {
  String get label => switch (this) {
        ApptStatus.pending => 'در انتظار',
        ApptStatus.confirmed => 'تأیید شده',
        ApptStatus.done => 'انجام شده',
        ApptStatus.canceled => 'لغو شده',
      };
}

/// رنگ وضعیت متناسب با روشنایی تم
/// (در تم روشن ته‌رنگ‌های عمیق‌تر برای کنتراست بهتر استفاده می‌شود)
Color statusColor(Brightness b, ApptStatus s) => switch (s) {
      ApptStatus.pending =>
        b == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      ApptStatus.confirmed =>
        b == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      ApptStatus.done =>
        b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF059669),
      ApptStatus.canceled =>
        b == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    };

/// یک نوبت
class Appt {
  final String id;
  final String name; // نام مشتری
  final String phone; // شماره تماس (اختیاری)
  final String service; // نوع خدمت
  final int dateKey; // تاریخ شمسی به شکل yyyymmdd
  final int time; // دقیقه از نیمه‌شب
  final String note; // یادداشت
  final ApptStatus status;
  final int? price; // مبلغ نوبت به تومان (اختیاری — ثبت لحظه رزرو)
  final int createdAt; // میلی‌ثانیه

  const Appt({
    required this.id,
    required this.name,
    this.phone = '',
    required this.service,
    required this.dateKey,
    required this.time,
    this.note = '',
    this.status = ApptStatus.pending,
    this.price,
    this.createdAt = 0,
  });

  factory Appt.fromJson(Map<String, dynamic> j) => Appt(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        service: (j['service'] as String?) ?? '',
        dateKey: (j['dateKey'] as num?)?.toInt() ?? 0,
        time: (j['time'] as num?)?.toInt() ?? 0,
        note: (j['note'] as String?) ?? '',
        status: ApptStatus.values
                .where((s) => s.name == (j['status'] as String?))
                .firstOrNull ??
            ApptStatus.pending,
        price: (j['price'] as num?)?.toInt(),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'service': service,
        'dateKey': dateKey,
        'time': time,
        'note': note,
        'status': status.name,
        if (price != null) 'price': price,
        'createdAt': createdAt,
      };

  /// تاریخ شمسی نوبت
  Jalali get date => Jalali.fromKey(dateKey);

  Appt copyWith({
    String? name,
    String? phone,
    String? service,
    int? dateKey,
    int? time,
    String? note,
    ApptStatus? status,
    int? price,
    bool clearPrice = false,
  }) =>
      Appt(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        service: service ?? this.service,
        dateKey: dateKey ?? this.dateKey,
        time: time ?? this.time,
        note: note ?? this.note,
        status: status ?? this.status,
        price: clearPrice ? null : (price ?? this.price),
        createdAt: createdAt,
      );
}

/// نوع کسب‌وکار
enum BusinessType { beautyClinic, hairSalon, dentalClinic }

extension BusinessTypeX on BusinessType {
  String get label => switch (this) {
        BusinessType.beautyClinic => 'کلینیک زیبایی',
        BusinessType.hairSalon => 'آرایشگاه',
        BusinessType.dentalClinic => 'کلینیک دندان‌پزشکی',
      };

  IconData get icon => switch (this) {
        BusinessType.beautyClinic => Icons.face_retouching_natural,
        BusinessType.hairSalon => Icons.content_cut,
        BusinessType.dentalClinic => Icons.medical_services,
      };

  /// فهرست خدمات پیش‌فرض هر نوع کسب‌وکار (بدون قیمت)
  List<String> get defaultServiceNames => switch (this) {
        BusinessType.beautyClinic => const [
            'پاکسازی پوست',
            'لیزر موهای زائد',
            'میکاپ',
            'تزریق بوتاکس',
            'ژل و فیلر',
            'میکرونیدلینگ',
            'هیدرودرم',
            'لیفت با نخ',
          ],
        BusinessType.hairSalon => const [
            'اصلاح مو',
            'رنگ مو',
            'مش و لایت',
            'کوتاهی زنانه',
            'براشینگ',
            'شنیون',
            'خدمات ناخن',
            'اصلاح ریش',
          ],
        BusinessType.dentalClinic => const [
            'جرم‌گیری',
            'معاینه و مشاوره',
            'عصب‌کشی',
            'ترمیم کامپوزیت',
            'کشیدن دندان',
            'ایمپلنت',
            'ارتودنسی',
            'بلیچینگ',
          ],
      };

  /// فهرست خدمات پیش‌فرض به شکل مدل Service
  List<Service> get defaultServices =>
      defaultServiceNames.map((n) => Service(name: n)).toList();
}

/// یک خدمت قابل ارائه با قیمت پیش‌فرض اختیاری
class Service {
  final String name;
  final int? price; // تومان

  const Service({required this.name, this.price});

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        name: (j['name'] as String?) ?? '',
        price: (j['price'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, if (price != null) 'price': price};

  Service copyWith({String? name, int? price, bool clearPrice = false}) =>
      Service(
        name: name ?? this.name,
        price: clearPrice ? null : (price ?? this.price),
      );

  @override
  bool operator ==(Object other) =>
      other is Service &&
      other.name.trim() == name.trim() &&
      other.price == price;

  @override
  int get hashCode => Object.hash(name.trim(), price);
}

/// بازه زمانی غیرفعال (استراحت هفتگی یا تعطیلی تاریخ خاص)
/// weekDay مقدار داشته باشد یعنی هر هفته تکرار می‌شود (۰=شنبه … ۶=جمعه)؛
/// در غیر این صورت dateKey تاریخ مشخص تعطیلی است.
class TimeBlock {
  final String id;
  final int? weekDay;
  final int? dateKey;
  final int start; // دقیقه از نیمه‌شب
  final int end;

  const TimeBlock({
    required this.id,
    this.weekDay,
    this.dateKey,
    this.start = 0,
    this.end = 24 * 60,
  });

  bool get isWeekly => weekDay != null;
  bool get isFullDay => start <= 0 && end >= 24 * 60;

  /// آیا بازه [from, to) در این تاریخ با این بلاک تداخل دارد؟
  bool overlaps({required Jalali date, required int from, required int to}) {
    if (isWeekly) {
      if (date.weekDay != weekDay) return false;
    } else {
      if (dateKey == null || date.dateKey != dateKey) return false;
    }
    return from < end && to > start;
  }

  factory TimeBlock.fromJson(Map<String, dynamic> j) => TimeBlock(
        id: (j['id'] as String?) ?? '',
        weekDay: (j['weekDay'] as num?)?.toInt(),
        dateKey: (j['dateKey'] as num?)?.toInt(),
        start: (j['start'] as num?)?.toInt() ?? 0,
        end: (j['end'] as num?)?.toInt() ?? 24 * 60,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (weekDay != null) 'weekDay': weekDay,
        if (dateKey != null) 'dateKey': dateKey,
        'start': start,
        'end': end,
      };

  /// برچسب فارسی برای نمایش در فهرست
  String get label {
    final range = isFullDay
        ? 'کل روز'
        : '${faTime(start)} تا ${faTime(end)}';
    if (isWeekly) return '${kWeekDays[weekDay!]}، $range';
    final d = Jalali.fromKey(dateKey ?? 0);
    return '${d.fullText}، $range';
  }
}

/// حالت تم برنامه
enum AppThemeMode { system, dark, light }

extension AppThemeModeX on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.system => 'هماهنگ با سیستم',
        AppThemeMode.dark => 'تیره',
        AppThemeMode.light => 'روشن',
      };

  IconData get icon => switch (this) {
        AppThemeMode.system => Icons.brightness_auto,
        AppThemeMode.dark => Icons.dark_mode,
        AppThemeMode.light => Icons.light_mode,
      };
}

/// تنظیمات کسب‌وکار
class BizSettings {
  String name;
  BusinessType type;
  int dayStart; // دقیقه از نیمه‌شب
  int dayEnd;
  int slot; // مدت هر نوبت (دقیقه)

  /// فهرست خدمات قابل ارائه با قیمت پیش‌فرض
  List<Service> services;

  /// بازه‌های غیرفعال (استراحت/تعطیلی)
  List<TimeBlock> blocks;

  /// حالت تم برنامه
  AppThemeMode themeMode;

  /// یادآوری نوبت با نوتیفیکیشن
  bool notifyAppts;
  int reminderLead; // دقیقه قبل از نوبت

  /// خلاصه صبحگاهی نوبت‌های فردا
  bool morningSummary;
  int morningHour; // دقیقه از نیمه‌شب (پیش‌فرض ۸:۰۰)

  BizSettings({
    this.name = '',
    this.type = BusinessType.beautyClinic,
    this.dayStart = 9 * 60,
    this.dayEnd = 20 * 60,
    this.slot = 30,
    List<Service>? services,
    List<TimeBlock>? blocks,
    this.themeMode = AppThemeMode.system,
    this.notifyAppts = true,
    this.reminderLead = 60,
    this.morningSummary = true,
    this.morningHour = 8 * 60,
  })  : services = (services == null || services.isEmpty)
            ? type.defaultServices
            : services,
        blocks = blocks ?? [];

  factory BizSettings.fromJson(Map<String, dynamic> j) {
    final type = BusinessType.values
            .where((t) => t.name == (j['type'] as String?))
            .firstOrNull ??
        BusinessType.beautyClinic;
    final rawServices = j['services'];
    final services = rawServices is List
        ? rawServices
            .map((e) => Service.fromJson(e as Map<String, dynamic>))
            .where((s) => s.name.trim().isNotEmpty)
            .toList()
        : <Service>[];
    final rawBlocks = j['blocks'];
    final blocks = rawBlocks is List
        ? rawBlocks
            .map((e) => TimeBlock.fromJson(e as Map<String, dynamic>))
            .toList()
        : <TimeBlock>[];
    return BizSettings(
      name: (j['name'] as String?) ?? '',
      type: type,
      dayStart: (j['dayStart'] as num?)?.toInt() ?? 9 * 60,
      dayEnd: (j['dayEnd'] as num?)?.toInt() ?? 20 * 60,
      slot: (j['slot'] as num?)?.toInt() ?? 30,
      services: services.isEmpty ? type.defaultServices : services,
      blocks: blocks,
      themeMode: AppThemeMode.values
              .where((t) => t.name == (j['themeMode'] as String?))
              .firstOrNull ??
          AppThemeMode.system,
      notifyAppts: (j['notifyAppts'] as bool?) ?? true,
      reminderLead: (j['reminderLead'] as num?)?.toInt() ?? 60,
      morningSummary: (j['morningSummary'] as bool?) ?? true,
      morningHour: (j['morningHour'] as num?)?.toInt() ?? 8 * 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'dayStart': dayStart,
        'dayEnd': dayEnd,
        'slot': slot,
        'services': services.map((s) => s.toJson()).toList(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'themeMode': themeMode.name,
        'notifyAppts': notifyAppts,
        'reminderLead': reminderLead,
        'morningSummary': morningSummary,
        'morningHour': morningHour,
      };

  /// آیا فهرست خدمات فعلی همان پیش‌فرض نوع کسب‌وکار است؟
  bool get servicesAreDefault {
    final def = type.defaultServices;
    if (services.length != def.length) return false;
    for (var i = 0; i < services.length; i++) {
      if (services[i].name != def[i].name || services[i].price != null) {
        return false;
      }
    }
    return true;
  }

  /// بازه [from, to) در این تاریخ غیرفعال است؟
  bool isBlocked(Jalali date, int from, int to) =>
      blocks.any((b) => b.overlaps(date: date, from: from, to: to));

  /// آیا کل روز تعطیل است؟ (بلاک تمام‌روز)
  bool isDayOff(Jalali date) => blocks.any((b) =>
      (b.isWeekly ? date.weekDay == b.weekDay : date.dateKey == b.dateKey) &&
      b.isFullDay);

  BizSettings copyWith({
    String? name,
    BusinessType? type,
    int? dayStart,
    int? dayEnd,
    int? slot,
    List<Service>? services,
    List<TimeBlock>? blocks,
    AppThemeMode? themeMode,
    bool? notifyAppts,
    int? reminderLead,
    bool? morningSummary,
    int? morningHour,
  }) =>
      BizSettings(
        name: name ?? this.name,
        type: type ?? this.type,
        dayStart: dayStart ?? this.dayStart,
        dayEnd: dayEnd ?? this.dayEnd,
        slot: slot ?? this.slot,
        services: services ?? this.services,
        blocks: blocks ?? this.blocks,
        themeMode: themeMode ?? this.themeMode,
        notifyAppts: notifyAppts ?? this.notifyAppts,
        reminderLead: reminderLead ?? this.reminderLead,
        morningSummary: morningSummary ?? this.morningSummary,
        morningHour: morningHour ?? this.morningHour,
      );
}

/// متن یادآوری آماده برای ارسال به مشتری
String reminderText(Appt a, BizSettings s) {
  final biz = s.name.trim().isEmpty ? 'نوبت‌یار' : s.name.trim();
  final buf = StringBuffer()
    ..write('سلام ${a.name} عزیز\n')
    ..write('یادآوری نوبت ${a.service}')
    ..write('\nروز ${a.date.weekDayName} ${a.date.fullText} ساعت ${faTime(a.time)}');
  if (a.price != null && a.price! > 0) {
    buf.write('\nهزینه: ${faMoney(a.price!)} تومان');
  }
  buf.write('\nمحل: $biz\nلطفاً چند دقیقه قبل از ساعت مقرر حاضر باشید.');
  return buf.toString();
}

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
