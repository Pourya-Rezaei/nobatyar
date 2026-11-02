import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/jalali.dart';
import '../../data/app_data.dart';
import '../../data/models.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../app_theme.dart';
import '../widgets/jalali_picker.dart';

/// تنظیمات کسب‌وکار، خدمات و قیمت‌ها، ساعات کاری، یادآوری‌ها، ظاهر و داده‌ها
class SettingsScreen extends StatefulWidget {
  final AppData data;

  const SettingsScreen({super.key, required this.data});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data.settings.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setStart(int v) {
    final s = widget.data.settings;
    var end = s.dayEnd;
    if (v >= end) end = (v + 60).clamp(0, 23 * 60);
    widget.data.updateSettings(s.copyWith(dayStart: v, dayEnd: end));
  }

  void _setEnd(int v) {
    final s = widget.data.settings;
    var start = s.dayStart;
    if (v <= start) start = (v - 60).clamp(6 * 60, 23 * 60);
    widget.data.updateSettings(s.copyWith(dayStart: start, dayEnd: v));
  }

  /// تغییر نوع کسب‌وکار — اگر خدمات دست‌نخورده باشند، پیش‌فرض نوع جدید جایگزین می‌شود
  void _setType(BusinessType t) {
    final s = widget.data.settings;
    final services = s.servicesAreDefault ? t.defaultServices : s.services;
    widget.data.updateSettings(s.copyWith(type: t, services: services));
  }

  Future<void> _clearAll() async {
    final app = widget.data;
    if (app.appts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوبتی برای حذف وجود ندارد')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن همه نوبت‌ها'),
        content: Text(
          'همه ${faNum(app.appts.length)} نوبت ثبت‌شده برای همیشه حذف می‌شوند. مطمئنی؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
              foregroundColor: const Color(0xFF2A0E0E),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف همه'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    app.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('همه نوبت‌ها پاک شد')),
    );
  }

  // ---------------------------------------------------------------
  // پشتیبان‌گیری

