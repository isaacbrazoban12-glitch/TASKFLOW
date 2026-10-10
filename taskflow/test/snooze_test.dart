import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/notification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationService.alarmIdsForTask', () {
    test('incluye regulares y posposiciones por defecto', () {
      final ids = NotificationService.alarmIdsForTask(5);
      expect(ids.length, 14);
      for (int weekday = 1; weekday <= 7; weekday++) {
        expect(ids, contains(5 * 10 + weekday));
        expect(ids, contains(5 * 10 + weekday + 100000));
      }
    });

    test('sin snooze solo devuelve los 7 regulares', () {
      final ids = NotificationService.alarmIdsForTask(5, includeSnooze: false);
      expect(ids.length, 7);
      for (int weekday = 1; weekday <= 7; weekday++) {
        expect(ids, contains(5 * 10 + weekday));
        expect(ids, isNot(contains(5 * 10 + weekday + 100000)));
      }
    });
  });

  group('NotificationService.snoozeDeadline', () {
    test('set deja marca unos 5 minutos en futuro', () async {
      final before = DateTime.now().toUtc();
      await NotificationService.instance.setSnoozeDeadline(1);
      final deadline = await NotificationService.instance.snoozeDeadline(1);
      expect(deadline, isNotNull);
      final delta = deadline!.difference(before);
      expect(delta.inMinutes, 5);
      expect(deadline.isAfter(before), isTrue);
    });

    test('marca vencida (ya sono) devuelve null y se elimina', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'snooze_deadline_2',
        DateTime.now().toUtc().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );
      final deadline = await NotificationService.instance.snoozeDeadline(2);
      expect(deadline, isNull);
      expect(prefs.containsKey('snooze_deadline_2'), isFalse);
    });

    test('sin marca devuelve null', () async {
      expect(await NotificationService.instance.snoozeDeadline(99), isNull);
    });

    test('clear elimina la marca (al completar)', () async {
      await NotificationService.instance.setSnoozeDeadline(3);
      expect(await NotificationService.instance.snoozeDeadline(3), isNotNull);
      await NotificationService.instance.clearSnoozeDeadline(3);
      expect(await NotificationService.instance.snoozeDeadline(3), isNull);
    });
  });
}
