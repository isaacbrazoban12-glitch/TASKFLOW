import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/database/database_helper.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/sound_service.dart';

import 'widget_test.dart' show FakeDatabaseHelper, pumpFrames;

Completion c(DateTime at) => Completion(taskId: 1, title: 'x', at: at);

void main() {
  group('ProgressStats', () {
    final now = DateTime(2026, 11, 7, 18); // sábado

    test('racha cuenta días seguidos hasta hoy', () {
      final s = ProgressStats.from([
        c(DateTime(2026, 11, 7, 8)),
        c(DateTime(2026, 11, 6, 8)),
        c(DateTime(2026, 11, 5, 8)),
        c(DateTime(2026, 11, 3, 8)), // hueco el día 4
      ], now);
      expect(s.streakDays, 3);
    });

    test('la racha no se rompe si hoy aún no hay nada', () {
      final s = ProgressStats.from([
        c(DateTime(2026, 11, 6, 8)),
        c(DateTime(2026, 11, 5, 8)),
      ], now);
      expect(s.streakDays, 2);
    });

    test('esta semana cuenta desde el lunes', () {
      final s = ProgressStats.from([
        c(DateTime(2026, 11, 2, 9)), // lunes: cuenta
        c(DateTime(2026, 11, 1, 9)), // domingo anterior: no
        c(DateTime(2026, 11, 7, 9)),
      ], now);
      expect(s.thisWeek, 2);
    });

    test('últimos 7 días: hoy es el último valor', () {
      final s = ProgressStats.from([
        c(DateTime(2026, 11, 7, 8)),
        c(DateTime(2026, 11, 7, 9)),
        c(DateTime(2026, 11, 1, 9)),
      ], now);
      expect(s.lastSevenDays, [1, 0, 0, 0, 0, 0, 2]);
      expect(s.bestDay, 2);
    });
  });

  group('SoundService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sonido de tarea se guarda y se borra en la clave que lee Kotlin', () async {
      await SoundService.instance.syncTaskSound(5, 'raw:tf_zen');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alarm_sound_task_5'), 'raw:tf_zen');
      await SoundService.instance.removeTaskSound(5);
      expect(prefs.getString('alarm_sound_task_5'), isNull);
    });

    test('nombres legibles', () async {
      expect(await SoundService.instance.labelFor(null), 'Predeterminado de la app');
      expect(await SoundService.instance.labelFor('raw:tf_zen'), 'Zen');
      expect(await SoundService.instance.labelFor('default'), 'Alarma del teléfono');
    });

    test('los ids incluidos tienen el formato que acepta Kotlin', () {
      for (final s in SoundService.builtIn) {
        expect(RegExp(r'^raw:tf_[a-z0-9_]+$').hasMatch(s.id), isTrue, reason: s.id);
      }
    });
  });

  group('Navegación', () {
    late FakeDatabaseHelper db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = FakeDatabaseHelper();
      DatabaseHelper.instance = db;
    });

    testWidgets('las secciones Sonidos y Progreso se abren', (tester) async {
      await db.insertTask(
          const Task(title: 'Leer', weekdays: [1, 2, 3, 4, 5, 6, 7], hour: 21, minute: 0));
      await tester.pumpWidget(TaskFlowApp());
      await pumpFrames(tester);

      await tester.tap(find.text('Sonidos'));
      await pumpFrames(tester);
      expect(find.text('Volumen de alarma'), findsOneWidget);
      expect(find.text('Amanecer'), findsOneWidget);

      await tester.tap(find.text('Progreso'));
      await pumpFrames(tester);
      expect(find.text('Hechas esta semana'), findsOneWidget);
      expect(find.text('AGENDA DE LA SEMANA'), findsOneWidget);
    });

    testWidgets('completar una tarea queda en el historial', (tester) async {
      await db.insertTask(
          const Task(title: 'Estudiar', weekdays: [1], hour: 8, minute: 30));
      await tester.pumpWidget(TaskFlowApp());
      await pumpFrames(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('check-1')));
      await tester.tap(find.byKey(const ValueKey('check-1')));
      await pumpFrames(tester);

      expect(db.completions, hasLength(1));
      expect(db.completions.single.title, 'Estudiar');
    });
  });
}
