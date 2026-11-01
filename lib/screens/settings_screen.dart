import 'package:flutter/material.dart';

import '../app_data.dart';
import '../jalali.dart';
import '../models.dart';

/// تنظیمات کسب‌وکار، ساعات کاری و مدیریت داده‌ها
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

  @override
  Widget build(BuildContext context) {
    final app = widget.data;

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final s = app.settings;
          final theme = Theme.of(context);

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
                  onTap: () =>
                      app.updateSettings(s.copyWith(type: t)),
                ),
              ),
              const SizedBox(height: 20),

              _SectionTitle('ساعات کاری'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                      color: Colors.white.withValues(alpha: 0.06),
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
                      'نوبت‌یار نسخه ۱.۰.۰',
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
}

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
                : Colors.white.withValues(alpha: 0.06),
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
