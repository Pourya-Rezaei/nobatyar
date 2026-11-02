import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';

/// ثبت خطاهای غیرمنتظره روی دیسک + پیشنهاد اشتراک‌گذاری در اجرای بعدی.
///
/// فلسفه: بدون سرویس خارجی (Sentry/Crashlytics نیازمند اکانت و ارسال
/// داده به سرور خارجی‌اند). خطاها فقط روی خود دستگاه ذخیره می‌شوند و
/// کاربر تصمیم می‌گیرد بفرستد یا نه.
///
/// چه چیزی ثبت می‌شود: زمان، نسخهٔ اپ، سیستم‌عامل، متن خطا و استک.
/// چه چیزی ثبت نمی‌شود: هیچ دادهٔ کاربر (نام/شماره/مبلغ) — فقط اثر خطا.
class CrashLogService {
  CrashLogService._();

  static const _kSeenMarker = 'nobatyar.crashlog.seenSize';
  static const _fileName = 'crash-log.txt';
  static const int maxEntries = 50;
  static const int maxEntryBytes = 8 * 1024;

  /// آیا گزارش خوانده‌نشده‌ای برای پیشنهاد ارسال هست؟
  static final ValueNotifier<bool> hasUnread =
      ValueNotifier<bool>(false);

  // ---------------------------------------------------------------
  // راه‌اندازی

  /// نصب هدرهای خطا — باید قبل از runApp صدا شود.
  static void install() {
    // خطاهای فریم‌ورک (build/layout errors)
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record('framework', details.exception, details.stack);
      previous?.call(details);
    };

    // خطاهای ناهمگام بی‌گیر (Futureهای بی‌await و ایزوله‌ها)
    PlatformDispatcher.instance.onError = (error, stack) {
      record('uncaught', error, stack);
      return true; // اپ را نکشیم؛ رفتار پیش‌فرض حفظ شود
    };
  }

  /// ثبت یک خطا. هرگز استثنا پر نمی‌کند (لاگ نباید لاگ را بشکند).
  static Future<void> record(
    String kind,
    Object error,
    StackTrace? stack,
  ) async {
    if (kDebugMode) return; // در حالت دیباگ، کنسول کافی است

    try {
      final file = await _file();
      final buf = StringBuffer();
      buf.writeln('--- ${DateTime.now().toIso8601String()}'
          ' | $kind | v$appVersion'
          ' | ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      var text = error.toString();
      if (text.length > 2000) text = '${text.substring(0, 2000)}…';
      buf.writeln(text);
      if (stack != null) {
        var s = stack.toString();
        if (s.length > maxEntryBytes) s = '${s.substring(0, maxEntryBytes)}…';
        buf.writeln(s);
      }
      buf.writeln();
      await file.writeAsString(buf.toString(), mode: FileMode.append);
      await _trim(file);
      hasUnread.value = true;
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // خواندن و ارسال

  /// بررسی هنگام شروع: اگر از اجرای قبل خطای جدیدی مانده، پرچم بزن
  static Future<void> checkUnreadFromLastRun() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return;
      final p = await SharedPreferences.getInstance();
      final seen = p.getInt(_kSeenMarker) ?? 0;
      if (file.lengthSync() > seen) hasUnread.value = true;
    } catch (_) {}
  }

  /// محتوای گزارش برای ارسال (حداکثر ۳۲KB — محدودیت‌های اشتراک‌گذاری متن)
  static Future<String> exportText() async {
    final file = await _file();
    if (!file.existsSync()) return '';
    var text = await file.readAsString();
    if (text.length > 32 * 1024) {
      text = '…(قدیمی‌ها حذف شد)…\n${text.substring(text.length - 32 * 1024)}';
    }
    return 'گزارش خطای نوبت‌یار v$appVersion\n'
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n\n'
        '$text';
  }

  /// بعد از ارسال یا بستن دیالوگ — همه را «دیده» علامت بزن
  static Future<void> markAllRead() async {
    try {
      final file = await _file();
      final len = file.existsSync() ? file.lengthSync() : 0;
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kSeenMarker, len);
      hasUnread.value = false;
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // فایل

  static Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path }/$_fileName');
  }

  /// نگهداشتن فقط [maxEntries] خطای آخر — فایل بی‌سروصدا بزرگ نمی‌شود
  static Future<void> _trim(File file) async {
    try {
      if (!file.existsSync()) return;
      final size = file.lengthSync();
      if (size < 64 * 1024) return; // زیر ۶۴KB نیازی به برش نیست
      final text = await file.readAsString();
      final entries = text.split('--- ').where((e) => e.trim().isNotEmpty);
      final keep =
          entries.toList().take(maxEntries).map((e) => '--- $e').join();
      await file.writeAsString('${keep.trimRight()}\n');
    } catch (_) {}
  }
}
