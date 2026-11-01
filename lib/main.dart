import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_data.dart';
import 'screens/appointments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SharedPrefsStore();
  await store.load();
  runApp(NobatyarApp(data: AppData(store)));
}

class NobatyarApp extends StatelessWidget {
  final AppData data;

  const NobatyarApp({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نوبت‌یار',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(data: data),
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'تنظیمات',
          ),
        ],
      ),
    );
  }
}

/// پالت رنگ تیره با لهجه بنفش نئونی
abstract final class AppColors {
  static const Color bg = Color(0xFF0C0F1D);
  static const Color surface = Color(0xFF141930);
  static const Color surfaceHi = Color(0xFF1B2138);
  static const Color primary = Color(0xFFA78BFA);
  static const Color primaryDeep = Color(0xFF7C5CFF);
  static const Color onPrimary = Color(0xFF191228);
  static const Color textHi = Color(0xFFF3F4FB);
  static const Color textMid = Color(0xFFA7ACC7);
  static const Color danger = Color(0xFFF87171);
}

ThemeData buildAppTheme() {
  const bg = AppColors.bg;
  const surface = AppColors.surface;
  const surfaceHi = AppColors.surfaceHi;
  const primary = AppColors.primary;
  const onPrimary = AppColors.onPrimary;
  const textHi = AppColors.textHi;
  const textMid = AppColors.textMid;

  final scheme = ColorScheme.dark(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: const Color(0xFF2A2350),
    onPrimaryContainer: const Color(0xFFD6C8FF),
    secondary: AppColors.primaryDeep,
    onSecondary: Colors.white,
    surface: surface,
    onSurface: textHi,
    surfaceContainerHighest: surfaceHi,
    onSurfaceVariant: textMid,
    error: AppColors.danger,
    onError: const Color(0xFF2A0E0E),
    outline: const Color(0xFF3A4060),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: 'Vazirmatn',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: textHi,
      titleTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: textHi,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: textMid,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : textMid,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceHi,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x10FFFFFF)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHi,
      hintStyle: const TextStyle(color: textMid, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x14FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: Color(0x40F87171)),
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF232A47),
      contentTextStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        color: AppColors.textHi,
        fontSize: 14,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 14,
        color: AppColors.textHi,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textHi,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 14,
        color: AppColors.textMid,
        height: 1.6,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.06),
      thickness: 1,
      space: 1,
    ),
  );
}
