import '../scenario_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theAppShouldShowTheLoginButton(
  ScenarioState state,
  String label,
) async {
  final button = find.widgetWithText(OutlinedButton, label);
  expect(button, findsOneWidget);
  expect(button.hitTestable(), findsOneWidget);
}
