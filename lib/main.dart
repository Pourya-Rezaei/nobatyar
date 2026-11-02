import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_data.dart';
import 'data/models.dart';
import 'data/storage.dart';
import 'services/auto_backup_service.dart';
import 'services/crash_log_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'ui/app_theme.dart';
import 'ui/screens/appointments_screen.dart';
import 'ui/screens/customers_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ثبت خطاهای غیرمنتظره روی دیسک — قبل از هر چیز
  CrashLogService.install();

  // فقط بارگذاری داده از دیسک قبل از نخستین فریم — سریع و سبک
  final store = SharedPrefsStore();
  await store.load();
  final app = AppData(store);

  runApp(NobatyarApp(data: app));

  // کارهای پس از نخستین فریم تا شروع اپ روان بماند
  // (ساخت پلاگین نوتیفیکیشن + بکاپ خودکار + بررسی به‌روزرسانی)
  unawaited(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await NotificationService.instance.init();
    await NotificationService.instance.rescheduleAll(app);

    // بکاپ خودکار هفتگی — بی‌صدا و مقاوم به خطا
    unawaited(AutoBackupService.maybeRun(app));

    // بررسی خطاهای اجرای قبلی + پیشنهاد ارسال گزارش
    unawaited(CrashLogService.checkUnreadFromLastRun());

    // بررسی نسخهٔ جدید — حداکثر هر ۲۴ ساعت یک‌بار، بی‌صدا
    unawaited(UpdateService.checkOnStartup());
  }());
}

class NobatyarApp extends StatelessWidget {
  final AppData data;

  const NobatyarApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // فقط به تغییر «تم» گوش می‌دهیم — تغییر داده‌های عادی نباید
    // کل MaterialApp و ساخت هر دو تم را در هر build تکرار کند
    return ListenableBuilder(
      listenable: data.theme,
      builder: (context, _) {
        final mode = switch (data.settings.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.light => ThemeMode.light,
        };
        return MaterialApp(
          title: 'نوبت‌یار',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: mode,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppShell(data: data),
        );
      },
    );
  }
}

/// پوسته اصلی اپ با نوار پایین
class AppShell extends StatefulWidget {
  final AppData data;

  const AppShell({super.key, required this.data});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(data: widget.data),
          AppointmentsScreen(data: widget.data),
          CustomersScreen(data: widget.data),
          SettingsScreen(data: widget.data),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'امروز',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'نوبت‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'مشتریان',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'تنظیمات',
          ),
        ],
      ),
    );
  }
}
