import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_data.dart';
import '../../core/jalali.dart';
import '../../data/models.dart';
import '../app_theme.dart';
import '../widgets/appointment_card.dart';
import '../widgets/appointment_form.dart';

/// فهرست مشتریان — گروه‌بندی نوبت‌ها بر اساس شماره تماس یا نام
class CustomersScreen extends StatefulWidget {
  final AppData data;

  const CustomersScreen({super.key, required this.data});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// جستجو با تأخیر کوتاه برای پرهیز از فیلتر پیوسته
  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.data;

    return Scaffold(
      appBar: AppBar(title: const Text('مشتریان')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final q = enDigits(_query.trim());
          final customers = app.customers
              .where((c) =>
                  q.isEmpty ||
                  enDigits('${c.name} ${c.phone}').contains(q))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'جستجوی نام یا شماره تماس…',
                    prefixIcon: const Icon(Icons.search, size: 21),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 19),
                            onPressed: () {
                              _searchDebounce?.cancel();
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              Expanded(
                child: customers.isEmpty
                    ? _EmptyCustomers(hasAny: app.customers.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                        itemCount: customers.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CustomerTile(
                            customer: customers[i],
                            onTap: () =>
                                _openCustomer(context, customers[i].key),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCustomer(BuildContext context, String key) {
    final app = widget.data;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(data: app, customerKey: key),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerProfile customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final brightness = theme.brightness;
    final green = statusColor(brightness, ApptStatus.done);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              // آواتار حرف اول
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pal.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.trim().isEmpty
                      ? '؟'
                      : customer.name.trim().characters.first,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: pal.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.phone.isEmpty
                          ? 'بدون شماره تماس'
                          : customer.phone,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: pal.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${faNum(customer.appts.length)} نوبت',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pal.primary,
                      ),
                    ),
                  ),
                  if (customer.totalSpent > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${faMoney(customer.totalSpent)} ت',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: green,
                        ),
                      ),
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

class _EmptyCustomers extends StatelessWidget {
  final bool hasAny;

  const _EmptyCustomers({required this.hasAny});

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
              hasAny ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              hasAny ? 'مشتری‌ای پیدا نشد' : 'هنوز مشتری‌ای ثبت نشده',
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasAny ? 'عبارت دیگری را جستجو کن' : 'با ثبت نوبت، مشتری‌ها اینجا جمع می‌شوند',
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

/// پرونده مشتری: مشخصات + تاریخچه نوبت‌ها
class CustomerDetailScreen extends StatefulWidget {
  final AppData data;
  final String customerKey;

  const CustomerDetailScreen({
    super.key,
    required this.data,
    required this.customerKey,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final app = widget.data;
    final theme = Theme.of(context);
    final pal = AppPalette.of(context);
    final brightness = theme.brightness;
    final green = statusColor(brightness, ApptStatus.done);

    return Scaffold(
      appBar: AppBar(title: const Text('پرونده مشتری')),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final c = app.customerByKey(widget.customerKey);
          if (c == null) {
            return const Center(child: Text('این مشتری دیگر نوبتی ندارد'));
          }
          final last = c.lastVisit;

          // بخش‌های ثابت بالای تاریخچه — کارت‌ها به‌صورت تنبل ساخته می‌شوند
          final fixed = <Widget>[
            // سربرگ پرونده
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pal.hairline),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [pal.primaryDeep, pal.primary],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.name.trim().isEmpty
                              ? '؟'
                              : c.name.trim().characters.first,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: pal.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (c.phone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                c.phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: 'کل نوبت‌ها',
                          value: faNum(c.appts.length),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          label: 'انجام‌شده',
                          value: faNum(c.doneCount),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStat(
                          label: 'مجموع پرداخت',
                          value: '${faMoney(c.totalSpent)} ت',
                          highlight: green,
                        ),
                      ),
                    ],
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'آخرین مراجعه: ${last.date.weekDayName} ${last.date.fullText}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            // دکمه‌های اقدام
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showAppointmentSheet(
                      context,
                      app,
                      initialName: c.name,
                      initialPhone: c.phone,
                    ),
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text('نوبت جدید'),
                  ),
                ),
                if (c.phone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _CircleAction(
                    icon: Icons.call_outlined,
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: c.phone));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('شماره تماس کپی شد')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'تاریخچه نوبت‌ها',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
          ];

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: fixed.length + c.appts.length,
            itemBuilder: (context, i) => i < fixed.length
                ? fixed[i]
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppointmentCard(
                        app: app, appt: c.appts[i - fixed.length]),
                  ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;

  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: highlight,
            ),
          ),
          const SizedBox(height: 3),
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

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: pal.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Icon(icon, size: 21, color: pal.primary),
        ),
      ),
    );
  }
}
