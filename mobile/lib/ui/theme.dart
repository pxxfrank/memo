// flomo 风格主题色（与桌面端 tailwind 配置一致；暗黑模式通过 AppColors.dark 切换）
import 'package:flutter/material.dart';

abstract final class AppColors {
  static bool dark = false;
  // 浅色（与桌面 :root 一致）
  static const _bgL = Color(0xFFF7F6F3);
  static const _sidebarL = Color(0xFFF1F0EB);
  static const _cardL = Color(0xFFFFFFFF);
  static const _lineL = Color(0xFFE9E7E1);
  static const _inkL = Color(0xFF37352F);
  static const _subL = Color(0xFF8E8B84);
  static const _faintL = Color(0xFFB5B2AA);
  static const _greenL = Color(0xFF43B581);
  static const _greendarkL = Color(0xFF34996B);
  static const _tagbgL = Color(0xFFEAF4EF);
  static const _pinL = Color(0xFFF5A623);

  // 深色（与桌面 .dark 一致）
  static const _bgD = Color(0xFF1A1918);
  static const _sidebarD = Color(0xFF21201E);
  static const _cardD = Color(0xFF282725);
  static const _lineD = Color(0xFF3A3936);
  static const _inkD = Color(0xFFE9E7E2);
  static const _subD = Color(0xFFA8A59E);
  static const _faintD = Color(0xFF807E78);
  static const _greenD = Color(0xFF58C896);
  static const _greendarkD = Color(0xFF6EDAAC);
  static const _tagbgD = Color(0xFF263830);
  static const _pinD = Color(0xFFF5B860);

  static Color get bg => dark ? _bgD : _bgL;
  static Color get sidebar => dark ? _sidebarD : _sidebarL;
  static Color get card => dark ? _cardD : _cardL;
  static Color get line => dark ? _lineD : _lineL;
  static Color get ink => dark ? _inkD : _inkL;
  static Color get sub => dark ? _subD : _subL;
  static Color get faint => dark ? _faintD : _faintL;
  static Color get green => dark ? _greenD : _greenL;
  static Color get greendark => dark ? _greendarkD : _greendarkL;
  static Color get tagbg => dark ? _tagbgD : _tagbgL;
  static Color get pin => dark ? _pinD : _pinL;
}

/// 全局主题状态（暗黑开关实时生效）
abstract final class AppTheme {
  static final ValueNotifier<bool> darkNotifier = ValueNotifier<bool>(false);
  static void apply(bool dark) {
    AppColors.dark = dark;
    darkNotifier.value = dark;
  }
}

ThemeData buildTheme({bool darkMode = false}) {
  AppColors.dark = darkMode;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: darkMode ? Brightness.dark : Brightness.light,
    primary: AppColors.green,
    onPrimary: Colors.white,
    surface: AppColors.bg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: darkMode ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    fontFamily: 'Microsoft YaHei',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.faint, fontSize: 14),
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.green, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.card,
      textStyle: TextStyle(color: AppColors.ink, fontSize: 13.5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    ),
    dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
  );
}
