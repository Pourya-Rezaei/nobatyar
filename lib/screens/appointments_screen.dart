import 'package:flutter/material.dart';

import '../app_data.dart';
import '../jalali.dart';
import '../models.dart';
import '../widgets/appointment_card.dart';
import '../widgets/appointment_form.dart';

/// فهرست همه نوبت‌ها با جستجو و فیلتر
class AppointmentsScreen extends StatefulWidget {
  final AppData data;

  const AppointmentsScreen({super.key, required this.data});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ApptStatus? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Appt a) {
    // جستجو با اعداد فارسی و لاتین
    final q = enDigits(_query.trim());
    if (q.isNotEmpty) {
      final hay = enDigits(
        '${a.name} ${a.service} ${a.phone} ${a.note} ${a.status.label}',
      );
      if (!hay.contains(q)) return false;
    }
    if (_filter != null && a.status != _filter) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.data;

    return Scaffold(
      appBar: AppBar(title: const Text('همه نوبت‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAppointmentSheet(context, app),
        icon: const Icon(Icons.add),
        label: const Text('نوبت جدید'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final today = todayJalali();
          final all = app.appts.where(_matches).toList()
            ..sort((a, b) {
              final c = b.dateKey.compareTo(a.dateKey); // تاریخ‌های جدیدتر اول
              return c != 0 ? c : a.time.compareTo(b.time);
            });

          // گروه‌بندی بر اساس تاریخ
          final groups = <int, List<Appt>>{};
          for (final a in all) {
            groups.putIfAbsent(a.dateKey, () => []).add(a);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'جستجوی نام، خدمت یا شماره تماس…',
                    prefixIcon: const Icon(Icons.search, size: 21),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 19),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _filterChip(null, 'همه', app.appts.length),
                    const SizedBox(width: 8),
                    ...ApptStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: _filterChip(
                          s,
                          s.label,
                          app.appts
                              .where((a) => a.status == s)
                              .length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? _EmptyResult(hasAny: app.appts.isNotEmpty)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                        children: [
                          for (final entry in groups.entries) ...[
                            _GroupHeader(
                              date: Jalali.fromKey(entry.key),
                              today: today,
                              count: entry.value.length,
                            ),
                            ...entry.value.map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child:
                                    AppointmentCard(app: app, appt: a),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(ApptStatus? status, String label, int count) {
    final theme = Theme.of(context);
    final selected = _filter == status;
    final color = status?.color ?? theme.colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.07),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              faNum(count),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? color
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final Jalali date;
  final Jalali today;
  final int count;

  const _GroupHeader({
    required this.date,
    required this.today,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final rel = relativeDayLabel(date, today);
    final label = rel.isEmpty
        ? '${date.weekDayName} ${date.shortText}'
        : '$rel · ${date.weekDayName} ${date.shortText}';
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${faNum(count)} نوبت',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final bool hasAny;

  const _EmptyResult({required this.hasAny});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAny ? Icons.search_off : Icons.event_note_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              hasAny ? 'نوبتی مطابق جستجو پیدا نشد' : 'هنوز نوبتی ثبت نشده',
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasAny
                  ? 'عبارت دیگری را جستجو کن یا فیلتر را بردار'
                  : 'از دکمه «نوبت جدید» اولین نوبت را ثبت کن',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
