import 'package:flutter/material.dart';

/// Los 4 temas de TaskFlow. TODOS los colores y medidas viven en este archivo.
/// Kotlin (`ThemeHelper.kt`) usa una copia documentada de la misma tabla.
enum AppThemeId { rosa, medianoche, grafito, bosque }

/// Nombres de día/mes en español (sin paquete intl).
const List<String> kDayFullNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo'
];
const List<String> kMonthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre'
];

class AppTheme {
  final AppThemeId id;
  final String name;
  final Color accent;
  final Color background;
  final bool isDark;
  final Color onAccent;
  final Color onBackground;

  // Tipografías propias (assets/fonts).
  final String fontBody;
  final String fontDisplay;
  final String? fontMono;

  // Superficies.
  final Color card;
  final Color border;
  final Color text;
  final Color muted;

  // Checks de tarea.
  final Color checkEmpty;
  final Color checkDone;
  final Color checkIcon;
  final double? checkRadius;

  // Borrar por deslizamiento.
  final Color danger;

  // Franja semanal.
  final Color chipBg;
  final Color? chipBorder;
  final Color chipLetter;

  // Tarjeta "Siguiente alarma".
  final Color nextBg;
  final Color nextText;
  final Color nextLabel;
  final Color nextPill;
  final Color nextCircle;
  final Color nextCircleIcon;

  // Radios.
  final double chipRadius;
  final double cardRadius;
  final double bigCardRadius;
  final double buttonRadius;

  // Cabecera.
  final double titleSize;
  final bool titleUppercase;
  final bool dateMonoUppercase;

  // Alarma nativa (los usa Kotlin; aquí documentan el sistema).
  final Color alarmBg;
  final Color alarmLabel;
  final Color alarmHour;
  final Color alarmSecondaryBorder;

  const AppTheme({
    required this.id,
    required this.name,
    required this.accent,
    required this.background,
    required this.isDark,
    required this.onAccent,
    required this.onBackground,
    required this.fontBody,
    required this.fontDisplay,
    this.fontMono,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.checkEmpty,
    required this.checkDone,
    required this.checkIcon,
    this.checkRadius,
    required this.danger,
    required this.chipBg,
    this.chipBorder,
    required this.chipLetter,
    required this.nextBg,
    required this.nextText,
    required this.nextLabel,
    required this.nextPill,
    required this.nextCircle,
    required this.nextCircleIcon,
    required this.chipRadius,
    required this.cardRadius,
    required this.bigCardRadius,
    required this.buttonRadius,
    required this.titleSize,
    required this.titleUppercase,
    required this.dateMonoUppercase,
    required this.alarmBg,
    required this.alarmLabel,
    required this.alarmHour,
    required this.alarmSecondaryBorder,
  });

  ThemeData get data => ThemeData(
        useMaterial3: true,
        fontFamily: fontBody,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: background,
      );
}

const double _pill = 999;

