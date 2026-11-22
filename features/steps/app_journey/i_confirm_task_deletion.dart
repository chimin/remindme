import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

Future<void> iConfirmTaskDeletion(PatrolIntegrationTester tester) async {
  final $ = tester;
  await $(find.widgetWithText(FilledButton, 'Delete')).tap();
}
