import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_data.dart';
import 'app_theme.dart';
import 'notification_service.dart';
import 'models.dart';
import 'screens/appointments_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SharedPrefsStore();
  await store.load();
  final app = AppData(store);

  // راه‌اندازی نوتیفیکیشن و چیدمان دوباره یادآوری‌ها
  unawaited(NotificationService.instance
      .init()
      .then((_) => NotificationService.instance.rescheduleAll(app)));

  runApp(NobatyarApp(data: app));
}

class NobatyarApp extends StatelessWidget {
  final AppData data;

  const NobatyarApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
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