const Map<AppThemeId, AppTheme> appThemes = {
  AppThemeId.rosa: AppTheme(
    id: AppThemeId.rosa,
    name: 'Rosa',
    accent: Color(0xFFC93C74),
    background: Color(0xFFFFF6F9),
    isDark: false,
    onAccent: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1C1B1F),
    fontBody: 'PlusJakartaSans',
    fontDisplay: 'BricolageGrotesque',
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF3DCE7),
    text: Color(0xFF2B2036),
    muted: Color(0xFF7A6B86),
    checkEmpty: Color(0xFFD9B8CB),
    checkDone: Color(0xFF2F8F6B),
    checkIcon: Color(0xFF0E1B14),
    danger: Color(0xFFC93C74),
    chipBg: Color(0xFFF1E8FB),
    chipBorder: null,
    chipLetter: Color(0xFF6B5A7C),
    nextBg: Color(0xFF3A2557),
    nextText: Color(0xFFFFFFFF),
    nextLabel: Color(0xFFE6D9F5),
    nextPill: Color(0x29FFFFFF),
    nextCircle: Color(0xFFC93C74),
    nextCircleIcon: Color(0xFFFFFFFF),
    chipRadius: 16,
    cardRadius: 20,
    bigCardRadius: 24,
    buttonRadius: _pill,
    titleSize: 42,
    titleUppercase: false,
    dateMonoUppercase: false,
    alarmBg: Color(0xFFFFF6F9),
    alarmLabel: Color(0xFFC93C74),
    alarmHour: Color(0xFF2B2036),
    alarmSecondaryBorder: Color(0xFFD9B8CB),
  ),
  AppThemeId.medianoche: AppTheme(
    id: AppThemeId.medianoche,
    name: 'Medianoche',
    accent: Color(0xFF22D3EE),
    background: Color(0xFF0B1220),
    isDark: true,
    onAccent: Color(0xFF101418),
    onBackground: Color(0xFF1C1B1F),
    fontBody: 'SpaceGrotesk',
    fontDisplay: 'SpaceGrotesk',
    fontMono: 'JetBrainsMono',
    card: Color(0xFF131C2E),
    border: Color(0xFF1E2A40),
    text: Color(0xFFF1F5F9),
    muted: Color(0xFF94A3B8),
    checkEmpty: Color(0xFF3A4A66),
    checkDone: Color(0xFF34D399),
    checkIcon: Color(0xFF04222B),
    checkRadius: 12,
    danger: Color(0xFFF87171),
    chipBg: Color(0xFF131C2E),
    chipBorder: Color(0xFF1E2A40),
    chipLetter: Color(0xFF94A3B8),
    nextBg: Color(0xFF22D3EE),
    nextText: Color(0xFF04222B),
    nextLabel: Color(0xFF04222B),
    nextPill: Color(0x2404222B),
    nextCircle: Color(0xFF04222B),
    nextCircleIcon: Color(0xFF22D3EE),
    chipRadius: 14,
    cardRadius: 16,
    bigCardRadius: 20,
    buttonRadius: 16,
    titleSize: 42,
    titleUppercase: false,
    dateMonoUppercase: true,
    alarmBg: Color(0xFF0B1220),
    alarmLabel: Color(0xFF22D3EE),
    alarmHour: Color(0xFFF1F5F9),
    alarmSecondaryBorder: Color(0xFF3A4A66),
  ),
  AppThemeId.grafito: AppTheme(
    id: AppThemeId.grafito,
    name: 'Grafito',
    accent: Color(0xFFC2410C),
    background: Color(0xFFECEEF1),
    isDark: false,
    onAccent: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1C1B1F),
    fontBody: 'Archivo',
    fontDisplay: 'Archivo',
    card: Color(0xFFFFFFFF),
    border: Color(0xFFDDE1E6),
    text: Color(0xFF1B1F24),
    muted: Color(0xFF5B6470),
    checkEmpty: Color(0xFFA8B0BA),
    checkDone: Color(0xFF15803D),
    checkIcon: Color(0xFFFFFFFF),
    checkRadius: 10,
    danger: Color(0xFFC2410C),
    chipBg: Color(0xFFFFFFFF),
    chipBorder: Color(0xFFDDE1E6),
    chipLetter: Color(0xFF5B6470),
    nextBg: Color(0xFF1F252C),
    nextText: Color(0xFFFFFFFF),
    nextLabel: Color(0xFFFDBA74),
    nextPill: Color(0x24FFFFFF),
    nextCircle: Color(0xFFC2410C),
    nextCircleIcon: Color(0xFFFFFFFF),
    chipRadius: 14,
    cardRadius: 14,
    bigCardRadius: 16,
    buttonRadius: 14,
    titleSize: 46,
    titleUppercase: true,
    dateMonoUppercase: false,
    alarmBg: Color(0xFF1F252C),
    alarmLabel: Color(0xFFFDBA74),
    alarmHour: Color(0xFFFFFFFF),
    alarmSecondaryBorder: Color(0xFF59636F),
  ),
  AppThemeId.bosque: AppTheme(
    id: AppThemeId.bosque,
    name: 'Bosque',
    accent: Color(0xFFBEF264),
    background: Color(0xFF0F1F18),
    isDark: true,
    onAccent: Color(0xFF101418),
    onBackground: Color(0xFF1C1B1F),
    fontBody: 'Manrope',
    fontDisplay: 'Manrope',
    card: Color(0xFF16291F),
    border: Color(0xFF24402F),
    text: Color(0xFFECF3EE),
    muted: Color(0xFF9DB5A8),
    checkEmpty: Color(0xFF3F6650),
    checkDone: Color(0xFFBEF264),
    checkIcon: Color(0xFF14230F),
    danger: Color(0xFFE5484D),
    chipBg: Color(0xFF16291F),
    chipBorder: Color(0xFF24402F),
    chipLetter: Color(0xFF9DB5A8),
    nextBg: Color(0xFFE9DFC7),
    nextText: Color(0xFF1E2A22),
    nextLabel: Color(0xFF5A4E2E),
    nextPill: Color(0x1F1E2A22),
    nextCircle: Color(0xFF1E2A22),
    nextCircleIcon: Color(0xFFBEF264),
    chipRadius: 18,
    cardRadius: 22,
    bigCardRadius: 26,
    buttonRadius: _pill,
    titleSize: 42,
    titleUppercase: false,
    dateMonoUppercase: false,
    alarmBg: Color(0xFF0F1F18),
    alarmLabel: Color(0xFFBEF264),
    alarmHour: Color(0xFFE9DFC7),
    alarmSecondaryBorder: Color(0xFF3F6650),
  ),
};

