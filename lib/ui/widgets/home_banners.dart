import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/jalali.dart';
import '../../services/auto_backup_service.dart';
import '../../services/crash_log_service.dart';
import '../../services/update_service.dart';
import '../app_theme.dart';

/// سبز وضعیت «انجام‌شده» — یکسان با statusColor در models.dart
Color _successOf(Brightness b) =>
    b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF059669);

/// بنر «نسخهٔ جدید» بالای صفحهٔ خانه.
///
/// فقط وقتی رندر می‌شود که UpdateService.available مقدار داشته باشد؛
/// در تست‌ها/گولدن‌ها سرویس اجرا نمی‌شود و بنر اصلاً وجود ندارد.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      // مرورگر باز نشد — لینک را برای کپی در دسترس بگذار
      await SharePlus.instance.share(
        ShareParams(text: 'دانلود نسخهٔ جدید نوبت‌یار: $url'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: UpdateService.available,
      builder: (context, info, _) {
        if (info == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: Container(
            padding:
                const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [pal.primaryDeep, pal.primary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.system_update_alt,
                    size: 20, color: pal.onPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'نسخهٔ جدید ${faDigits(info.latestVersion)} آماده است',
                    style: TextStyle(
                      color: pal.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: pal.onPrimary,
                    backgroundColor: pal.onPrimary.withValues(alpha: 0.14),
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _open(context, info.releaseUrl),
                  child: const Text(
                    'دانلود',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: pal.onPrimary.withValues(alpha: 0.8),
                  onPressed: () => UpdateService.dismiss(info.latestVersion),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// بنر «بکاپ خودکار ساخته شد» — پیشنهاد انتقال فایل به جای امن.
class AutoBackupBanner extends StatelessWidget {
  const AutoBackupBanner({super.key});

  Future<void> _share(AutoBackupResult r) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(r.path)],
        title: 'نسخه پشتیبان خودکار نوبت‌یار',
        text: AutoBackupService.shareText(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = _successOf(theme.brightness);
    return ValueListenableBuilder<AutoBackupResult?>(
      valueListenable: AutoBackupService.lastResult,
      builder: (context, r, _) {
        if (r == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: success.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    size: 20, color: success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'بکاپ خودکار ساخته شد (${r.encrypted ? 'رمزدار' : 'ساده'}) — '
                    'برای اطمینان، فایل را به جای امن (تلگرام/درایو) بفرست',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: success.withValues(alpha: 0.16),
                    foregroundColor: success,
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10),
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () {
                    AutoBackupService.lastResult.value = null;
                    if (File(r.path).existsSync()) _share(r);
                  },
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('ارسال',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// دیالوگ «گزارش خطا برای توسعه‌دهنده بفرست» — بعد از کرش در اجرای بعدی.
class CrashReportGate extends StatefulWidget {
  final Widget child;
  const CrashReportGate({super.key, required this.child});

  @override
  State<CrashReportGate> createState() => _CrashReportGateState();
}

class _CrashReportGateState extends State<CrashReportGate> {
  bool _asked = false;

  Future<void> _maybeAsk() async {
    if (_asked) return;
    if (!CrashLogService.hasUnread.value) return;
    // یک لحظه صبر تا فریم اصلی رسم شود؛ دیالوگ روی UI آماده بیاید
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || !CrashLogService.hasUnread.value || _asked) return;
    _asked = true;
    await CrashLogService.markAllRead();
    if (!mounted) return;
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('یک خطا ثبت شد'),
        content: Text(
          'در اجرای قبلی نوبت‌یار خطایی ثبت شده است.\n\n'
          'گزارش فقط شامل متن فنی خطا است؛ هیچ اطلاعات مشتری‌ای در آن نیست. '
          'اگر بفرستی، رفع مشکل سریع‌تر می‌شود.',
          style: TextStyle(fontSize: 13.5, height: 1.6, color: theme.colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بعداً'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: pal.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              final text = await CrashLogService.exportText();
              if (text.isEmpty) return;
              await SharePlus.instance.share(ShareParams(
                text: text,
                title: 'گزارش خطای نوبت‌یار',
              ));
            },
            icon: const Icon(Icons.bug_report_outlined, size: 17),
            label: const Text('فرستادن گزارش'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
