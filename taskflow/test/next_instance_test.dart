import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/app_themes.dart';
import 'package:taskflow/database/database_helper.dart';
import 'package:taskflow/notification_service.dart';
import 'package:taskflow/widgets/task_form_dialog.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'widget_test.dart' show FakeDatabaseHelper;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('nextInstanceOfWeekdayTime', () {
    test('conserva la hora local al cruzar el cambio de horario (DST)', () {
      // Madrid: el domingo 29-mar-2026 a las 2:00 se adelanta a las 3:00.
      final madrid = tz.getLocation('Europe/Madrid');
      final now = tz.TZDateTime(madrid, 2026, 3, 27, 12); // viernes
      final next = NotificationService.nextInstanceOfWeekdayTime(
          now, DateTime.monday, 7, 30);
      expect(next.year, 2026);
      expect(next.month, 3);
      expect(next.day, 30);
      expect(next.hour, 7); // antes salía 8:30 por sumar 24 h exactas
      expect(next.minute, 30);
    });

    test('si la hora de hoy ya pasó, va a la semana siguiente', () {
      final utc = tz.getLocation('UTC');
      final now = tz.TZDateTime(utc, 2026, 11, 2, 9); // lunes 9:00
      final next = NotificationService.nextInstanceOfWeekdayTime(
          now, DateTime.monday, 8, 0);
      expect(next.day, 9);
      expect(next.weekday, DateTime.monday);
    });

    test('si es hoy y aún no llega la hora, es hoy', () {
      final utc = tz.getLocation('UTC');
      final now = tz.TZDateTime(utc, 2026, 11, 2, 7);
      final next = NotificationService.nextInstanceOfWeekdayTime(
          now, DateTime.monday, 8, 0);
      expect(next.day, 2);
      expect(next.hour, 8);
    });
  });

  group('Formulario de tarea', () {
    late FakeDatabaseHelper db;

    setUp(() {
      db = FakeDatabaseHelper();
      DatabaseHelper.instance = db;
    });

    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final theme = appThemeOf(AppThemeId.rosa);
      await tester.pumpWidget(MaterialApp(
        theme: theme.data,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTaskForm(context, theme: theme),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('el atajo Lun a Vie guarda los 5 días ordenados', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField), 'Gimnasio');
      await tester.tap(find.text('Lun a Vie'));
      await tester.pump();
      await tester.tap(find.text('Crear alarma'));
      await tester.pumpAndSettle();

      expect(db.stored, hasLength(1));
      expect(db.stored.single.title, 'Gimnasio');
      expect(db.stored.single.weekdays, [1, 2, 3, 4, 5]);
    });

    testWidgets('sin días no guarda nada', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField), 'Sin días');
      await tester.tap(find.text('Crear alarma'));
      await tester.pump();

      expect(db.stored, isEmpty);
      expect(find.text('Crear alarma'), findsOneWidget);
    });

    testWidgets('el título tiene límite de longitud', (tester) async {
      await openForm(tester);
      await tester.enterText(find.byType(TextFormField), 'x' * 200);
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text.length, kMaxTaskTitle);
    });
  });
}
