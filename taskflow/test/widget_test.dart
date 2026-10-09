import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/main.dart';

void main() {
  testWidgets('TaskFlowApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Mis Tareas'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Empty state shows message', (WidgetTester tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes tareas.\nToca + para agregar una.'), findsOneWidget);
  });
}
