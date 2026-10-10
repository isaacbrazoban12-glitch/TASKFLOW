import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task.dart';

// 12/10/2026 es lunes (weekday == 1).
final DateTime monday830 = DateTime(2026, 10, 12, 8, 30);

Task weeklyTask({
  bool completed = false,
  int? completedAt,
  bool stopOnComplete = false,
  List<int> weekdays = const [1],
}) {
  return Task(
    id: 1,
    title: 'Semanal',
    weekdays: weekdays,
    hour: 8,
    minute: 30,
    repeats: true,
    stopOnComplete: stopOnComplete,
    completed: completed,
    completedAt: completedAt,
  );
}

void main() {
  group('Task.serializacion', () {
    test('toMap/fromMap conserva completedAt', () {
      final task = weeklyTask(completedAt: monday830.millisecondsSinceEpoch);
      final restored = Task.fromMap(task.toMap());
      expect(restored.completedAt, monday830.millisecondsSinceEpoch);
      expect(restored.completed, isFalse);
    });

    test('fromMap sin completedAt (fila legacy v1) da null', () {
      final restored = Task.fromMap({
        'id': 1,
        'title': 'Legacy',
        'weekdays': '1',
        'hour': 8,
        'minute': 30,
        'repeats': 1,
        'stopOnComplete': 0,
        'completed': 0,
      });
      expect(restored.completedAt, isNull);
    });

    test('copyWith conserva y puede limpiar completedAt', () {
      final task = weeklyTask(completedAt: 123);
      expect(task.copyWith(title: 'Otro').completedAt, 123);
      expect(task.copyWith(clearCompletedAt: true).completedAt, isNull);
    });
  });

  group('Task.stopsOnComplete/isStopped', () {
    test('no repetitiva se detiene al completar', () {
      const task = Task(
        title: 'Única',
        weekdays: [2],
        hour: 9,
        minute: 0,
        repeats: false,
      );
      expect(task.stopsOnComplete, isTrue);
    });

    test('repetitiva con stopOnComplete se detiene', () {
      expect(weeklyTask(stopOnComplete: true).stopsOnComplete, isTrue);
    });

    test('repetitiva sin stopOnComplete no se detiene', () {
      final task = weeklyTask();
      expect(task.stopsOnComplete, isFalse);
      expect(task.isStopped, isFalse);
    });

    test('isStopped refleja solo el booleano permanente', () {
      expect(weeklyTask(completed: true).isStopped, isTrue);
      expect(
        weeklyTask(completedAt: monday830.millisecondsSinceEpoch).isStopped,
        isFalse,
      );
    });
  });

  group('Task.lastOccurrenceBeforeOrAt', () {
    test('mismo dia ya pasado devuelve hoy a la hora', () {
      final task = weeklyTask();
      final now = DateTime(2026, 10, 12, 9, 0); // lunes 9:00
      expect(task.lastOccurrenceBeforeOrAt(now), monday830);
    });

    test('mismo dia aun futuro devuelve la semana anterior', () {
      final task = weeklyTask();
      final now = DateTime(2026, 10, 12, 7, 0); // lunes 7:00
      expect(
        task.lastOccurrenceBeforeOrAt(now),
        DateTime(2026, 10, 5, 8, 30),
      );
    });

    test('varios dias devuelve la ocurrencia mas reciente', () {
      final task = weeklyTask(weekdays: [1, 3]); // lun + mie
      final now = DateTime(2026, 10, 14, 10, 0); // mie 10:00
      expect(
        task.lastOccurrenceBeforeOrAt(now),
        DateTime(2026, 10, 14, 8, 30),
      );
    });

    test('sin dias validos devuelve null', () {
      const task = Task(title: 'X', weekdays: [], hour: 8, minute: 30);
      expect(task.lastOccurrenceBeforeOrAt(monday830), isNull);
    });
  });

  group('Task.isEffectivelyCompleted', () {
    test('detenida siempre true', () {
      final task = weeklyTask(completed: true);
      expect(task.isEffectivelyCompleted(monday830), isTrue);
      expect(
        task.isEffectivelyCompleted(monday830.add(const Duration(days: 30))),
        isTrue,
      );
    });

    test('ocurrencia marcada sigue true hasta la siguiente', () {
      final markedAt = DateTime(2026, 10, 12, 8, 35).millisecondsSinceEpoch;
      final task = weeklyTask(completedAt: markedAt);
      // Mismo lunes despues de marcar.
      expect(
        task.isEffectivelyCompleted(DateTime(2026, 10, 12, 12, 0)),
        isTrue,
      );
      // Miercoles: aun no llega el proximo lunes.
      expect(
        task.isEffectivelyCompleted(DateTime(2026, 10, 14, 12, 0)),
        isTrue,
      );
    });

    test('se reinicia al llegar la siguiente ocurrencia', () {
      final markedAt = DateTime(2026, 10, 12, 8, 35).millisecondsSinceEpoch;
      final task = weeklyTask(completedAt: markedAt);
      // Lunes siguiente despues de la hora: la marca quedo atras.
      expect(
        task.isEffectivelyCompleted(DateTime(2026, 10, 19, 9, 0)),
        isFalse,
      );
    });

    test('marca exacta en la ocurrencia cuenta como completada', () {
      final task = weeklyTask(completedAt: monday830.millisecondsSinceEpoch);
      expect(
        task.isEffectivelyCompleted(DateTime(2026, 10, 12, 9, 0)),
        isTrue,
      );
    });

    test('sin marca ni stop es false', () {
      expect(weeklyTask().isEffectivelyCompleted(monday830), isFalse);
    });

    test('no repetitiva pendiente es false aunque haya completedAt viejo', () {
      const task = Task(
        title: 'Única',
        weekdays: [1],
        hour: 8,
        minute: 30,
        repeats: false,
        completedAt: 123,
      );
      expect(task.isEffectivelyCompleted(monday830), isFalse);
    });
  });
}
