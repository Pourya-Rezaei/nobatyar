import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/jalali.dart';

void main() {
  group('تقویم شمسی', () {
    test('نقاط مرجع معتبر', () {
      // نوروز ۱۴۰۴: ۲۱ مارس ۲۰۲۵ — جمعه
      final n1404 = jalaliFromDateTime(DateTime(2025, 3, 21));
      expect(n1404, const Jalali(1404, 1, 1));
      expect(n1404.weekDay, 6);
      expect(n1404.weekDayName, 'جمعه');

      // نوروز ۱۴۰۵: ۲۱ مارس ۲۰۲۶
      final n1405 = jalaliFromDateTime(DateTime(2026, 3, 21));
      expect(n1405, const Jalali(1405, 1, 1));

      // ۱۴۰۳ سال کبیسه است: اسفند ۳۰ روزه و با ۲۰ مارس ۲۰۲۵ برابر است
      final leapEnd = jalaliFromDateTime(DateTime(2025, 3, 20));
      expect(leapEnd, const Jalali(1403, 12, 30));
      // چرخه کبیسه‌های شمسی
      const leaps = [1375, 1379, 1383, 1387, 1391, 1395, 1399, 1403, 1408];
      for (final y in leaps) {
        expect(isJalaliLeap(y), isTrue, reason: '$y باید کبیسه باشد');
      }
      for (final y in [1374, 1376, 1400, 1404, 1405, 1406, 1407]) {
        expect(isJalaliLeap(y), isFalse, reason: '$y نباید کبیسه باشد');
      }
      expect(jalaliMonthLength(1403, 12), 30);
      expect(jalaliMonthLength(1404, 12), 29);
      expect(jalaliMonthLength(1405, 12), 29);

      // ۱ نوامبر ۲۰۲۶ = ۱۰ آبان ۱۴۰۵ — یکشنبه
      final d = jalaliFromDateTime(DateTime(2026, 11, 1));
      expect(d, const Jalali(1405, 8, 10));
      expect(d.weekDayName, 'یکشنبه');
    });

    test('رفت‌وبرگشت شمسی ↔ میلادی بدون خطا', () {
      var dt = DateTime(2020, 1, 1);
      final end = DateTime(2035, 12, 31);
      while (dt.isBefore(end)) {
        final j = jalaliFromDateTime(dt);
        final back = j.toDateTime();
        expect(back.year, dt.year, reason: '$dt → $j');
        expect(back.month, dt.month, reason: '$dt → $j');
        expect(back.day, dt.day, reason: '$dt → $j');
        dt = dt.add(const Duration(days: 1));
      }
    });

    test('طول ماه‌های شمسی', () {
      expect(jalaliMonthLength(1405, 1), 31);
      expect(jalaliMonthLength(1405, 6), 31);
      expect(jalaliMonthLength(1405, 7), 30);
      expect(jalaliMonthLength(1405, 11), 30);
      expect(jalaliMonthLength(1405, 12), 29);
    });

    test('کلید تاریخ و مرتب‌سازی', () {
      final a = const Jalali(1405, 8, 9);
      expect(a.dateKey, 14050809);
      expect(Jalali.fromKey(14050809), a);
      expect(a.isBefore(const Jalali(1405, 8, 10)), isTrue);
      expect(a.addDays(1), const Jalali(1405, 8, 10));
      // مهر ۳۰ روزه است: ۹ آبان منهای ۹ روز = ۳۰ مهر
      expect(a.addDays(-9), const Jalali(1405, 7, 30));
      // مرز سال کبیسه
      expect(const Jalali(1403, 12, 30).addDays(1), const Jalali(1404, 1, 1));
      expect(const Jalali(1404, 1, 1).addDays(-1), const Jalali(1403, 12, 30));
    });

    test('اعداد و ساعت فارسی', () {
      expect(faDigits('1405/08/09'), '۱۴۰۵/۰۸/۰۹');
      expect(enDigits('۰۹۱۲۳۴۵۶۷۸۹'), '09123456789');
      expect(faTime(9 * 60), '۰۹:۰۰');
      expect(faTime(16 * 60 + 30), '۱۶:۳۰');
      expect(faNum(1405), '۱۴۰۵');
    });

    test('برچسب روزهای نسبی', () {
      final today = const Jalali(1405, 8, 9);
      expect(relativeDayLabel(today, today), 'امروز');
      expect(relativeDayLabel(today.addDays(1), today), 'فردا');
      expect(relativeDayLabel(today.addDays(-1), today), 'دیروز');
      expect(relativeDayLabel(today.addDays(5), today), '');
    });
  });
}
