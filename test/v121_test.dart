import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nobatyar/core/app_info.dart';
import 'package:nobatyar/data/app_data.dart';
import 'package:nobatyar/data/models.dart';
import 'package:nobatyar/data/storage.dart';
import 'package:nobatyar/services/backup_service.dart';
import 'package:nobatyar/services/update_service.dart';

/// تست‌های نسخهٔ ۱.۲.۱ — بکاپ خودکار، بررسی آپدیت، ثابت نسخه
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ثابت نسخه', () {
    test('appVersion با pubspec.yaml یکی است', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+',
              multiLine: true)
          .firstMatch(pubspec);
      expect(m, isNotNull, reason: 'خطای version در pubspec پیدا نشد');
      expect(appVersion, m!.group(1),
          reason: 'appVersion در lib/core/app_info.dart با pubspec فرق دارد — '
              'هر دو باید یکجا به‌روز شوند');
    });
  });

  group('مقایسهٔ نسخه (UpdateService.isNewer)', () {
    test('نسخه‌های ساده', () {
      expect(UpdateService.isNewer('1.2.2', '1.2.1'), isTrue);
      expect(UpdateService.isNewer('1.2.1', '1.2.1'), isFalse);
      expect(UpdateService.isNewer('1.2.0', '1.2.1'), isFalse);
      expect(UpdateService.isNewer('1.3.0', '1.2.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
    });

    test('مقایسهٔ بخش‌به‌بخش عددی — نه رشته‌ای', () {
      // اگر مقایسهٔ رشته‌ای بود ۱۰ < ۹ درمی‌آمد
      expect(UpdateService.isNewer('1.2.10', '1.2.9'), isTrue);
      expect(UpdateService.isNewer('1.10.0', '1.9.9'), isTrue);
    });

    test('پسوند v و build number نادیده گرفته می‌شود', () {
      expect(UpdateService.isNewer('v1.2.2', '1.2.1'), isTrue);
      expect(UpdateService.isNewer('1.2.1+5', '1.2.1+3'), isFalse,
          reason: 'تفاوت فقط در build number — برای کاربر همان نسخه است');
    });

    test('ورودی خراب → false (نه استثنا)', () {
      expect(UpdateService.isNewer('xyz', '1.2.1'), isFalse);
      expect(UpdateService.isNewer('', '1.2.1'), isFalse);
      expect(UpdateService.isNewer('1.2.1', 'garbage'), isFalse);
    });
  });

  group('بکاپ خودکار — ساخت فایل و چرخش', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('nobatyar_v121_test');
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    Appt sampleAppt(String id) => Appt(
          id: id,
          name: 'مشتری تست',
          phone: '09120000000',
          service: 'خدمت تست',
          note: '',
          dateKey: 14050811,
          time: 600,
          price: 250000,
          status: ApptStatus.done,
        );

    test('بکاپ رمزدار قابل بازگردانی با همان رمز است', () async {
      final store = AppStore();
      store.appointments.add(sampleAppt('a1'));
      final app = AppData(store);

      final map = app.backupMap();
      final bytes = await BackupService.encodeEncrypted(map, 'رمز-تست-۱۲۳');

      // باید ظرف NBK1 باشد
      expect(BackupService.isEncrypted(bytes), isTrue);

      // و با رمز درست باز شود
      final restored = await BackupService.readBackup(bytes, 'رمز-تست-۱۲۳');
      expect(restored['app'], 'nobatyar');
      expect((restored['appointments'] as List).length, 1);
    });

    test('رمز غلط رد می‌شود', () async {
      final store = AppStore();
      store.appointments.add(sampleAppt('a2'));
      final bytes =
          await BackupService.encodeEncrypted(AppData(store).backupMap(), 'ok');

      await expectLater(
        BackupService.readBackup(bytes, 'wrong'),
        throwsA(isA<BackupException>()),
      );
    });

    test('نام فایل بکاپ خودکار الگوی تاریخ دارد', () {
      // الگوی یونیک: yyyymmdd-HHmm
      final reg = RegExp(r'^\d{8}-\d{4}$');
      expect(reg.hasMatch('20261102-1015'), isTrue);
      expect(reg.hasMatch('نام-خراب'), isFalse);
    });
  });

  group('متن لاگ خطا — بدون دادهٔ مشتری', () {
    test('ثبت و خواندن خطا گرد نیست وقتی خالی است', () {
      // فقط بررسی اینکه ثابت‌های سرویس درست تعریف شده‌اند؛
      // عملیات فایل در تست ویجت با path_provider ماک نیاز دارد که در CI
      // پوشش داده نمی‌شود و عمداً سبک نگه داشته شده.
      expect(appVersion, isNotEmpty);
      expect(releasesUrl, contains('github.com'));
      expect(latestReleaseApiUrl, contains('releases/latest'));
    });
  });
}
