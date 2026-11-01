import 'package:flutter/material.dart';

import '../app_data.dart';
import '../models.dart';
import 'appointment_form.dart';

/// کارت نمایش یک نوبت
class AppointmentCard extends StatelessWidget {
  final AppData app;
  final Appt appt;

  const AppointmentCard({super.key, required this.app, required this.appt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = appt.status.color;
    final dimmed =
        appt.status == ApptStatus.done || appt.status == ApptStatus.canceled;
    final strike = appt.status == ApptStatus.canceled;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showAppointmentSheet(context, app, existing: appt),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بلوک ساعت
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.schedule, size: 15, color: statusColor),
                    const SizedBox(height: 4),
                    Text(
                      _timeLabel(appt.time),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // مشخصات نوبت
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              appt.service,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                decoration:
                                    strike ? TextDecoration.lineThrough : null,
                                decorationColor: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              appt.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                                decoration: dimmed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (appt.phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.call_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 5),
                            Text(
                              appt.phone,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (appt.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.notes,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                appt.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // وضعیت و منوی اقدامات
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(status: appt.status),
                  SizedBox(
                    height: 30,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 19,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (v) => _onMenuSelected(context, v),
                      itemBuilder: (context) => [
                        if (appt.status != ApptStatus.done)
                          const PopupMenuItem(
                            value: 'done',
                            child: _MenuRow(
                              icon: Icons.task_alt,
                              color: Color(0xFF34D399),
                              label: 'علامت انجام‌شده',
                            ),
                          ),
                        if (appt.status != ApptStatus.confirmed)
                          const PopupMenuItem(
                            value: 'confirmed',
                            child: _MenuRow(
                              icon: Icons.check_circle_outline,
                              color: Color(0xFF60A5FA),
                              label: 'تأیید نوبت',
                            ),
                          ),
                        if (appt.status != ApptStatus.pending)
                          const PopupMenuItem(
                            value: 'pending',
                            child: _MenuRow(
                              icon: Icons.hourglass_top,
                              color: Color(0xFFFBBF24),
                              label: 'در انتظار',
                            ),
                          ),
                        if (appt.status != ApptStatus.canceled)
                          const PopupMenuItem(
                            value: 'canceled',
                            child: _MenuRow(
                              icon: Icons.event_busy,
                              color: Color(0xFFF87171),
                              label: 'لغو نوبت',
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'edit',
                          child: _MenuRow(
                            icon: Icons.edit_outlined,
                            color: Color(0xFFA7ACC7),
                            label: 'ویرایش',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: _MenuRow(
                            icon: Icons.delete_outline,
                            color: Color(0xFFF87171),
                            label: 'حذف',
                          ),
                        ),
                      ],
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

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String _timeLabel(int minutes) {
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm'.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => _faDigits[int.parse(m.group(0)!)],
    );
  }

  Future<void> _onMenuSelected(BuildContext context, String value) async {
    switch (value) {
      case 'edit':
        showAppointmentSheet(context, app, existing: appt);
        break;
      case 'delete':
        final ok = await _confirmDelete(context);
        if (ok == true) app.removeAppt(appt.id);
        break;
      default:
        final status =
            ApptStatus.values.where((s) => s.name == value).firstOrNull;
        if (status != null) app.updateAppt(appt.copyWith(status: status));
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نوبت'),
        content: Text(
          'نوبت «${appt.name}» برای «${appt.service}» حذف شود؟ این عمل قابل بازگشت نیست.',
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

/// برچسب رنگی وضعیت
class StatusPill extends StatelessWidget {
  final ApptStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
