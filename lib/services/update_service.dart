import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
/// اطلاعات یک نسخهٔ جدید در دسترس
class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;

  const UpdateInfo({required this.latestVersion, required this.releaseUrl});
}

/// بررسی به‌روزرسانی از GitHub Releases — بدون وابستگی شبکه‌ای جدید.
///
/// اصول:
///  - حداکثر یک‌بار در ۲۴ ساعت به API گیت‌هاب زده می‌شود (محدودیت نرخ و ادب)
///  - هر خطا (بی‌شبکه، تایم‌اوت، پاسخ خراب) بی‌صدا نادیده گرفته می‌شود؛
///    این قابلیت هرگز نباید کار را اذیت کند
///  - مقایسهٔ نسخه‌ها معنایی (semver) است: 1.2.10 > 1.2.9 > 1.2.2 > 1.10؟ نه!
///    (مقایسهٔ عددیِ هر بخش جداگانه انجام می‌شود)
class UpdateService {
  UpdateService._();

  static const _kLastCheck = 'nobatyar.update.lastCheck';
  static const _kDismissed = 'nobatyar.update.dismissed';

  /// نتیجهٔ آخرین بررسی — صفحهٔ خانه به آن گوش می‌دهد
  static final ValueNotifier<UpdateInfo?> available =
      ValueNotifier<UpdateInfo?>(null);

  /// آیا کاربر این نسخه را دیده و عمداً بسته است؟
  static Future<bool> isDismissed(String version) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDismissed) == version;
  }

  static Future<void> dismiss(String version) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDismissed, version);
    available.value = null;
  }

  // ---------------------------------------------------------------

  /// بررسی خودکار هنگام شروع (حداکثر هر ۲۴ ساعت یک‌بار).
  /// فقط وقتی نتیجه مثبت بود و کاربر همان را نبسته بود نوتیفایر را پر می‌کند.
  static Future<void> checkOnStartup() async {
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getInt(_kLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < const Duration(hours: 24).inMilliseconds) return;

      final info = await _fetchLatest();
      await p.setInt(_kLastCheck, now);
      if (info == null) return;
      if (!isNewer(info.latestVersion, appVersion)) return;
      if (await isDismissed(info.latestVersion)) return;
      available.value = info;
    } catch (_) {
      // بی‌شبکه/تایم‌اوت/پاسخ خراب — ساکت
    }
  }

  /// بررسی دستی از تنظیمات — همیشه به API می‌زند و نتیجه را برمی‌گرداند:
  ///  - null → خطا در دریافت (پیام مناسب به کاربر نشان داده می‌شود)
  ///  - UpdateInfo با isNewer=false → به‌روز هستی
  ///  - UpdateInfo با isNewer=true → نسخهٔ جدید + نوتیفایر پر می‌شود
  static Future<UpdateInfo?> checkManually() async {
    final info = await _fetchLatest();
    if (info == null) return null;
    if (isNewer(info.latestVersion, appVersion)) {
      available.value = info;
    }
    return info;
  }

  static Future<UpdateInfo?> _fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client
          .getUrl(Uri.parse(latestReleaseApiUrl))
          .timeout(const Duration(seconds: 8));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'nobatyar-app');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body =
          await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 10));
      final j = jsonDecode(body);
      if (j is! Map<String, dynamic>) return null;
      final tag = j['tag_name'];
      final url = j['html_url'];
      if (tag is! String || url is! String) return null;
      return UpdateInfo(
        latestVersion: tag.replaceFirst(RegExp('^v'), ''),
        releaseUrl: url,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ---------------------------------------------------------------
  // مقایسهٔ نسخه

  /// آیا [a] جدیدتر از [b] است؟ (مقایسهٔ بخش‌به‌بخش عددی semver)
  static bool isNewer(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    if (pa == null || pb == null) return false;
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i]! > pb[i]!;
    }
    return false;
  }

  /// «1.2.10» → [1, 2, 10]؛ پیشوند v و پسوندهایی مثل «-beta» نادیده گرفته می‌شوند
  static List<int?>? _parse(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final core = s.split(RegExp('[-+]')).first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 4) return null;
    final out = <int?>[0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      final n = int.tryParse(parts[i].trim());
      if (n == null) return null;
      out[i] = n;
    }
    return out;
  }
}