AppTheme appThemeOf(AppThemeId id) => appThemes[id]!;

/// Paleta del reloj de la pantalla vacía (copia del SVG de referencia).
class ClockPalette {
  final Color faceFrom;
  final Color faceTo;
  final Color ringLight;
  final Color ringMid;
  final Color ringDark;
  final Color hands;
  final Color numbers;
  final Color numbersQuarter;
  final Color brand;
  final Color tick;
  final Color winBg;
  final Color winBorder;
  final Color winText;
  final Color second;
  final Color hub;
  final Color sparkA;
  final Color sparkB;
  final Color sparkC;
  final Color halo;

  const ClockPalette({
    required this.faceFrom,
    required this.faceTo,
    required this.ringLight,
    required this.ringMid,
    required this.ringDark,
    required this.hands,
    required this.numbers,
    required this.numbersQuarter,
    required this.brand,
    required this.tick,
    required this.winBg,
    required this.winBorder,
    required this.winText,
    required this.second,
    required this.hub,
    required this.sparkA,
    required this.sparkB,
    required this.sparkC,
    required this.halo,
  });
}

const Map<AppThemeId, ClockPalette> clockPalettes = {
  AppThemeId.rosa: ClockPalette(
    faceFrom: Color(0xFF4E3478),
    faceTo: Color(0xFF2A1744),
    ringLight: Color(0xFFFFD3E4),
    ringMid: Color(0xFFC93C74),
    ringDark: Color(0xFF8F2A55),
    hands: Color(0xFFFFF6F9),
    numbers: Color(0xFFE6D9F5),
    numbersQuarter: Color(0xFFFFD3E4),
    brand: Color(0xFFE6D9F5),
    tick: Color(0xFFE6D9F5),
    winBg: Color(0xFFFFF6F9),
    winBorder: Color(0xFFE6D9F5),
    winText: Color(0xFFFFF6F9),
    second: Color(0xFFC93C74),
    hub: Color(0xFF2A1744),
    sparkA: Color(0xFFC93C74),
    sparkB: Color(0xFFE58BB2),
    sparkC: Color(0xFF3A2557),
    halo: Color(0xFFC93C74),
  ),
  AppThemeId.medianoche: ClockPalette(
    faceFrom: Color(0xFF1B2740),
    faceTo: Color(0xFF0F1828),
    ringLight: Color(0xFFA5F3FC),
    ringMid: Color(0xFF22D3EE),
    ringDark: Color(0xFF0E7490),
    hands: Color(0xFFF1F5F9),
    numbers: Color(0xFFE2E8F0),
    numbersQuarter: Color(0xFFA5F3FC),
    brand: Color(0xFF94A3B8),
    tick: Color(0xFFE2E8F0),
    winBg: Color(0xFFF1F5F9),
    winBorder: Color(0xFFE2E8F0),
    winText: Color(0xFFF1F5F9),
    second: Color(0xFF22D3EE),
    hub: Color(0xFF0F1828),
    sparkA: Color(0xFF22D3EE),
    sparkB: Color(0xFFA5F3FC),
    sparkC: Color(0xFF0E7490),
    halo: Color(0xFF22D3EE),
  ),
  AppThemeId.grafito: ClockPalette(
    faceFrom: Color(0xFF2A3139),
    faceTo: Color(0xFF171B20),
    ringLight: Color(0xFFFDBA74),
    ringMid: Color(0xFFC2410C),
    ringDark: Color(0xFF7C2D12),
    hands: Color(0xFFFFFFFF),
    numbers: Color(0xFFF5F5F4),
    numbersQuarter: Color(0xFFFDBA74),
    brand: Color(0xFFB6BEC8),
    tick: Color(0xFFF5F5F4),
    winBg: Color(0xFFFFFFFF),
    winBorder: Color(0xFFF5F5F4),
    winText: Color(0xFFFFFFFF),
    second: Color(0xFFC2410C),
    hub: Color(0xFF171B20),
    sparkA: Color(0xFFC2410C),
    sparkB: Color(0xFFFDBA74),
    sparkC: Color(0xFF7C2D12),
    halo: Color(0xFFC2410C),
  ),
  AppThemeId.bosque: ClockPalette(
    faceFrom: Color(0xFF1E3A2C),
    faceTo: Color(0xFF0F1F18),
    ringLight: Color(0xFFE9DFC7),
    ringMid: Color(0xFFBEF264),
    ringDark: Color(0xFF4D7C0F),
    hands: Color(0xFFECF3EE),
    numbers: Color(0xFFE9DFC7),
    numbersQuarter: Color(0xFFBEF264),
    brand: Color(0xFF9DB5A8),
    tick: Color(0xFFE9DFC7),
    winBg: Color(0xFFECF3EE),
    winBorder: Color(0xFFE9DFC7),
    winText: Color(0xFFECF3EE),
    second: Color(0xFFBEF264),
    hub: Color(0xFF0F1F18),
    sparkA: Color(0xFFBEF264),
    sparkB: Color(0xFFE9DFC7),
    sparkC: Color(0xFF4D7C0F),
    halo: Color(0xFFBEF264),
  ),
};

