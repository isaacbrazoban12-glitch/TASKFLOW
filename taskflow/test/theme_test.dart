import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/app_themes.dart';
import 'package:taskflow/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Horario por defecto', () {
    List<ThemeRule> rules() => defaultThemeRules();

    AppThemeId at(int weekday, int hour, int minute) =>
        ThemeController.resolveSchedule(
          weekday: weekday,
          minutes: hour * 60 + minute,
          rules: rules(),
          weekendEnabled: true,
          weekendTheme: AppThemeId.bosque,
        );

    test('Rosa de 6:00 a 12:00 en laborable', () {
      expect(at(DateTime.monday, 6, 0), AppThemeId.rosa);
      expect(at(DateTime.wednesday, 9, 30), AppThemeId.rosa);
      expect(at(DateTime.friday, 11, 59), AppThemeId.rosa);
    });

    test('Grafito de 12:00 a 18:00 en laborable', () {
      expect(at(DateTime.monday, 12, 0), AppThemeId.grafito);
      expect(at(DateTime.tuesday, 15, 0), AppThemeId.grafito);
      expect(at(DateTime.friday, 17, 59), AppThemeId.grafito);
    });

    test('Medianoche de 18:00 a 6:00 en laborable', () {
      expect(at(DateTime.monday, 18, 0), AppThemeId.medianoche);
      expect(at(DateTime.thursday, 23, 30), AppThemeId.medianoche);
      expect(at(DateTime.friday, 0, 0), AppThemeId.medianoche);
      expect(at(DateTime.monday, 5, 59), AppThemeId.medianoche);
    });

    test('Bosque sábados y domingos todo el día', () {
      expect(at(DateTime.saturday, 0, 0), AppThemeId.bosque);
      expect(at(DateTime.saturday, 12, 0), AppThemeId.bosque);
      expect(at(DateTime.sunday, 23, 59), AppThemeId.bosque);
    });

    test('sin finde rigen las reglas también en finde', () {
      final id = ThemeController.resolveSchedule(
        weekday: DateTime.sunday,
        minutes: 9 * 60,
        rules: rules(),
        weekendEnabled: false,
        weekendTheme: AppThemeId.bosque,
      );
      expect(id, AppThemeId.rosa);
    });

    test('reglas desordenadas y lista vacía', () {
      final shuffled = [
        const ThemeRule(startMinutes: 1080, theme: AppThemeId.medianoche),
        const ThemeRule(startMinutes: 360, theme: AppThemeId.rosa),
      ];
      expect(
        ThemeController.resolveSchedule(
          weekday: DateTime.monday,
          minutes: 7 * 60,
          rules: shuffled,
          weekendEnabled: false,
          weekendTheme: AppThemeId.bosque,
        ),
        AppThemeId.rosa,
      );
      expect(
        ThemeController.resolveSchedule(
          weekday: DateTime.monday,
          minutes: 7 * 60,
          rules: const [],
          weekendEnabled: false,
          weekendTheme: AppThemeId.bosque,
        ),
        AppThemeId.rosa,
      );
    });
  });

  group('Rotación', () {
    test('determinista y cíclica cada X horas', () {
      const hours = 6;
      final a = ThemeController.resolveRotation(epochHours: 100, rotationHours: hours);
      final b = ThemeController.resolveRotation(epochHours: 101, rotationHours: hours);
      expect(a, b);
      expect(
        ThemeController.resolveRotation(epochHours: 102, rotationHours: hours),
        isNot(a),
      );
      final seen = {
        for (int h = 0; h < 24; h += hours)
          ThemeController.resolveRotation(epochHours: h, rotationHours: hours),
      };
      expect(seen.length, AppThemeId.values.length);
    });

    test('horas inválidas usan 6', () {
      expect(
        ThemeController.resolveRotation(epochHours: 12, rotationHours: 0),
        ThemeController.resolveRotation(epochHours: 12, rotationHours: 6),
      );
    });
  });

  group('ThemeRule', () {
    test('fromMap valida', () {
      expect(
        ThemeRule.fromMap({'start': 360, 'theme': 'rosa'}),
        isA<ThemeRule>(),
      );
      expect(ThemeRule.fromMap({'start': -1, 'theme': 'rosa'}), isNull);
      expect(ThemeRule.fromMap({'start': 1440, 'theme': 'rosa'}), isNull);
      expect(ThemeRule.fromMap({'start': 360, 'theme': 'inexistente'}), isNull);
      expect(ThemeRule.fromMap({'start': 'x', 'theme': 'rosa'}), isNull);
    });

    test('toMap/fromMap ida y vuelta', () {
      const rule = ThemeRule(startMinutes: 720, theme: AppThemeId.grafito);
      expect(ThemeRule.fromMap(rule.toMap())?.toMap(), rule.toMap());
    });
  });

  group('ThemeController con prefs', () {
    test('manual persiste y se recalcula', () async {
      final controller = await ThemeController.load();
      expect(controller.mode, ThemeModeSetting.schedule);
      await controller.setMode(ThemeModeSetting.manual);
      await controller.setManualTheme(AppThemeId.bosque);
      expect(controller.current, AppThemeId.bosque);

      final reloaded = await ThemeController.load();
      expect(reloaded.mode, ThemeModeSetting.manual);
      expect(reloaded.current, AppThemeId.bosque);
      controller.dispose();
      reloaded.dispose();
    });

    test('refresh avisa solo al cambiar', () async {
      final controller = await ThemeController.load();
      var calls = 0;
      controller.addListener(() => calls++);
      await controller.setMode(ThemeModeSetting.manual);
      await controller.setManualTheme(AppThemeId.grafito);
      controller.refresh(DateTime(2026, 10, 12, 9, 0));
      expect(calls, greaterThanOrEqualTo(1));
      final before = calls;
      controller.refresh(DateTime(2026, 10, 12, 9, 1));
      expect(calls, before);
      controller.dispose();
    });
  });

  group('app_themes', () {
    test('los 4 temas tienen datos', () {
      for (final id in AppThemeId.values) {
        final theme = appThemeOf(id);
        expect(theme.name, isNotEmpty);
        expect(theme.data.scaffoldBackgroundColor, theme.background);
      }
      expect(appThemeOf(AppThemeId.medianoche).isDark, isTrue);
      expect(appThemeOf(AppThemeId.rosa).isDark, isFalse);
    });
  });
}