  /// انتخاب نوع خروجی: ساده (JSON) یا رمزدار (AES-256)
  Future<void> _exportBackup() async {
    final app = widget.data;
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<_ExportChoice>(
      context: context,
      builder: (ctx) => const _ExportPasswordDialog(),
    );
    if (choice == null || !mounted) return;

    try {
      final map = app.backupMap();
      final date = DateTime.now().toIso8601String().split('T').first;
      late final String path;
      late final String mime;
      if (choice.encrypted) {
        final bytes =
            await BackupService.encodeEncrypted(map, choice.password);
        path = '${Directory.systemTemp.path}/nobatyar-backup-$date.nbk';
        await File(path).writeAsBytes(bytes, flush: true);
        mime = 'application/octet-stream';
      } else {
        final jsonStr = BackupService.encodePlain(map);
        path = '${Directory.systemTemp.path}/nobatyar-backup-$date.json';
        await File(path).writeAsString(jsonStr, flush: true);
        mime = 'application/json';
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: mime)],
          title: 'نسخه پشتیبان نوبت‌یار',
        ),
      );
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('خروجی پشتیبان ساخته نشد — دوباره تلاش کن')),
      );
    }
  }

  Future<void> _importBackup() async {
    final app = widget.data;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'nbk'],
      );
      final file = result.isEmpty ? null : result.first;
      final path = file?.path;
      if (path == null) return;

      var bytes = await File(path).readAsBytes();
      if (!mounted) return;

      // فایل رمزدار → اول رمز را بپرس
      String? password;
      if (BackupService.isEncrypted(bytes)) {
        password = await showDialog<String>(
          context: context,
          builder: (ctx) => const _PasswordDialog(
            title: 'رمز پشتیبان',
            hint: 'رمز این فایل پشتیبان را وارد کن',
          ),
        );
        if (password == null || !mounted) return; // انصراف
      }

      final j = await BackupService.readBackup(bytes, password);
      if (!mounted) return;

      final count = (j['appointments'] as List).length;
      final bizName = ((j['settings'] ?? {}) as Map)['name'];

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('بازگردانی پشتیبان'),
          content: Text(
            'این فایل شامل ${faNum(count)} نوبت'
            '${bizName is String && bizName.isNotEmpty ? ' برای «$bizName»' : ''} است.\n\n'
            'داده‌های فعلی جایگزین می‌شوند. ادامه بدهم؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بازگردانی'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      app.applyBackup(j);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('پشتیبان با موفقیت بازگردانی شد (${faNum(count)} نوبت)'),
      ));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('خواندن فایل پشتیبان ممکن نشد')),
      );
    }
  }

  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final app = widget.data;
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final s = app.settings;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SectionTitle('مشخصات کسب‌وکار'),
              TextField(
                controller: _nameCtrl,
                onChanged: (v) =>
                    app.updateSettings(s.copyWith(name: v)),
                decoration: const InputDecoration(
                  hintText: 'نام کسب‌وکار — مثلاً کلینیک زیبایی رز',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 21),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'نوع کسب‌وکار (فهرست خدمات پیش‌فرض بر اساس همین انتخاب می‌شود)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...BusinessType.values.map(
                (t) => _TypeTile(
                  type: t,
                  selected: s.type == t,
                  onTap: () => _setType(t),
                ),
              ),
              const SizedBox(height: 20),

              _SectionTitle('خدمات و قیمت‌ها'),
              _ActionTile(
                icon: Icons.design_services_outlined,
                color: pal.primary,
                title: 'مدیریت خدمات',
                subtitle:
                    '${faNum(s.services.length)} خدمت — ${faNum(s.services.where((x) => x.price != null).length)} مورد با قیمت',
                onTap: () => _openServicesSheet(context, app),
              ),
              const SizedBox(height: 20),

              _SectionTitle('ساعات کاری'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.hairline),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _TimeDropdown(
                            label: 'شروع کار',
                            value: s.dayStart,
                            onChanged: _setStart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeDropdown(
                            label: 'پایان کار',
                            value: s.dayEnd,
                            onChanged: _setEnd,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SlotDropdown(
                      value: s.slot,
                      onChanged: (v) =>
                          app.updateSettings(s.copyWith(slot: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SectionTitle('ساعات غیرفعال'),
              _ActionTile(
                icon: Icons.event_busy,
                color: statusColor(theme.brightness, ApptStatus.pending),
                title: 'استراحت و تعطیلی',
                subtitle: s.blocks.isEmpty
                    ? 'مثلاً استراحت ناهار یا روزهای تعطیل'
                    : '${faNum(s.blocks.length)} بازه غیرفعال',
                onTap: () => _openBlocksSheet(context, app),
              ),
              const SizedBox(height: 20),

              _SectionTitle('یادآوری‌ها'),
              Material(
                clipBehavior: Clip.antiAlias,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: pal.hairline),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.notifications_outlined,
                          color: pal.primary),
                      title: const Text(
                        'یادآوری نوبت‌ها',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'اعلان قبل از شروع هر نوبت',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: s.notifyAppts,
                      onChanged: (v) {
                        app.updateSettings(
                            s.copyWith(notifyAppts: v));
                        if (v) {
                          NotificationService.instance.requestPermission();
                        }
                      },
                    ),
                    if (s.notifyAppts)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _LeadDropdown(
                          value: s.reminderLead,
                          onChanged: (v) => app
                              .updateSettings(s.copyWith(reminderLead: v)),
                        ),
                      ),
                    Divider(
                        height: 1,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.08)),
                    SwitchListTile(
                      secondary: Icon(Icons.wb_twilight_outlined,
                          color: pal.primary),
                      title: const Text(
                        'خلاصه صبحگاهی',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'هر صبح، برنامه نوبت‌های آن روز',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: s.morningSummary,
                      onChanged: (v) {
                        app.updateSettings(
                            s.copyWith(morningSummary: v));
                        if (v) {
                          NotificationService.instance.requestPermission();
                        }
                      },
                    ),
                    if (s.morningSummary)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _MorningHourDropdown(
                          value: s.morningHour,
                          onChanged: (v) => app
                              .updateSettings(s.copyWith(morningHour: v)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SectionTitle('ظاهر'),
              Row(
                children: [
                  for (final m in AppThemeMode.values) ...[
                    Expanded(
                      child: _ThemeChoice(
                        mode: m,
                        selected: s.themeMode == m,
                        onTap: () => app
                            .updateSettings(s.copyWith(themeMode: m)),
                      ),
                    ),
                    if (m != AppThemeMode.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              _SectionTitle('داده‌ها'),
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.event_note_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text(
                        'نوبت‌های ثبت‌شده',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        faNum(app.appts.length),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.08),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.save_outlined,
                        color: statusColor(
                            theme.brightness, ApptStatus.confirmed),
                      ),
                      title: const Text(
                        'تهیه نسخه پشتیبان',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'فایل JSON خوانا یا رمزنگاری‌شده با AES-256 برای نگهداری یا انتقال',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      onTap: _exportBackup,
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.08),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.restore,
                        color: statusColor(
                            theme.brightness, ApptStatus.done),
                      ),
                      title: const Text(
                        'بازگردانی از پشتیبان',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'داده‌های فعلی با فایل پشتیبان جایگزین می‌شود',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      onTap: _importBackup,
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.08),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Color(0xFFF87171),
                      ),
                      title: const Text(
                        'پاک کردن همه نوبت‌ها',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF87171),
                        ),
                      ),
                      onTap: _clearAll,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    Text(
                      'نوبت‌یار نسخه ۱.۲.۰',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'همه داده‌ها فقط روی همین گوشی ذخیره می‌شود',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openServicesSheet(BuildContext context, AppData app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ServicesSheet(app: app),
    );
  }

  void _openBlocksSheet(BuildContext context, AppData app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BlocksSheet(app: app),
    );
  }
}

// ===================================================================
// اجزای کوچک

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pal.hairline),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
              fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_left,
            color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoice({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? pal.primary.withValues(alpha: 0.10)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? pal.primary.withValues(alpha: 0.6)
                : pal.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              mode.icon,
              size: 20,
              color: selected ? pal.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 5),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected
                    ? pal.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final BusinessType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final primary = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.6)
                : pal.hairline,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              type.icon,
              size: 20,
              color: selected ? primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 19, color: primary),
          ],
        ),
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  static List<int> get _times =>
      [for (var t = 6 * 60; t <= 23 * 60; t += 30) t];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('time_$label$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: _times
          .map((t) => DropdownMenuItem(
                value: t,
                child: Text(faTime(t)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SlotDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SlotDropdown({required this.value, required this.onChanged});

  static const List<int> _slots = [15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('slot_$value'),
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'مدت هر نوبت',
        suffixText: 'دقیقه',
      ),
      items: _slots
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text('${faNum(v)} دقیقه'),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _LeadDropdown extends StatelessWidget {
  final int value; // دقیقه
  final ValueChanged<int> onChanged;

  const _LeadDropdown({required this.value, required this.onChanged});

  static const Map<int, String> _options = {
    30: '۳۰ دقیقه قبل',
    60: '۱ ساعت قبل',
    120: '۲ ساعت قبل',
    720: '۱۲ ساعت قبل',
    1440: '۱ روز قبل',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('lead_$value'),
      initialValue: _options.containsKey(value) ? value : 60,
      decoration: const InputDecoration(
        labelText: 'زمان ارسال یادآوری',
        prefixIcon: Icon(Icons.schedule, size: 19),
      ),
      items: _options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _MorningHourDropdown extends StatelessWidget {
  final int value; // دقیقه از نیمه‌شب
  final ValueChanged<int> onChanged;

  const _MorningHourDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final times = [for (var h = 6; h <= 11; h++) h * 60];
    return DropdownButtonFormField<int>(
      key: ValueKey('morning_$value'),
      initialValue: times.contains(value) ? value : 8 * 60,
      decoration: const InputDecoration(
        labelText: 'ساعت دریافت خلاصه',
        prefixIcon: Icon(Icons.wb_twilight, size: 19),
      ),
      items: times
          .map((t) => DropdownMenuItem(value: t, child: Text(faTime(t))))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ===================================================================
/// بات‌شیت مدیریت خدمات و قیمت‌ها
class _ServicesSheet extends StatefulWidget {
  final AppData app;

  const _ServicesSheet({required this.app});

  @override
  State<_ServicesSheet> createState() => _ServicesSheetState();
}

class _ServicesSheetState extends State<_ServicesSheet> {
  late List<Service> _list;
  final _ctrls = <String, TextEditingController>{};
  final _priceCtrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _list = List.of(widget.app.settings.services);
    _makeCtrls();
  }

  void _makeCtrls() {
    for (final s in _list) {
      _ctrls[s.name] = TextEditingController(text: s.name);
      _priceCtrls[s.name] = TextEditingController(
        text: s.price == null ? '' : faNum(s.price!),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _commit() =>
      widget.app.updateSettings(widget.app.settings.copyWith(services: _list));

  int? _parse(String t) {
    final v = enDigits(t.trim()).replaceAll(',', '');
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  void _removeAt(int i) {
    final s = _list.removeAt(i);
    _ctrls.remove(s.name)?.dispose();
    _priceCtrls.remove(s.name)?.dispose();
    setState(() {});
    _commit();
  }

  void _add() {
    var n = _list.length + 1;
    while (_list.any((s) => s.name == 'خدمت $n')) {
      n++;
    }
    setState(() {
      _list = [..._list, Service(name: 'خدمت $n')];
      _makeCtrls();
    });
    _commit();
  }

  void _reset() {
    setState(() {
      for (final c in _ctrls.values) {
        c.dispose();
      }
      for (final c in _priceCtrls.values) {
        c.dispose();
      }
      _ctrls.clear();
      _priceCtrls.clear();
      _list = widget.app.settings.type.defaultServices;
      _makeCtrls();
    });
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'خدمات و قیمت‌ها',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('پیش‌فرض'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'قیمت پیش‌فرض هر خدمت هنگام ثبت نوبت خودکار پر می‌شود — قابل ویرایش است.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _ctrls[_list[i].name],
                          decoration: const InputDecoration(
                              hintText: 'نام خدمت'),
                          onChanged: (v) {
                            _list[i] = _list[i].copyWith(name: v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _priceCtrls[_list[i].name],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9۰-۹,]')),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'قیمت',
                            suffixText: 'ت',
                          ),
                          onChanged: (v) {
                            final p = _parse(v);
                            _list[i] = p == null
                                ? _list[i].copyWith(clearPrice: true)
                                : _list[i].copyWith(price: p);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () => _removeAt(i),
                        icon: Icon(
                          Icons.remove_circle_outline,
                          size: 21,
                          color: pal.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pal.primary,
                    side: BorderSide(color: pal.primary.withValues(alpha: 0.4)),
                  ),
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('افزودن خدمت جدید'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    _commit();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('خدمات و قیمت‌ها ذخیره شد')),
                    );
                  },
                  icon: const Icon(Icons.check, size: 19),
                  label: const Text('ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
/// بات‌شیت مدیریت ساعات غیرفعال
class _BlocksSheet extends StatefulWidget {
  final AppData app;

  const _BlocksSheet({required this.app});

  @override
  State<_BlocksSheet> createState() => _BlocksSheetState();
}

class _BlocksSheetState extends State<_BlocksSheet> {
  int? _newWeekDay;
  Jalali? _newDate;
  bool _fullDay = true;
  int _from = 13 * 60;
  int _to = 14 * 60;

  List<TimeBlock> get _blocks => widget.app.settings.blocks;

  void _save(List<TimeBlock> blocks) => widget.app
      .updateSettings(widget.app.settings.copyWith(blocks: blocks));

  void _removeAt(int i) => _save([..._blocks]..removeAt(i));

  void _add() {
    final id = 'blk_${DateTime.now().microsecondsSinceEpoch}';
    TimeBlock b;
    if (_newDate != null) {
      b = TimeBlock(
        id: id,
        dateKey: _newDate!.dateKey,
        start: _fullDay ? 0 : _from,
        end: _fullDay ? 24 * 60 : _to,
      );
    } else {
      if (_newWeekDay == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('روز هفته یا تاریخ را انتخاب کن')),
        );
        return;
      }
      b = TimeBlock(
        id: id,
        weekDay: _newWeekDay,
        start: _fullDay ? 0 : _from,
        end: _fullDay ? 24 * 60 : _to,
      );
    }
    if (!_fullDay && _to <= _from) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پایان بازه باید بعد از شروع آن باشد')),
      );
      return;
    }
    _save([..._blocks, b]);
    setState(() {
      _newWeekDay = null;
      _newDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'استراحت و تعطیلی',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'بازه‌های غیرفعال هنگام ثبت نوبت نمایش داده نمی‌شوند.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // فهرست بلاک‌ها
              if (_blocks.isEmpty)
                Text(
                  'هنوز بازه‌ای غیرفعال نشده است.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (var i = 0; i < _blocks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _blocks[i].isWeekly
                                ? Icons.repeat
                                : Icons.event,
                            size: 17,
                            color: pal.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _blocks[i].label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _removeAt(i),
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: pal.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 14),

              // افزودن بلاک جدید
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'افزودن بازه غیرفعال',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _newWeekDay,
                            hint: const Text('هر هفته'),
                            decoration: const InputDecoration(
                                labelText: 'تکرار هفتگی'),
                            items: [
                              for (var d = 0; d < 7; d++)
                                DropdownMenuItem(
                                    value: d, child: Text(kWeekDays[d])),
                            ],
                            onChanged: (v) => setState(() {
                              _newWeekDay = v;
                              _newDate = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showJalaliDatePicker(
                                context,
                                initial: _newDate ?? todayJalali(),
                              );
                              if (picked == null) return;
                              setState(() {
                                _newDate = picked;
                                _newWeekDay = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 15),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: pal.hairline),
                              ),
                              child: Text(
                                _newDate == null
                                    ? 'تاریخ خاص'
                                    : _newDate!.shortText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _newDate == null
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'کل روز تعطیل',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      value: _fullDay,
                      onChanged: (v) => setState(() => _fullDay = v),
                    ),
                    if (!_fullDay)
                      Row(
                        children: [
                          Expanded(
                            child: _TimeDropdown(
                              label: 'از ساعت',
                              value: _from,
                              onChanged: (v) =>
                                  setState(() => _from = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeDropdown(
                              label: 'تا ساعت',
                              value: _to,
                              onChanged: (v) => setState(() => _to = v),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add, size: 19),
                        label: const Text('افزودن بازه'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// دیالوگ‌های رمز پشتیبان

/// نتیجهٔ دیالوگ خروجی: ساده یا رمزدار
class _ExportChoice {
  final bool encrypted;
  final String password;
  const _ExportChoice({required this.encrypted, this.password = ''});
}

/// دیالوگ انتخاب نوع خروجی پشتیبان + رمز اختیاری
class _ExportPasswordDialog extends StatefulWidget {
  const _ExportPasswordDialog();

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('تهیه نسخه پشتیبان'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اگر رمزی وارد کنی، فایل پشتیبان با رمزنگاری AES-256 قفل می‌شود و '
            'بدون همین رمز روی هیچ دستگاهی باز نمی‌شود.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw1,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              hintText: 'رمز (اختیاری — حداقل ۴ نویسه)',
              prefixIcon: const Icon(Icons.password_outlined, size: 21),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pw2,
            obscureText: _obscure,
            decoration: const InputDecoration(
              hintText: 'تکرار رمز',
              prefixIcon: Icon(Icons.repeat, size: 21),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _ExportChoice(encrypted: false),
          ),
          child: const Text('خروجی ساده'),
        ),
        FilledButton(
          onPressed: () {
            final pw = _pw1.text;
            if (pw.length < 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('رمز باید حداقل ۴ نویسه باشد')),
              );
              return;
            }
            if (pw != _pw2.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('رمز و تکرار آن یکسان نیست')),
              );
              return;
            }
            Navigator.pop(
              context,
              _ExportChoice(encrypted: true, password: pw),
            );
          },
          child: const Text('خروجی رمزدار'),
        ),
      ],
    );
  }
}

/// دیالوگ سادهٔ ورود رمز (برای بازکردن پشتیبان رمزدار)
class _PasswordDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _PasswordDialog({required this.title, required this.hint});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        obscureText: _obscure,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.lock_outline, size: 21),
          suffixIcon: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('ادامه'),
        ),
      ],
    );
  }
}