ClockPalette clockPalette(AppThemeId id) => clockPalettes[id]!;

/// "0 de 1 lista" / "2 de 4 listas".
String taskCountLabel(int done, int total) =>
    '$done de $total lista${total == 1 ? '' : 's'}';

/// Fecha de cabecera ("Sábado, 10 de octubre"). En Medianoche va en
/// mayúsculas mono ("SÁB 10 OCT") y se pinta con [AppTheme.fontMono].
String headerDateString(DateTime date, AppTheme theme) {
  if (theme.dateMonoUppercase) {
    const short = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];
    return '${short[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }
  final day = kDayFullNames[date.weekday - 1].replaceFirstMapped(
    RegExp('^.'),
    (m) => m.group(0)!.toUpperCase(),
  );
  return '$day, ${date.day} de ${kMonthNames[date.month - 1]}';
}

/// Texto relativo ("en 1 h 15 min") desde [now] hasta [when].
String relativeAlarmString(DateTime when, DateTime now) {
  final diff = when.difference(now);
  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inHours < 1) return 'en ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    final rest = diff.inMinutes % 60;
    return rest == 0 ? 'en ${diff.inHours} h' : 'en ${diff.inHours} h $rest min';
  }
  return 'en ${diff.inDays} d';
}

/// Alcance a widgets sin contexto de tema.
class AppThemeScope extends InheritedWidget {
  final AppTheme theme;

  const AppThemeScope({super.key, required this.theme, required super.child});

  static AppTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope no encontrado');
    return scope!.theme;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) => theme != oldWidget.theme;
}
