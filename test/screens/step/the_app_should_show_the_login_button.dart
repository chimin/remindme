import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theAppShouldShowTheLoginButton(
  WidgetTester tester,
  String label,
) async {
  final button = find.widgetWithText(OutlinedButton, label);
  expect(button, findsOneWidget);
  expect(button.hitTestable(), findsOneWidget);
}
