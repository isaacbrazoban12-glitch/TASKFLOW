import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/widgets/alarm_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AlarmDialog.snoozeKey multiplataforma', () {
    test('mes y dia con dos digitos (el bug: 2026_1_9 vs 2026_01_09)', () {
      expect(
        AlarmDialog.snoozeKey(3, 1, DateTime(2026, 1, 9)),
        'alarm_dismiss_3_1_2026_01_09',
      );
    });

    test('coincide con la clave Kotlin para varias fechas', () {
      // Kotlin: "flutter.alarm_dismiss_${id}_${wd}_${yyyy_MM_dd}"
      // (SimpleDateFormat yyyy/MM/dd, Locale.US); el plugin quita el `flutter.`.
      const cases = {
        'alarm_dismiss_7_3_2026_03_05': [7, 3, 2026, 3, 5],
        'alarm_dismiss_1_7_2026_12_31': [1, 7, 2026, 12, 31],
        'alarm_dismiss_42_2_2026_10_09': [42, 2, 2026, 10, 9],
      };
      cases.forEach((expected, parts) {
        expect(
          AlarmDialog.snoozeKey(
            parts[0],
            parts[1],
            DateTime(parts[2], parts[3], parts[4]),
          ),
          expected,
        );
      });
    });

    test('sufijo siempre con formato yyyy_MM_dd', () {
      expect(AlarmDialog.dateSuffix(DateTime(2026, 10, 9)), '2026_10_09');
      expect(
        AlarmDialog.dateSuffix(DateTime(2026, 10, 9)),
        matches(RegExp(r'^\d{4}_\d{2}_\d{2}$')),
      );
    });
  });

  group('AlarmDialog.contador', () {
    test('getSnoozeCount lee tras reload', () async {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = AlarmDialog.snoozeKey(3, 1, DateTime.now());
      await prefs.setInt(todayKey, 2);
      expect(await AlarmDialog.getSnoozeCount(3, 1), 2);
    });

    test('clearStaleSnoozeCounts borra dias viejos y conserva hoy', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = AlarmDialog.snoozeKey(9, 1, now);
      final yesterdayKey =
          AlarmDialog.snoozeKey(9, 1, now.subtract(const Duration(days: 1)));
      await prefs.setInt(todayKey, 1);
      await prefs.setInt(yesterdayKey, 3);
      await prefs.setInt('otra_clave', 5);

      await AlarmDialog.clearStaleSnoozeCounts();

      expect(prefs.getInt(todayKey), 1);
      expect(prefs.containsKey(yesterdayKey), isFalse);
      expect(prefs.getInt('otra_clave'), 5);
    });
  });
}
