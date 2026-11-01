import 'package:flutter/material.dart';

import '../app_data.dart';
import '../app_theme.dart';
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
    final pal = AppPalette.of(context);

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
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [pal.primaryDeep, pal.primary],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.event_available,
                size: 22,
                color: pal.onPrimary,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_home',
        onPressed: () =>
            showAppointmentSheet(context, app, initialDate: _selected),
        icon: const Icon(Icons.add),
        label: const Text('نوبت جدید'),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final today = todayJalali();
          final dayAppts = app.apptsOfDay(_selected.dateKey);
          final done = dayAppts
              .where((a) => a.status == ApptStatus.done)
              .length;
          final canceled = dayAppts
              .where((a) => a.status == ApptStatus.canceled)
              .length;
          final remaining = dayAppts.length - done - canceled;
          final income = app.dayIncome(_selected.dateKey);
          final expected = app.dayExpected(_selected.dateKey);

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
              if (income > 0 || expected > 0) ...[
                const SizedBox(height: 10),
                _IncomeCard(income: income, expected: expected),
              ],
              if (dayAppts.isEmpty)
                _EmptyDay(
                  hasBusinessName: app.settings.name.trim().isNotEmpty,
                  isDayOff: app.settings.isDayOff(_selected),
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
    final pal = AppPalette.of(context);
    final primary = theme.colorScheme.primary;
    final isToday = selected == today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.hairline),
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
    final brightness = Theme.of(context).brightness;
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
            color: statusColor(brightness, ApptStatus.pending),
            label: 'باقی‌مانده',
            value: remaining,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt,
            color: statusColor(brightness, ApptStatus.done),
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
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.hairline),
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

/// کارت درآمد روز
class _IncomeCard extends StatelessWidget {
  final int income;
  final int expected;

  const _IncomeCard({required this.income, required this.expected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final brightness = theme.brightness;
    final green = statusColor(brightness, ApptStatus.done);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.payments_outlined, size: 18, color: green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'درآمد امروز',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${faMoney(income)} تومان',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
          if (expected > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'در انتظار وصول',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${faMoney(expected)} ت',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: pal.primary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool hasBusinessName;
  final bool isDayOff;

  const _EmptyDay({required this.hasBusinessName, required this.isDayOff});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        children: [
          Icon(
            isDayOff ? Icons.event_busy : Icons.event_available,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            isDayOff ? 'این روز تعطیل است' : 'نوبتی برای این روز ثبت نشده',
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isDayOff
                ? 'بازه‌های غیرفعال را می‌توانی در تنظیمات مدیریت کنی'
                : hasBusinessName
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
