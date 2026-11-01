import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_data.dart';
import '../app_theme.dart';
import '../jalali.dart';
import '../models.dart';

/// آمار و نمودارها: وضعیت نوبت‌ها، روزهای پرمراجعه و روند ماهانه
class StatsScreen extends StatelessWidget {
  final AppData data;

  const StatsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final app = data;

    return Scaffold(
      appBar: AppBar(title: const Text('آمار و گزارش‌ها')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.appts.isEmpty) {
            return const _EmptyStats();
          }

          // ماه‌های شش‌گانه اخیر (قدیمی → جدید)
          final months = _lastMonths(6);
          final monthLabels = [
            for (final m in months)
              '${kJalaliMonths[(m % 100) - 1]} ${faNum(m % 100)}',
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _SummaryRow(app: app),
              const SizedBox(height: 18),
              const _CardTitle('وضعیت نوبت‌ها'),
              _StatusDonut(app: app),
              const SizedBox(height: 18),
              const _CardTitle('نوبت‌ها بر اساس روز هفته'),
              _WeekdayBars(app: app),
              const SizedBox(height: 18),
              const _CardTitle('روند شش‌ماهه'),
              _MonthlyBars(
                app: app,
                months: months,
                labels: monthLabels,
                revenue: false,
              ),
              const SizedBox(height: 18),
              const _CardTitle('درآمد ماهانه'),
              _MonthlyBars(
                app: app,
                months: months,
                labels: monthLabels,
                revenue: true,
              ),
            ],
          );
        },
      ),
    );
  }

  /// کلیدهای شش ماه اخیر به شکل yyyymm (قدیمی → جدید)
  static List<int> _lastMonths(int count) {
    final now = todayJalali();
    final out = <int>[];
    var y = now.year;
    var m = now.month;
    for (var i = 0; i < count; i++) {
      out.insert(0, y * 100 + m);
      m--;
      if (m == 0) {
        m = 12;
        y--;
      }
    }
    return out;
  }
}

// -------------------------------------------------------------------

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

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
              Icons.insights_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            const Text(
              'هنوز داده‌ای برای نمایش نیست',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'با ثبت چند نوبت، آمار و نمودارها اینجا ظاهر می‌شوند',
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

class _CardTitle extends StatelessWidget {
  final String text;

  const _CardTitle(this.text);

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

class _SummaryRow extends StatelessWidget {
  final AppData app;

  const _SummaryRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final brightness = theme.brightness;
    final green = statusColor(brightness, ApptStatus.done);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.event_note,
            color: pal.primary,
            label: 'کل نوبت‌ها',
            value: faNum(app.appts.length),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.people_outline,
            color: statusColor(brightness, ApptStatus.confirmed),
            label: 'مشتریان',
            value: faNum(app.customers.length),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_outlined,
            color: green,
            label: 'درآمد کل',
            value: app.totalIncome > 0
                ? _shortMoney(app.totalIncome)
                : '—',
          ),
        ),
      ],
    );
  }
}

/// نمایش فشرده مبلغ: ۱,۲۰۰,۰۰۰ → «۱.۲ م.ت»
String _shortMoney(int v) {
  if (v >= 1000000) {
    final m = v / 1000000.0;
    final s = m >= 10
        ? m.toStringAsFixed(0)
        : (m * 10).round() / 10 == (m * 10).round() / 10
            ? m.toStringAsFixed(1)
            : m.toStringAsFixed(1);
    return '${faDigits(s)} م.ت';
  }
  return '${faMoney(v)} ت';
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryCard({
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
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------

/// دونات وضعیت نوبت‌ها
class _StatusDonut extends StatelessWidget {
  final AppData app;

  const _StatusDonut({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final brightness = theme.brightness;
    final total = app.appts.length;

    final sections = <PieChartSectionData>[];
    for (final s in ApptStatus.values) {
      final count = app.appts.where((a) => a.status == s).length;
      if (count == 0) continue;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: statusColor(brightness, s),
        radius: 46,
        title: faNum(count),
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in ApptStatus.values)
                  if (app.appts.any((a) => a.status == s))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor(brightness, s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              s.label,
                              style:
                                  const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '${faNum(app.appts.where((a) => a.status == s).length)} (${faNum((app.appts.where((a) => a.status == s).length * 100 / total).round())}٪)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------

/// ستون‌های روزهای هفته
class _WeekdayBars extends StatelessWidget {
  final AppData app;

  const _WeekdayBars({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);

    final counts = List<int>.filled(7, 0);
    for (final a in app.appts) {
      counts[Jalali.fromKey(a.dateKey).weekDay] += 1;
    }
    final max = counts.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.hairline),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                maxY: (max + 1).toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          kWeekDaysShort[value.toInt().clamp(0, 6)],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: counts[i].toDouble(),
                          color: pal.primary.withValues(
                              alpha: 0.35 + 0.65 * (max == 0 ? 0 : counts[i] / max)),
                          width: 18,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------

/// ستون‌های ماهانه — تعداد نوبت یا درآمد
class _MonthlyBars extends StatelessWidget {
  final AppData app;
  final List<int> months;
  final List<String> labels;
  final bool revenue;

  const _MonthlyBars({
    required this.app,
    required this.months,
    required this.labels,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);

    final values = [
      for (final m in months)
        (revenue ? app.monthIncome(m) : app.monthCount(m)).toDouble(),
    ];
    final hasAny = values.any((v) => v > 0);
    final max = values.reduce((a, b) => a > b ? a : b);

    if (revenue && !hasAny) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.hairline),
        ),
        child: Text(
          'هنوز قیمتی ثبت نشده — با افزودن مبلغ به نوبت‌ها، درآمد ماهانه اینجا محاسبه می‌شود.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.hairline),
      ),
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            maxY: max == 0 ? 1 : max * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: revenue
                          ? statusColor(theme.brightness, ApptStatus.done)
                              .withValues(alpha: 0.85)
                          : pal.primary.withValues(alpha: 0.85),
                      width: 20,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
