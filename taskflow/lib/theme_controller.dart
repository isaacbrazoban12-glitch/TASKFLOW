import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_themes.dart';

/// Cómo elige TaskFlow el tema.
enum ThemeModeSetting { manual, schedule, rotation }

/// Regla de horario: desde [startMinutes] (minutos desde medianoche) rige [theme].
/// Las reglas se evalúan ordenadas; antes de la primera rige la última (trasnoche).
class ThemeRule {
  final int startMinutes;
  final AppThemeId theme;

  const ThemeRule({required this.startMinutes, required this.theme});

  Map<String, dynamic> toMap() => {'start': startMinutes, 'theme': theme.name};

  static ThemeRule? fromMap(Map<String, dynamic> map) {
    final rawStart = map['start'];
    final start = rawStart is num ? rawStart.toInt() : int.tryParse('$rawStart');
    final theme = _themeByName(map['theme'] is String ? map['theme'] as String : null);
    if (start == null || theme == null || start < 0 || start > 1439) return null;
    return ThemeRule(startMinutes: start, theme: theme);
  }
}

AppThemeId? _themeByName(String? name) {
  if (name == null) return null;
  for (final id in AppThemeId.values) {
    if (id.name == name) return id;
  }
  return null;
}

/// Claves en SharedPreferences. Kotlin lee las mismas con prefijo `flutter.`.
class ThemePrefsKeys {
  static const mode = 'taskflow_theme_mode';
  static const manual = 'taskflow_theme_manual';
  static const rules = 'taskflow_theme_rules';
  static const weekendEnabled = 'taskflow_theme_weekend_enabled';
  static const weekend = 'taskflow_theme_weekend';
  static const rotationHours = 'taskflow_theme_rotation_hours';
}

/// Horario por defecto: Rosa 6:00–12:00, Grafito 12:00–18:00,
/// Medianoche 18:00–6:00, Bosque sábados y domingos.
List<ThemeRule> defaultThemeRules() => const [
      ThemeRule(startMinutes: 6 * 60, theme: AppThemeId.rosa),
      ThemeRule(startMinutes: 12 * 60, theme: AppThemeId.grafito),
      ThemeRule(startMinutes: 18 * 60, theme: AppThemeId.medianoche),
    ];

class ThemeController extends ChangeNotifier {
  ThemeModeSetting mode = ThemeModeSetting.schedule;
  AppThemeId manualTheme = AppThemeId.rosa;
  List<ThemeRule> rules = defaultThemeRules();
  bool weekendEnabled = true;
  AppThemeId weekendTheme = AppThemeId.bosque;
  int rotationHours = 6;

  AppThemeId _current = AppThemeId.rosa;
  AppThemeId get current => _current;

  Timer? _timer;

  ThemeController();

  static Future<ThemeController> load() async {
    final controller = ThemeController();
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(ThemePrefsKeys.mode);
      if (mode != null) {
        for (final m in ThemeModeSetting.values) {
          if (m.name == mode) controller.mode = m;
        }
      }
      controller.manualTheme =
          _themeByName(prefs.getString(ThemePrefsKeys.manual)) ?? AppThemeId.rosa;
      final rawRules = prefs.getString(ThemePrefsKeys.rules);
      if (rawRules != null) {
        try {
          final list = jsonDecode(rawRules) as List;
          final parsed = list
              .whereType<Map>()
              .map((e) => ThemeRule.fromMap(Map<String, dynamic>.from(e)))
              .whereType<ThemeRule>()
              .toList();
          if (parsed.isNotEmpty) controller.rules = parsed;
        } catch (_) {}
      }
      controller.weekendEnabled =
          prefs.getBool(ThemePrefsKeys.weekendEnabled) ?? true;
      controller.weekendTheme =
          _themeByName(prefs.getString(ThemePrefsKeys.weekend)) ?? AppThemeId.bosque;
      final hours = prefs.getInt(ThemePrefsKeys.rotationHours);
      if (hours != null && hours > 0 && hours <= 24) controller.rotationHours = hours;
    } catch (_) {}
    controller.refresh();
    return controller;
  }

  /// Recalcula el tema para [now] (ahora por defecto) y avisa si cambió.
  void refresh([DateTime? now]) {
    final at = now ?? DateTime.now();
    final resolved = switch (mode) {
      ThemeModeSetting.manual => manualTheme,
      ThemeModeSetting.schedule => resolveSchedule(
          weekday: at.weekday,
          minutes: at.hour * 60 + at.minute,
          rules: rules,
          weekendEnabled: weekendEnabled,
          weekendTheme: weekendTheme,
        ),
      ThemeModeSetting.rotation => resolveRotation(
          epochHours: at.toUtc().millisecondsSinceEpoch ~/ 3600000,
          rotationHours: rotationHours,
        ),
    };
    if (resolved != _current) {
      _current = resolved;
      notifyListeners();
    }
  }

  /// Arranca el recálculo periódico (idempotente). Parar con [dispose].
  void startAutoRefresh() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// Pura y testeable: qué tema toca por horario.
  static AppThemeId resolveSchedule({
    required int weekday,
    required int minutes,
    required List<ThemeRule> rules,
    required bool weekendEnabled,
    required AppThemeId weekendTheme,
  }) {
    if (weekendEnabled && (weekday == DateTime.saturday || weekday == DateTime.sunday)) {
      return weekendTheme;
    }
    final sorted = [...rules]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    if (sorted.isEmpty) return AppThemeId.rosa;
    AppThemeId pick = sorted.last.theme;
    for (final rule in sorted) {
      if (rule.startMinutes <= minutes) pick = rule.theme;
    }
    return pick;
  }

  /// Pura y testeable: rotación determinista en el orden del enum.
  static AppThemeId resolveRotation({required int epochHours, required int rotationHours}) {
    final hours = rotationHours <= 0 ? 6 : rotationHours;
    final values = AppThemeId.values;
    return values[(epochHours ~/ hours) % values.length];
  }

  Future<void> _save(Future<void> Function(SharedPreferences prefs) write) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await write(prefs);
    } catch (_) {}
    refresh();
  }

  Future<void> setMode(ThemeModeSetting mode) async {
    this.mode = mode;
    await _save((prefs) => prefs.setString(ThemePrefsKeys.mode, mode.name));
  }

  Future<void> setManualTheme(AppThemeId theme) async {
    manualTheme = theme;
    await _save((prefs) => prefs.setString(ThemePrefsKeys.manual, theme.name));
  }

  Future<void> setRules(List<ThemeRule> newRules) async {
    if (newRules.isNotEmpty) rules = List.of(newRules);
    await _save((prefs) => prefs.setString(
          ThemePrefsKeys.rules,
          jsonEncode(rules.map((r) => r.toMap()).toList()),
        ));
  }

  Future<void> setWeekend({required bool enabled, AppThemeId? theme}) async {
    weekendEnabled = enabled;
    if (theme != null) weekendTheme = theme;
    await _save((prefs) async {
      await prefs.setBool(ThemePrefsKeys.weekendEnabled, enabled);
      if (theme != null) await prefs.setString(ThemePrefsKeys.weekend, theme.name);
    });
  }

  Future<void> setRotationHours(int hours) async {
    rotationHours = hours < 1 ? 1 : (hours > 24 ? 24 : hours);
    await _save((prefs) => prefs.setInt(ThemePrefsKeys.rotationHours, rotationHours));
  }
}
