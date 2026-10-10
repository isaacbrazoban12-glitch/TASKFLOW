import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:taskflow/database/database_helper.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/task.dart';

/// BD mockeada en memoria: evita sqlite nativo en tests de widgets.
class FakeDatabaseHelper extends DatabaseHelper {
  FakeDatabaseHelper() : super.test();

  final List<Task> stored = [];
  int _nextId = 1;

  @override
  Future<List<Task>> getTasks() async => List<Task>.of(stored);

  @override
  Future<int> insertTask(Task task) async {
    final saved = task.copyWith(id: _nextId++);
    stored.add(saved);
    return saved.id!;
  }

  @override
  Future<int> updateTask(Task task) async {
    final index = stored.indexWhere((t) => t.id == task.id);
    if (index < 0) throw StateError('Tarea no encontrada');
    stored[index] = task;
    return 1;
  }

  @override
  Future<int> deleteTask(int id) async {
    stored.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<Database> get database => throw UnimplementedError('Fake sin BD real');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.instance = FakeDatabaseHelper();
  });

  testWidgets('TaskFlowApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Mis Tareas'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Empty state shows message', (WidgetTester tester) async {
    await tester.pumpWidget(TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes tareas.\nToca + para agregar una.'), findsOneWidget);
  });

  testWidgets('Muestra las tareas guardadas en la BD', (WidgetTester tester) async {
    await DatabaseHelper.instance.insertTask(
      const Task(title: 'Regar plantas', weekdays: [1], hour: 8, minute: 30),
    );

    await tester.pumpWidget(TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Regar plantas'), findsOneWidget);
    expect(
      find.text('Aún no tienes tareas.\nToca + para agregar una.'),
      findsNothing,
    );
  });

  testWidgets('Completar desde el checkbox tacha la tarea', (WidgetTester tester) async {
    await DatabaseHelper.instance.insertTask(
      const Task(title: 'Estudiar', weekdays: [1], hour: 8, minute: 30),
    );

    await tester.pumpWidget(TaskFlowApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Estudiar'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });
}
