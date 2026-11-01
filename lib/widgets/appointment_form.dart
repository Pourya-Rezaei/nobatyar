import 'package:flutter/material.dart';

import '../app_data.dart';
import '../jalali.dart';
import '../models.dart';
import 'jalali_picker.dart';

const String _customTag = '__custom__';

/// بات‌شیت افزودن/ویرایش نوبت
Future<void> showAppointmentSheet(
  BuildContext context,
  AppData app, {
  Appt? existing,
  Jalali? initialDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AppointmentSheet(
        app: app,
        existing: existing,
        initialDate: initialDate ?? todayJalali(),
      ),
    ),
  );
}

class _AppointmentSheet extends StatefulWidget {
  final AppData app;
  final Appt? existing;
  final Jalali initialDate;

  const _AppointmentSheet({
    required this.app,
    required this.existing,
    required this.initialDate,
  });

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late final TextEditingController _customService = TextEditingController(
    text: _initialCustomService,
  );

  late String? _service = _initialService;
  late bool _isCustom = _initialIsCustom;
  late Jalali _date =
      widget.existing != null ? Jalali.fromKey(widget.existing!.dateKey) : widget.initialDate;
  late int? _time = widget.existing?.time;
  late ApptStatus _status = widget.existing?.status ?? ApptStatus.pending;

  String? get _initialService {
    final e = widget.existing;
    if (e == null || e.service.isEmpty) return null;
    return widget.app.settings.type.services.contains(e.service)
        ? e.service
        : null;
  }

  bool get _initialIsCustom {
    final e = widget.existing;
    if (e == null || e.service.isEmpty) return false;
    return !widget.app.settings.type.services.contains(e.service);
  }

  String get _initialCustomService {
    final e = widget.existing;
    if (e == null || e.service.isEmpty) return '';
    return widget.app.settings.type.services.contains(e.service) ? '' : e.service;
  }

  /// بازه‌های زمانی آزاد از تنظیمات کسب‌وکار
  List<int> get _slots {
    final s = widget.app.settings;
    final out = <int>[];
    if (s.slot <= 0 || s.dayEnd <= s.dayStart) return out;
    for (var t = s.dayStart; t + s.slot <= s.dayEnd; t += s.slot) {
      out.add(t);
    }
    return out;
  }

  /// آیا این بازه برای این تاریخ قبلاً رزرو شده؟
  bool _isBooked(int t) => widget.app.appts.any(
        (a) =>
            a.dateKey == _date.dateKey &&
            a.time == t &&
            a.status != ApptStatus.canceled &&
            a.id != widget.existing?.id,
      );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _customService.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showJalaliDatePicker(context, initial: _date);
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      // اگر ساعت انتخاب‌شده در تاریخ جدید پر شده باشد، پاک می‌شود
      if (_time != null && _isBooked(_time!)) _time = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final service =
        _isCustom ? _customService.text.trim() : (_service ?? '').trim();
    if (service.isEmpty) {
      _toast('نوع خدمت را انتخاب یا بنویسید');
      return;
    }
    if (_time == null) {
      _toast('یکی از ساعات آزاد را انتخاب کن');
      return;
    }

    final e = widget.existing;
    final appt = Appt(
      id: e?.id ?? 'appt_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      service: service,
      dateKey: _date.dateKey,
      time: _time!,
      note: _note.text.trim(),
      status: _status,
      createdAt: e?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );

    final messenger = ScaffoldMessenger.of(context);
    if (e == null) {
      widget.app.addAppt(appt);
    } else {
      widget.app.updateAppt(appt);
    }
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text(e == null ? 'نوبت جدید ثبت شد' : 'تغییرات ذخیره شد')),
    );
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نوبت'),
        content: Text(
          'نوبت «${e.name}» برای «${e.service}» حذف شود؟ این عمل قابل بازگشت نیست.',
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
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    widget.app.removeAppt(e.id);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('نوبت حذف شد')));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.app.settings;
    final isEdit = widget.existing != null;
    final slots = _slots;
    // اگر ساعت نوبتِ در حال ویرایش در فهرست بازه‌ها نباشد، جداگانه نمایشش می‌دهیم
    final extraSlot =
        (_time != null && !slots.contains(_time!)) ? _time! : null;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'ویرایش نوبت' : 'نوبت جدید',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _FieldLabel('نام و نام خانوادگی'),
            TextFormField(
              controller: _name,
              autofocus: !isEdit,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'نام مشتری را بنویسید' : null,
              decoration: const InputDecoration(hintText: 'مثلاً سارا محمدی'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('شماره تماس'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(hintText: 'اختیاری — مثلاً ۰۹۱۲۳۴۵۶۷۸۹'),
            ),
            const SizedBox(height: 14),

            _FieldLabel('نوع خدمت'),
            DropdownButtonFormField<String>(
              initialValue: _isCustom ? _customTag : _service,
              hint: const Text('انتخاب کنید'),
              items: [
                ...s.type.services.map(
                  (sv) => DropdownMenuItem(value: sv, child: Text(sv)),
                ),
                const DropdownMenuItem(
                  value: _customTag,
                  child: Text('سایر (دلخواه)'),
                ),
              ],
              onChanged: (v) => setState(() {
                if (v == _customTag) {
                  _isCustom = true;
                } else {
                  _isCustom = false;
                  _service = v;
                }
              }),
            ),
            if (_isCustom) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customService,
                decoration:
                    const InputDecoration(hintText: 'نام خدمت را بنویسید…'),
                validator: (v) => (_isCustom && (v == null || v.trim().isEmpty))
                    ? 'نام خدمت را بنویسید'
                    : null,
              ),
            ],
            const SizedBox(height: 14),

            _FieldLabel('تاریخ'),
            const SizedBox(height: 6),
            _DateField(date: _date, onTap: _pickDate),
            const SizedBox(height: 14),

            _FieldLabel('ساعت نوبت'),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              Text(
                'ابتدا ساعات کاری را در تنظیمات مشخص کنید',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (extraSlot != null) _slotChip(extraSlot, true, false),
                  ...slots.map((t) => _slotChip(t, t == _time, _isBooked(t))),
                ],
              ),
            const SizedBox(height: 14),

            _FieldLabel('وضعیت'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ApptStatus.values.map(_statusChip).toList(),
            ),
            const SizedBox(height: 14),

            _FieldLabel('یادداشت'),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'اختیاری…'),
            ),
            const SizedBox(height: 22),

            if (isEdit)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, size: 19),
                      label: const Text('حذف نوبت'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 19),
                      label: const Text('ذخیره'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('ثبت نوبت'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(int t, bool selected, bool booked) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: booked ? null : () => setState(() => _time = t),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Text(
          faTime(t),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: booked
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
            decoration: booked ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  Widget _statusChip(ApptStatus st) {
    final theme = Theme.of(context);
    final selected = _status == st;
    final c = st.color;
    return InkWell(
      onTap: () => setState(() => _status = st),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? c
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? c : c.withValues(alpha: 0.35),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF171225) : c,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              st.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF171225) : c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final Jalali date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              '${date.weekDayName}، ${date.fullText}',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down,
                size: 22, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
