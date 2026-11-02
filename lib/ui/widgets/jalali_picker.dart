import 'package:flutter/material.dart';

import '../../core/jalali.dart';

/// انتخابگر تاریخ شمسی به شکل بات‌شیت
Future<Jalali?> showJalaliDatePicker(
  BuildContext context, {
  Jalali? initial,
}) {
  return showModalBottomSheet<Jalali>(
    context: context,
    builder: (_) => _JalaliPickerSheet(initial: initial ?? todayJalali()),
  );
}

class _JalaliPickerSheet extends StatefulWidget {
  final Jalali initial;

  const _JalaliPickerSheet({required this.initial});

  @override
  State<_JalaliPickerSheet> createState() => _JalaliPickerSheetState();
}

class _JalaliPickerSheetState extends State<_JalaliPickerSheet> {
  late Jalali _view = Jalali(widget.initial.year, widget.initial.month, 1);
  late final Jalali _selected = widget.initial;
  late final Jalali _today = todayJalali();

  void _shiftMonth(int delta) {
    setState(() {
      var y = _view.year;
      var m = _view.month + delta;
      if (m > 12) {
        m = 1;
        y++;
      } else if (m < 1) {
        m = 12;
        y--;
      }
      _view = Jalali(y, m, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final monthLen = jalaliMonthLength(_view.year, _view.month);
    final firstWeekDay = Jalali(_view.year, _view.month, 1).weekDay;
    final totalCells = firstWeekDay + monthLen;
    final rows = (totalCells / 7).ceil();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // هدر ماه
            Row(
              children: [
                // در چینش راست‌چین، ماه قبل سمت راست است
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_right, size: 26),
                  tooltip: 'ماه قبل',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_view.monthName} ${faNum(_view.year)}',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_left, size: 26),
                  tooltip: 'ماه بعد',
                ),
              ],
            ),
            const SizedBox(height: 4),
            // سرستون روزهای هفته (شنبه تا جمعه)
            Row(
              children: kWeekDaysShort
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            // شبکه روزها
            Column(
              children: List.generate(rows, (r) {
                return Row(
                  children: List.generate(7, (c) {
                    final idx = r * 7 + c;
                    final dayNum = idx - firstWeekDay + 1;
                    if (dayNum < 1 || dayNum > monthLen) {
                      return const Expanded(
                        child: SizedBox(height: 44),
                      );
                    }
                    final date = Jalali(_view.year, _view.month, dayNum);
                    final isSel = date == _selected;
                    final isToday = date == _today;
                    return Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(context, date),
                        customBorder: const CircleBorder(),
                        child: Container(
                          height: 44,
                          margin: const EdgeInsets.all(2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? primary : null,
                            border: isToday && !isSel
                                ? Border.all(color: primary, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            faNum(dayNum),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  isSel || isToday ? FontWeight.w700 : null,
                              color: isSel
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
            const SizedBox(height: 10),
            // بازگشت به امروز
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.4)),
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => Navigator.pop(context, _today),
                icon: const Icon(Icons.today, size: 18),
                label: const Text('انتخاب امروز'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
