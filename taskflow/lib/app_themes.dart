import 'package:flutter/material.dart';

/// Los 4 temas de TaskFlow. TODOS los colores viven en este archivo
/// (Kotlin usa una copia documentada en `ThemeHelper.kt`-equivalente:
/// ver `NativeAlarmHelper`/`AlarmActivity`, misma tabla).
enum AppThemeId { rosa, medianoche, grafito, bosque }

class AppTheme {
  final AppThemeId id;
  final String name;
  final Color accent;
  final Color background;
  final bool isDark;
  final Color onAccent;
  final Color onBackground;

  const AppTheme({
    required this.id,
    required this.name,
    required this.accent,
    required this.background,
    required this.isDark,
    required this.onAccent,
    required this.onBackground,
  });

  ThemeData get data => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: background,
      );
}

const Map<AppThemeId, AppTheme> appThemes = {
  AppThemeId.rosa: AppTheme(
    id: AppThemeId.rosa,
    name: 'Rosa',
    accent: Color(0xFFC93C74),
    background: Color(0xFFFFF6F9),
    isDark: false,
    onAccent: Colors.white, // 4.79:1
    onBackground: Color(0xFF1C1B1F),
  ),
  AppThemeId.medianoche: AppTheme(
    id: AppThemeId.medianoche,
    name: 'Medianoche',
    accent: Color(0xFF22D3EE),
    background: Color(0xFF0B1220),
    isDark: true,
    onAccent: Color(0xFF101418), // 10.24:1 (blanco solo 1.81:1)
    onBackground: Color(0xFFE6E1E5),
  ),
  AppThemeId.grafito: AppTheme(
    id: AppThemeId.grafito,
    name: 'Grafito',
    accent: Color(0xFFC2410C),
    background: Color(0xFFECEEF1),
    isDark: false,
    onAccent: Colors.white, // 5.18:1
    onBackground: Color(0xFF1C1B1F),
  ),
  AppThemeId.bosque: AppTheme(
    id: AppThemeId.bosque,
    name: 'Bosque',
    accent: Color(0xFFBEF264),
    background: Color(0xFF0F1F18),
    isDark: true,
    onAccent: Color(0xFF101418), // 14.16:1 (blanco solo 1.31:1)
    onBackground: Color(0xFFE6E1E5),
  ),
};

AppTheme appThemeOf(AppThemeId id) => appThemes[id]!;
