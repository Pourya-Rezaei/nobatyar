import 'package:flutter/material.dart';

/// وضعیت نوبت
enum ApptStatus { pending, confirmed, done, canceled }

extension ApptStatusX on ApptStatus {
  String get label => switch (this) {
        ApptStatus.pending => 'در انتظار',
        ApptStatus.confirmed => 'تأیید شده',
        ApptStatus.done => 'انجام شده',
        ApptStatus.canceled => 'لغو شده',
      };

  Color get color => switch (this) {
        ApptStatus.pending => const Color(0xFFFBBF24),
        ApptStatus.confirmed => const Color(0xFF60A5FA),
        ApptStatus.done => const Color(0xFF34D399),
        ApptStatus.canceled => const Color(0xFFF87171),
      };

  Color get softBg => color.withValues(alpha: 0.14);
}

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
        'createdAt': createdAt,
      };

  Appt copyWith({
    String? name,
    String? phone,
    String? service,
    int? dateKey,
    int? time,
    String? note,
    ApptStatus? status,
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

  /// فهرست خدمات پیش‌فرض هر نوع کسب‌وکار
  List<String> get services => switch (this) {
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
}

/// تنظیمات کسب‌وکار
class BizSettings {
  String name;
  BusinessType type;
  int dayStart; // دقیقه از نیمه‌شب
  int dayEnd;
  int slot; // مدت هر نوبت (دقیقه)

  BizSettings({
    this.name = '',
    this.type = BusinessType.beautyClinic,
    this.dayStart = 9 * 60,
    this.dayEnd = 20 * 60,
    this.slot = 30,
  });

  factory BizSettings.fromJson(Map<String, dynamic> j) => BizSettings(
        name: (j['name'] as String?) ?? '',
        type: BusinessType.values
                .where((t) => t.name == (j['type'] as String?))
                .firstOrNull ??
            BusinessType.beautyClinic,
        dayStart: (j['dayStart'] as num?)?.toInt() ?? 9 * 60,
        dayEnd: (j['dayEnd'] as num?)?.toInt() ?? 20 * 60,
        slot: (j['slot'] as num?)?.toInt() ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'dayStart': dayStart,
        'dayEnd': dayEnd,
        'slot': slot,
      };

  BizSettings copyWith({
    String? name,
    BusinessType? type,
    int? dayStart,
    int? dayEnd,
    int? slot,
  }) =>
      BizSettings(
        name: name ?? this.name,
        type: type ?? this.type,
        dayStart: dayStart ?? this.dayStart,
        dayEnd: dayEnd ?? this.dayEnd,
        slot: slot ?? this.slot,
      );
}
