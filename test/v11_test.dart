import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/data/app_data.dart';
import 'package:nobatyar/core/jalali.dart';
import 'package:nobatyar/data/models.dart';
import 'package:nobatyar/data/storage.dart';
import 'package:nobatyar/services/backup_service.dart';

void main() {
  group('قالب‌بندی پول', () {
    test('جداکننده هزارگان', () {
      expect(faMoney(0), '۰');
      expect(faMoney(45000), '۴۵,۰۰۰');
      expect(faMoney(450000), '۴۵۰,۰۰۰');
      expect(faMoney(1200000), '۱,۲۰۰,۰۰۰');
      expect(faMoney(2500000), '۲,۵۰۰,۰۰۰');
    });
  });

  group('بلاک‌های زمانی', () {
    final day = Jalali(1405, 8, 12); // چهارشنبه (weekDay=3)
    final blocks = [
      TimeBlock(
        id: 'lunch',
        weekDay: 3, // چهارشنبه‌ها
        start: 13 * 60,
        end: 14 * 60,
      ),
      TimeBlock(
        id: 'holiday',
        dateKey: 14050813,
        start: 0,
        end: 24 * 60,
      ),
    ];

    test('بازه استراحت هفتگی فقط روز خودش را می‌بندد', () {
      expect(blocks[0].overlaps(date: day, from: 13 * 60, to: 13 * 60 + 30), isTrue);
      expect(blocks[0].overlaps(date: day, from: 12 * 60, to: 12 * 60 + 30), isFalse);
      expect(blocks[0].overlaps(date: day, from: 14 * 60, to: 14 * 60 + 30), isFalse);
      // پنجشنبه (weekDay=4) بلاک نمی‌شود
      expect(
        blocks[0].overlaps(date: Jalali(1405, 8, 13), from: 13 * 60, to: 14 * 60),
        isFalse,
      );
    });

    test('تعطیلی تاریخ خاص کل روز را می‌بندد', () {
      final d = Jalali.fromKey(14050813);
      expect(blocks[1].overlaps(date: d, from: 9 * 60, to: 10 * 60), isTrue);
      expect(blocks[1].isFullDay, isTrue);
    });

    test('slotsFor بازه‌های بلاک‌شده را حذف می‌کند', () {
      final data = AppData(MemoryStore(
        settings: BizSettings(blocks: [
          TimeBlock(
              id: 'lunch', weekDay: day.weekDay, start: 13 * 60, end: 14 * 60),
        ]),
      ));
      final slots = data.slotsFor(day);
      expect(slots, isNot(contains(13 * 60)));
      expect(slots, contains(12 * 60 + 30));
      expect(slots, contains(14 * 60));
    });

    test('isDayOff فقط برای بلاک تمام‌روز', () {
      final s = BizSettings(blocks: [
        TimeBlock(
            id: 'lunch', weekDay: 3, start: 13 * 60, end: 14 * 60),
        TimeBlock(id: 'off', dateKey: 14050813),
      ]);
      expect(s.isDayOff(day), isFalse); // فقط ناهار بلاک است
      expect(s.isDayOff(Jalali.fromKey(14050813)), isTrue);
    });
  });

  group('درآمد', () {
    late AppData data;
    final today = todayJalali();

    setUp(() {
      data = AppData(MemoryStore(seed: [
        Appt(
            id: '1',
            name: 'آ',
            service: 'س',
            dateKey: today.dateKey,
            time: 9 * 60,
            status: ApptStatus.done,
            price: 100000),
        Appt(
            id: '2',
            name: 'ب',
            service: 'س',
            dateKey: today.dateKey,
            time: 10 * 60,
            status: ApptStatus.confirmed,
            price: 200000),
        Appt(
            id: '3',
            name: 'ج',
            service: 'س',
            dateKey: today.dateKey,
            time: 11 * 60,
            status: ApptStatus.canceled,
            price: 50000),
        Appt(
            id: '4',
            name: 'د',
            service: 'س',
            dateKey: today.dateKey,
            time: 12 * 60,
            status: ApptStatus.done), // بدون قیمت
      ]));
    });

    test('درآمد روز فقط نوبت‌های انجام‌شده', () {
      expect(data.dayIncome(today.dateKey), 100000);
      expect(data.dayExpected(today.dateKey), 200000);
    });

    test('درآمد ماه', () {
      expect(data.monthIncome(today.dateKey ~/ 100), 100000);
      expect(data.monthCount(today.dateKey ~/ 100), 4);
    });
  });

  group('مشتریان', () {
    test('گروه‌بندی بر اساس شماره تماس', () {
      final today = todayJalali();
      final data = AppData(MemoryStore(seed: [
        Appt(
            id: '1',
            name: 'سارا',
            phone: '09121111111',
            service: 'س',
            dateKey: today.dateKey,
            time: 9 * 60,
            status: ApptStatus.done,
            price: 100),
        Appt(
            id: '2',
            name: 'سارا محمدی',
            phone: '09121111111',
            service: 'س',
            dateKey: today.addDays(-7).dateKey,
            time: 10 * 60,
            status: ApptStatus.done,
            price: 200),
        Appt(
            id: '3',
            name: 'سارا',
            service: 'س', // بدون شماره — بر اساس نام جدا گروه می‌شود
            dateKey: today.dateKey,
            time: 11 * 60),
      ]));

      final customers = data.customers;
      expect(customers.length, 2);

      final withPhone =
          customers.firstWhere((c) => c.phone == '09121111111');
      expect(withPhone.appts.length, 2);
      expect(withPhone.doneCount, 2);
      expect(withPhone.totalSpent, 300);
      expect(withPhone.lastVisit!.id, '1');
    });
  });

  group('مهاجرت و پشتیبان', () {
    test('خواندن تنظیمات قدیمی (نسخه ۱) — بدون services/blocks', () {
      final s = BizSettings.fromJson({
        'name': 'کلینیک رز',
        'type': 'hairSalon',
        'dayStart': 600,
        'dayEnd': 1200,
        'slot': 45,
      });
      expect(s.name, 'کلینیک رز');
      expect(s.type, BusinessType.hairSalon);
      expect(s.services.length, 8); // پیش‌فرض آرایشگاه
      expect(s.services.first.name, 'اصلاح مو');
      expect(s.blocks, isEmpty);
      expect(s.themeMode, AppThemeMode.system);
      expect(s.notifyAppts, isTrue);
      expect(s.reminderLead, 60);
    });

    test('round-trip پشتیبان: خروجی ← بازگردانی', () {
      final src = AppData(MemoryStore(
        settings: BizSettings(name: 'کلینیک رز', slot: 45),
        seed: [
          Appt(
              id: 'x1',
              name: 'سارا',
              phone: '09120000000',
              service: 'پاکسازی',
              dateKey: 14050810,
              time: 9 * 60,
              status: ApptStatus.done,
              price: 450000),
        ],
      ));

      final exported = src.backupMap();
      expect(exported['app'], 'nobatyar');
      expect(exported['format'], 2);

      final dst = AppData(MemoryStore());
      dst.applyBackup(BackupService.validateBackup(exported));
      expect(dst.appts.length, 1);
      expect(dst.appts.first.price, 450000);
      expect(dst.settings.name, 'کلینیک رز');
      expect(dst.settings.slot, 45);
    });

    test('رد فایل نامعتبر', () {
      expect(
        () => BackupService.validateBackup({'app': 'other'}),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => BackupService.validateBackup(
            {'app': 'nobatyar', 'appointments': 'x'}),
        throwsA(isA<BackupException>()),
      );
      // تاریخ و ساعت خارج از محدوده رد می‌شود
      expect(
        () => BackupService.validateBackup({
          'app': 'nobatyar',
          'format': 2,
          'settings': BizSettings().toJson(),
          'appointments': [
            {'id': '1', 'name': 'a', 'service': 's', 'dateKey': 99999999, 'time': 5}
          ],
        }),
        throwsA(isA<BackupException>()),
      );
    });

    test('سرویس‌های پیش‌فرض پس از تغییر نوع', () {
      final app = AppData(MemoryStore(
          settings: BizSettings(type: BusinessType.beautyClinic)));
      expect(app.settings.servicesAreDefault, isTrue);

      // شبیه تغییر نوع در تنظیمات
      final s = app.settings;
      app.updateSettings(s.copyWith(
        type: BusinessType.dentalClinic,
        services: s.servicesAreDefault
            ? BusinessType.dentalClinic.defaultServices
            : s.services,
      ));
      expect(app.settings.services.first.name, 'جرم‌گیری');
    });
  });

  group('متن یادآوری', () {
    test('شامل تاریخ، ساعت و قیمت', () {
      final s = BizSettings(name: 'کلینیک رز');
      final a = Appt(
        id: '1',
        name: 'سارا',
        phone: '09120000000',
        service: 'پاکسازی پوست',
        dateKey: 14050812,
        time: 9 * 60 + 30,
        status: ApptStatus.confirmed,
        price: 450000,
      );
      final t = reminderText(a, s);
      expect(t, contains('سارا'));
      expect(t, contains('پاکسازی پوست'));
      expect(t, contains('۰۹:۳۰'));
      expect(t, contains('۴۵۰,۰۰۰ تومان'));
      expect(t, contains('کلینیک رز'));
    });
  });

  group('مدل داده', () {
    test('Appt با/بدون قیمت در JSON', () {
      final withPrice = Appt(
              id: '1', name: 'a', service: 's', dateKey: 1, time: 0, price: 5)
          .toJson();
      expect(withPrice['price'], 5);

      final noPrice =
          Appt(id: '1', name: 'a', service: 's', dateKey: 1, time: 0).toJson();
      expect(noPrice.containsKey('price'), isFalse);

      final restored = Appt.fromJson({
        'id': '1',
        'name': 'a',
        'service': 's',
        'dateKey': 1,
        'time': 0,
      });
      expect(restored.price, isNull);
    });

    test('Service equality برای تشخیص پیش‌فرض', () {
      const a = Service(name: 'پاکسازی پوست');
      const b = Service(name: ' پاکسازی پوست '); // فاصله اضافه نادیده گرفته می‌شود
      expect(a == b, isTrue);
      expect(const Service(name: 'x', price: 1) == const Service(name: 'x'), isFalse);
    });
  });
}
