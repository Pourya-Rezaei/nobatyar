import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/data/app_data.dart';
import 'package:nobatyar/data/models.dart';
import 'package:nobatyar/data/storage.dart';
import 'package:nobatyar/services/backup_service.dart';

/// تست‌های امنیتی پشتیبان: رمزنگاری AES-256-GCM، تشخیص فرمت
/// و اعتبارسنجی ساختاری
void main() {
  Map<String, dynamic> sampleBackup() => {
        'app': 'nobatyar',
        'format': 2,
        'exportedAt': '2026-11-02T10:00:00.000',
        'settings': BizSettings(name: 'کلینیک رز', slot: 45).toJson(),
        'appointments': [
          Appt(
            id: 'x1',
            name: 'سارا',
            phone: '09120000000',
            service: 'پاکسازی',
            dateKey: 14050810,
            time: 9 * 60,
            status: ApptStatus.done,
            price: 450000,
          ).toJson(),
        ],
      };

  group('رمزنگاری پشتیبان', () {
    test('round-trip رمزدار: ساخت ← خواندن با رمز درست', () async {
      final map = sampleBackup();
      final bytes = await BackupService.encodeEncrypted(map, 'pass1234');

      // فرمت ظرف: چهار بایت ابتدایی NBK1
      expect(BackupService.isEncrypted(bytes), isTrue);
      expect(String.fromCharCodes(bytes.take(4)), 'NBK1');
      // متن اصلی در فایل رمزدار دیده نمی‌شود
      expect(utf8.decode(bytes, allowMalformed: true).contains('سارا'), isFalse);

      final restored = await BackupService.readBackup(bytes, 'pass1234');
      expect(restored['app'], 'nobatyar');
      expect((restored['appointments'] as List).length, 1);
      expect(restored['settings']['name'], 'کلینیک رز');
    });

    test('رمز غلط رد می‌شود', () async {
      final bytes = await BackupService.encodeEncrypted(sampleBackup(), 'right-password');
      expect(
        () => BackupService.readBackup(bytes, 'wrong-password'),
        throwsA(isA<BackupException>()),
      );
    });

    test('فایل رمزدار بدون رمز رد می‌شود', () async {
      final bytes = await BackupService.encodeEncrypted(sampleBackup(), 'pass1234');
      expect(
        () => BackupService.readBackup(bytes, null),
        throwsA(isA<BackupException>()),
      );
    });

    test('salt تصادفی: دو خروجی یکسان بایت‌به‌بایت متفاوت‌اند', () async {
      final a = await BackupService.encodeEncrypted(sampleBackup(), 'p');
      final b = await BackupService.encodeEncrypted(sampleBackup(), 'p');
      expect(a.length, b.length);
      expect(a, isNot(equals(b)));
    });

    test('فایل سادهٔ JSON خوانده می‌شود (سازگاری نسخه‌های قبل)', () async {
      final jsonStr = BackupService.encodePlain(sampleBackup());
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      expect(BackupService.isEncrypted(bytes), isFalse);

      final restored = await BackupService.readBackup(bytes, null);
      expect(restored['app'], 'nobatyar');
    });

    test('فایل رمزدار خراب رد می‌شود', () async {
      final bytes =
          await BackupService.encodeEncrypted(sampleBackup(), 'pass1234');
      // خراب‌کاری بخشی از متن رمز
      bytes[bytes.length - 1] ^= 0xFF;
      expect(
        () => BackupService.readBackup(bytes, 'pass1234'),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('اعتبارسنجی ساختاری', () {
    test('مبلغ نامعتبر رد می‌شود', () {
      final map = sampleBackup();
      (map['appointments'] as List).first['price'] = -5;
      expect(
        () => BackupService.validateBackup(map),
        throwsA(isA<BackupException>()),
      );
    });

    test('ساعت خارج از روز رد می‌شود', () {
      final map = sampleBackup();
      (map['appointments'] as List).first['time'] = 25 * 60;
      expect(
        () => BackupService.validateBackup(map),
        throwsA(isA<BackupException>()),
      );
    });

    test('تنظیمات نامعتبر رد می‌شود', () {
      final map = sampleBackup();
      map['settings']['slot'] = 0;
      expect(
        () => BackupService.validateBackup(map),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('اعمال پشتیبان روی داده', () {
    test('applyBackup داده‌ها را کامل جایگزین می‌کند', () {
      final map = sampleBackup();
      final app = AppData(MemoryStore(seed: [
        Appt(
            id: 'old',
            name: 'قدیمی',
            service: 's',
            dateKey: 14050101,
            time: 10),
      ]));

      app.applyBackup(BackupService.validateBackup(map));
      expect(app.appts.length, 1);
      expect(app.appts.first.id, 'x1');
      expect(app.settings.name, 'کلینیک رز');

      // کش مشتریان هم تازه شده باشد
      expect(app.customers.first.name, 'سارا');
    });
  });
}
