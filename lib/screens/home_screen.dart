import 'package:flutter/material.dart';

import '../app_data.dart';
import '../jalali.dart';
import '../models.dart';
import '../widgets/appointment_card.dart';
import '../widgets/appointment_form.dart';

/// صفحه اصلی: صف نوبت‌های روز انتخابی
class HomeScreen extends StatefulWidget {
  final AppData data;

  const HomeScreen({super.key, required this.data});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Jalali _selected = todayJalali();

  @override
  Widget build(BuildContext context) {
    final app = widget.data;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نوبت‌یار',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              app.settings.name.trim().isEmpty
                  ? 'مدیریت نوبت کسب‌وکار شما'
                  : '${app.settings.type.label} ${app.settings.name.trim()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 20),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF7C5CFF), Color(0xFFA78BFA)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_available,
                size: 22,
                color: Color(0xFF171225),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showAppointmentSheet(context, app, initialDate: _selected),
        icon: const Icon(Icons.add),
        label: const Text('نوبت جدید'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final today = todayJalali();
          final dayAppts = app.appts
              .where((a) => a.dateKey == _selected.dateKey)
              .toList()
            ..sort((a, b) => a.time.compareTo(b.time));
          final done = dayAppts
              .where((a) => a.status == ApptStatus.done)
              .length;
          final canceled = dayAppts
              .where((a) => a.status == ApptStatus.canceled)
              .length;
          final remaining = dayAppts.length - done - canceled;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              _DateSelector(
                selected: _selected,
                today: today,
                onChanged: (j) => setState(() => _selected = j),
              ),
              const SizedBox(height: 14),
              _StatsRow(
                total: dayAppts.length,
                remaining: remaining,
                done: done,
                canceled: canceled,
              ),
              if (dayAppts.isEmpty)
                _EmptyDay(
                  hasBusinessName: app.settings.name.trim().isNotEmpty,
                )
              else
                ...dayAppts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppointmentCard(app: app, appt: a),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final Jalali selected;
  final Jalali today;
  final ValueChanged<Jalali> onChanged;

  const _DateSelector({
    required this.selected,
    required this.today,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isToday = selected == today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // روز قبل — در چینش راست‌چین سمت راست
          IconButton(
            onPressed: () => onChanged(selected.addDays(-1)),
            icon: const Icon(Icons.chevron_right, size: 26),
            tooltip: 'روز قبل',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${selected.weekDayName}، ${selected.fullText}',
                  style:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                if (isToday)
                  Text(
                    'امروز',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => onChanged(today),
                    child: Text(
                      'بازگشت به امروز',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primary,
                        decoration: TextDecoration.underline,
                        decorationColor: primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onChanged(selected.addDays(1)),
            icon: const Icon(Icons.chevron_left, size: 26),
            tooltip: 'روز بعد',
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int total;
  final int remaining;
  final int done;
  final int canceled;

  const _StatsRow({
    required this.total,
    required this.remaining,
    required this.done,
    required this.canceled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.event,
            color: Theme.of(context).colorScheme.primary,
            label: 'کل نوبت‌ها',
            value: total,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.pending_actions,
            color: const Color(0xFFFBBF24),
            label: 'باقی‌مانده',
            value: remaining,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt,
            color: const Color(0xFF34D399),
            label: 'انجام‌شده',
            value: done,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                faNum(value),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool hasBusinessName;

  const _EmptyDay({required this.hasBusinessName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          const Text(
            'نوبتی برای این روز ثبت نشده',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hasBusinessName
                ? 'با دکمه «نوبت جدید» برنامه این روز را بچین'
                : 'ابتدا نام کسب‌وکارت را در تنظیمات وارد کن',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
