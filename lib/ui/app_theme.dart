import 'package:flutter/material.dart';

/// پالت رنگ بر اساس روشنایی؛ رنگ وضعیت‌ها را هم [statusColor] ببینید.
class AppPalette {
  final Color bg; // پس‌زمینه صفحه
  final Color surface; // سطح کارت‌ها و نوار پایین
  final Color surfaceHi; // سطح برجسته (ورودی‌ها، چیپ‌ها)
  final Color primary; // رنگ تاکیدی بنفش
  final Color primaryDeep;
  final Color onPrimary; // متن/آیکون روی بنفش
  final Color textHi; // متن اصلی
  final Color textMid; // متن فرعی
  final Color danger;
  final Color hairline; // خطوط بسیار کم‌رنگ دور کارت‌ها
  final Color snackBarBg;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.textHi,
    required this.textMid,
    required this.danger,
    required this.hairline,
    required this.snackBarBg,
  });

  /// پالت تیره (پیش‌فرض همیشگی اپ)
  static const AppPalette dark = AppPalette(
    bg: Color(0xFF0C0F1D),
    surface: Color(0xFF141930),
    surfaceHi: Color(0xFF1B2138),
    primary: Color(0xFFA78BFA),
    primaryDeep: Color(0xFF7C5CFF),
    onPrimary: Color(0xFF191228),
    textHi: Color(0xFFF3F4FB),
    textMid: Color(0xFFA7ACC7),
    danger: Color(0xFFF87171),
    hairline: Color(0x0FFFFFFF),
    snackBarBg: Color(0xFF232A47),
  );

  /// پالت روشن — بنفش عمیق‌تر برای کنتراست روی زمینه روشن
  static const AppPalette light = AppPalette(
    bg: Color(0xFFF1F2FA),
    surface: Color(0xFFFFFFFF),
    surfaceHi: Color(0xFFEBEDF7),
    primary: Color(0xFF6D4DE8),
    primaryDeep: Color(0xFF5B3BD0),
    onPrimary: Color(0xFFFFFFFF),
    textHi: Color(0xFF1B1E33),
    textMid: Color(0xFF5D6382),
    danger: Color(0xFFDC2626),
    hairline: Color(0x12000000),
    snackBarBg: Color(0xFF2A3052),
  );

  static AppPalette of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

/// کش تم‌های ساخته‌شده — ساخت ThemeData سنگین است و فقط
/// یک بار در عمر برنامه باید انجام شود
final Map<Brightness, ThemeData> _themeCache = {};

/// تم اپ برای هر دو حالت روشن و تیره (کش‌شده)
ThemeData buildAppTheme(Brightness brightness) =>
    _themeCache[brightness] ??= _buildTheme(brightness);

ThemeData _buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer:
        brightness == Brightness.dark ? const Color(0xFF2A2350) : const Color(0xFFE7E0FF),
    onPrimaryContainer:
        brightness == Brightness.dark ? const Color(0xFFD6C8FF) : const Color(0xFF2A1E66),
    secondary: p.primaryDeep,
    onSecondary: brightness == Brightness.dark ? Colors.white : Colors.white,
    surface: p.surface,
    onSurface: p.textHi,
    surfaceContainerHighest: p.surfaceHi,
    onSurfaceVariant: p.textMid,
    error: p.danger,
    onError: brightness == Brightness.dark
        ? const Color(0xFF2A0E0E)
        : Colors.white,
    outline: brightness == Brightness.dark
        ? const Color(0xFF3A4060)
        : const Color(0xFFC9CCE0),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'Vazirmatn',
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: p.textHi,
      titleTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: p.textHi,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primary.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: p.textMid,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.primary : p.textMid,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surfaceHi,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHi,
      hintStyle: TextStyle(color: p.textMid, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.danger, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.danger,
        side: BorderSide(color: p.danger.withValues(alpha: 0.45)),
        textStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.snackBarBg,
      contentTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        color: brightness == Brightness.dark
            ? AppPalette.dark.textHi
            : Colors.white,
        fontSize: 14,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surfaceHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 14,
        color: p.textHi,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: p.textHi,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 14,
        color: p.textMid,
        height: 1.6,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerTheme: DividerThemeData(
      color: p.hairline,
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textMid,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? p.primary
            : p.surfaceHi,
      ),
    ),
  );
}
