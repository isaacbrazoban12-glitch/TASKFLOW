// TEMPORAL solo para la auditoría visual: genera PNG en docs/screens/
// con --update-goldens. NO commitear este fichero.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow/database/database_helper.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/widgets/alarm_dialog.dart';

import 'widget_test.dart' show FakeDatabaseHelper;

const String screens = '../../docs/screens';

Future<void> _seedList() async {
  final db = DatabaseHelper.instance;
  await db.insertTask(const Task(title: 'Reunión semanal', weekdays: [1], hour: 9, minute: 0));
  await db.insertTask(const Task(title: 'Gimnasio', weekdays: [2, 4], hour: 7, minute: 30));
  await db.insertTask(const Task(title: 'Leer 20 minutos', weekdays: [1, 3, 5], hour: 22, minute: 0));
  await db.insertTask(const Task(
    title: 'Informe mensual',
    weekdays: [5],
    hour: 18,
    minute: 0,
    repeats: false,
    completed: true,
  ));
  await db.insertTask(const Task(title: 'Llamar a mamá', weekdays: [7], hour: 12, minute: 0));
  await db.insertTask(const Task(
    title: 'Curso online',
    weekdays: [3],
    hour: 20,
    minute: 15,
    stopOnComplete: true,
    completed: true,
  ));
}

void main() {
  setUpAll(() async {
    // Fuente real para que el texto sea legible en las capturas.
    final regular = await File(r'C:\Windows\Fonts\arial.ttf').readAsBytes();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(regular))))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.instance = FakeDatabaseHelper();
  });

  tearDown(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.clearAllTestValues();
  });

  testWidgets('cap01 lista vacia claro', (tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/01-empty-light.png'));
  });

  testWidgets('cap02 lista con tareas claro', (tester) async {
    await _seedList();
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    final iconSize = tester.getSize(find.byIcon(Icons.add).first);
    final checkSize = tester.getSize(find.byType(Checkbox).first);
    final tileSize = tester.getSize(find.byType(ListTile).first);
    debugPrint('MEDIDAS iconAdd=$iconSize checkbox=$checkSize tileH=${tileSize.height}');
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/02-list-light.png'));
  });

  testWidgets('cap03 formulario nueva tarea', (tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/03-new-form-light.png'));
  });

  testWidgets('cap04 formulario edicion', (tester) async {
    await _seedList();
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gimnasio'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/04-edit-form-light.png'));
  });

  testWidgets('cap05 alarm dialog claro', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AlarmDialog(
        taskId: 1,
        taskTitle: 'Reunión semanal',
        weekday: 1,
        onCompleted: () {},
        onSnoozed: () {},
      ),
    ));
    await tester.pumpAndSettle();
    final btn = tester.getSize(find.widgetWithText(ElevatedButton, 'Voy a realizar la tarea'));
    debugPrint('MEDIDAS alarmBtn=$btn');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$screens/05-alarm-dialog-light.png'));
  });

  testWidgets('cap06 lista oscuro', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _seedList();
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/06-list-dark.png'));
  });

  testWidgets('cap07 alarm dialog oscuro', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(MaterialApp(
      home: AlarmDialog(
        taskId: 1,
        taskTitle: 'Reunión semanal',
        weekday: 1,
        onCompleted: () {},
        onSnoozed: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$screens/07-alarm-dialog-dark.png'));
  });

  testWidgets('cap08 lista fuente 150', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await _seedList();
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
    await expectLater(find.byType(TaskFlowApp), matchesGoldenFile('$screens/08-list-scale150-light.png'));
  });
}
