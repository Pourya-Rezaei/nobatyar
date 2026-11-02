import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../data/app_data.dart';
import 'backup_service.dart';

/// نتیجهٔ یک بکاپ خودکار موفق — برای بنر پیشنهاد اشتراک‌گذاری در خانه
class AutoBackupResult {
  final String path;
  final bool encrypted;
  final DateTime at;

  const AutoBackupResult({
    required this.path,
    required this.encrypted,
    required this.at,
  });
}

/// بکاپ خودکار هفتگی — بدون دخالت کاربر.
///
/// منطق:
///  - اگر نوبتی ثبت نشده باشد، کاری نمی‌کند (داده‌ای برای از دست دادن نیست)
///  - اگر از آخرین بکاپ کمتر از ۷ روز گذشته باشد، کاری نمی‌کند
///  - در غیر این صورت فایل پشتیبان را در پوشهٔ Documents خود اپ می‌نویسد
///    (با uninstall از بین می‌رود؛ به همین دلیل بنر «به جای امن بفرست» نمایش
///    داده می‌شود) و فقط ۳ نسخهٔ آخر نگه داشته می‌شود
///  - اگر کاربر در تنظیمات رمز بکاپ خودکار گذاشته باشد، خروجی رمزدار است
///
/// تنظیمات این سرویس (فعال/غیرفعال + رمز) عمداً جدا از `BizSettings` است تا
/// فرمت فایل پشتیبان (format 2) دست‌نخورده بماند و پشتیبان‌های قدیمی
/// معتبر بمانند.
class AutoBackupService {
  AutoBackupService._();

  static const _kEnabled = 'nobatyar.autobackup.enabled';
  static const _kPassword = 'nobatyar.autobackup.password';
  static const _kLastRun = 'nobatyar.autobackup.last';

  /// هر ۷ روز یک‌بار
  static const Duration interval = Duration(days: 7);

  /// حداکثر فایل بکاپ خودکار روی دیسک
  static const int keepCount = 3;

  /// نتیجهٔ آخرین بکاپ خودکار این نشست — صفحهٔ خانه به آن گوش می‌دهد
  static final ValueNotifier<AutoBackupResult?> lastResult =
      ValueNotifier<AutoBackupResult?>(null);

  // ---------------------------------------------------------------
  // تنظیمات (Preferences)
  //
  // همهٔ خواندن/نوشتن‌ها دفاعی‌اند: اگر پلاگین در دسترس نباشد (مثلاً در
  // محیط تست یا لحظهٔ اول راه‌اندازی) مقدار پیش‌فرض برگردانده می‌شود،
  // نه استثنا. بکاپ خودکار هرگز نباید اپ را بیندازد.

  static Future<bool> isEnabled() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kEnabled) ?? true; // پیش‌فرض: فعال
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kEnabled, v);
    } catch (_) {}
  }

  /// رمز ذخیره‌شده برای بکاپ خودکار (خالی = بدون رمز).
  ///
  /// نکتهٔ امنیتی: این رمز روی خود دستگاه ذخیره می‌شود؛ سطح حفاظتش با خودِ
  /// داده‌های اپ یکی است (داده‌های SharedPreferences رمزنگاری‌شده نیستند).
  /// ارزش رمز هنگام «ترک دستگاه» است، نه روی آن.
  static Future<String> storedPassword() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_kPassword) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> setPassword(String pw) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (pw.isEmpty) {
        await p.remove(_kPassword);
      } else {
        await p.setString(_kPassword, pw);
      }
    } catch (_) {}
  }

  static Future<DateTime?> lastRunAt() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ms = p.getInt(_kLastRun);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------
  // اجرا

  /// بررسی و در صورت نیاز اجرای بکاپ خودکار.
  /// خروجی: نتیجهٔ بکاپ (اگر ساخته شد) وگرنه null.
  /// هر خطایی بی‌صدا بلعیده می‌شود — بکاپ خودکار نباید اپ را بیفتد.
  static Future<AutoBackupResult?> maybeRun(AppData app) async {
    try {
      if (!await isEnabled()) return null;
      if (app.appts.isEmpty) return null;

      final last = await lastRunAt();
      final now = DateTime.now();
      if (last != null && now.difference(last) < interval) return null;

      final result = await _writeBackup(app, now);
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kLastRun, now.millisecondsSinceEpoch);
      lastResult.value = result;
      return result;
    } catch (_) {
      return null; // هرگز استثنا به UI نچکد
    }
  }

  static Future<AutoBackupResult> _writeBackup(
    AppData app,
    DateTime now,
  ) async {
    final map = app.backupMap();
    final stamp = _stamp(now);
    final pw = await storedPassword();

    late final String path;
    late final bool encrypted;
    if (pw.isNotEmpty) {
      final bytes = await BackupService.encodeEncrypted(map, pw);
      path = await _target('nobatyar-autobackup-$stamp.nbk');
      await File(path).writeAsBytes(bytes, flush: true);
      encrypted = true;
    } else {
      final text = BackupService.encodePlain(map);
      path = await _target('nobatyar-autobackup-$stamp.json');
      await File(path).writeAsString(text, flush: true);
      encrypted = false;
    }
    await _pruneOld();
    return AutoBackupResult(path: path, encrypted: encrypted, at: now);
  }

  /// پوشهٔ بکاپ در فضای Documents اپ
  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/autobackups');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> _target(String name) async =>
      '${(await _dir()).path}/$name';

  /// نگهداشتن فقط [keepCount] فایل آخر (بر اساس نام — اسم‌ها تاریخ‌دارند)
  static Future<void> _pruneOld() async {
    try {
      final dir = await _dir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('nobatyar-autobackup-'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      while (files.length > keepCount) {
        final f = files.removeAt(0);
        try {
          f.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// تاریخ به شکل yyyymmdd-HHmm برای نام فایل
  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}';
  }

  // ---------------------------------------------------------------
  // اطلاعات برای نمایش در تنظیمات

  /// فهرست فایل‌های بکاپ خودکار روی دیسک (جدید اول)
  static Future<List<File>> listFiles() async {
    try {
      final dir = await _dir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('nobatyar-autobackup-'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return const [];
    }
  }

  /// توضیح کوتاه وضعیت برای صفحهٔ تنظیمات
  static Future<String> statusLine() async {
    final last = await lastRunAt();
    if (last == null) return 'هنوز بکاپ خودکاری ساخته نشده';
    final d = DateTime.now().difference(last);
    final days = d.inDays;
    final when = days == 0
        ? 'امروز'
        : days == 1
            ? 'دیروز'
            : '$days روز پیش';
    final files = await listFiles();
    return 'آخرین بکاپ خودکار: $when — ${files.length} فایل روی دستگاه';
  }

  /// خطای خواندن مجدد برای اشتراک‌گذاری دستی (بنر خانه)
  static String shareText(AutoBackupResult r) => r.encrypted
      ? 'نسخه پشتیبان خودکار نوبت‌یار $appVersion (رمزدار) — ${r.at.toIso8601String()}'
      : 'نسخه پشتیبان خودکار نوبت‌یار $appVersion — ${r.at.toIso8601String()}';
}
