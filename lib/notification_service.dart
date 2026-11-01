import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_data.dart';
import 'jalali.dart';
import 'models.dart';

/// سرویس نوتیفیکیشن محلی — یادآوری نوبت‌ها و خلاصه صبحگاهی
/// همه‌چیز آفلاین است و داده‌ای جایی ارسال نمی‌شود.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// فقط بعد از init موفق فعال می‌شود؛ در تست‌ها خاموش می‌ماند
  bool ready = false;

  static const int _morningId = 900001;
  static const String _channelId = 'nobatyar_reminders';
  static const String _channelName = 'یادآوری نوبت‌ها';

  tz.Location get _loc => tz.getLocation('Asia/Tehran');

  /// راه‌اندازی اولیه + درخواست مجوز نمایش اعلان (اندروید ۱۳ به بالا)
  Future<void> init() async {
    if (ready) return;
    try {
      tzdata.initializeTimeZones();
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_splash'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      debugPrint('notifications initialized: $ok');
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      ready = true;
    } catch (e) {
      debugPrint('notification init failed: $e');
    }
  }

  /// درخواست مجوز نمایش اعلان (اندروید ۱۳ به بالا) — قابل فراخوانی مجدد
  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // شناسه پایدار بر اساس آیدی نوبت
  int _apptNotifId(String apptId) => apptId.hashCode & 0x7FFFFFFF;

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'یادآوری نوبت‌های پیش‌رو و خلاصه صبحگاهی',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> _schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!ready) return;
    final t = tz.TZDateTime.from(when, _loc);
    if (t.isBefore(tz.TZDateTime.now(_loc))) return; // گذشته — بی‌خیال
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: t,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  // ---------------------------------------------------------------
  /// یادآوری تک‌نوبت — به‌اندازه «reminderLead» دقیقه قبل از شروع
  Future<void> scheduleApptReminder(Appt a, BizSettings s) async {
    if (!ready) return;
    await cancelApptReminder(a.id);
    if (!s.notifyAppts) return;
    if (a.status == ApptStatus.canceled) return;

    final start =
        Jalali.fromKey(a.dateKey).toDateTime().add(Duration(minutes: a.time));
    final remindAt = start.subtract(Duration(minutes: s.reminderLead));
    if (remindAt.isBefore(DateTime.now())) return;

    final buf = StringBuffer()
      ..write('${a.service} — ${a.name}\n')
      ..write('${a.date.weekDayName} ${a.date.fullText} · ساعت ${faTime(a.time)}');
    if (a.price != null && a.price! > 0) {
      buf.write('\nهزینه: ${faMoney(a.price!)} تومان');
    }

    await _schedule(
      id: _apptNotifId(a.id),
      when: remindAt,
      title: 'یادآوری نوبت',
      body: buf.toString(),
    );
  }

  Future<void> cancelApptReminder(String apptId) async {
    if (!ready) return;
    try {
      await _plugin.cancel(id: _apptNotifId(apptId));
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  /// خلاصه صبحگاهی: هر بار برای «فردا» ساعت morningHour زمان‌بندی می‌شود؛
  /// با هر تغییر داده دوباره چیده می‌شود تا محتوایش به‌روز بماند.
  Future<void> scheduleMorningSummary(AppData app) async {
    if (!ready) return;
    await cancelMorningSummary();
    final s = app.settings;
    if (!s.morningSummary) return;

    final tomorrow = todayJalali().addDays(1);
    final when =
        tomorrow.toDateTime().add(Duration(minutes: s.morningHour));

    final appts = app.appts
        .where((a) =>
            a.dateKey == tomorrow.dateKey && a.status != ApptStatus.canceled)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    final body = appts.isEmpty
        ? 'فردا نوبتی ثبت نشده است.'
        : 'فردا ${faNum(appts.length)} نوبت داری:\n'
            '${appts.take(5).map((a) => '• ${faTime(a.time)} — ${a.name} (${a.service})').join('\n')}'
            '${appts.length > 5 ? '\nو ${faNum(appts.length - 5)} نوبت دیگر…' : ''}';

    await _schedule(
      id: _morningId,
      when: when,
      title: 'برنامه فردا',
      body: body,
    );
  }

  Future<void> cancelMorningSummary() async {
    if (!ready) return;
    try {
      await _plugin.cancel(id: _morningId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  /// چیدمان دوباره همه یادآوری‌ها (مثلاً بعد از بازگردانی پشتیبان)
  Future<void> rescheduleAll(AppData app) async {
    if (!ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    for (final a in app.appts) {
      await scheduleApptReminder(a, app.settings);
    }
    await scheduleMorningSummary(app);
  }
}
