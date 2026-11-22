import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../test/screens/golden_test_helper.dart';
import '../scenario_runner.dart';

Future<void> theTestShouldCaptureAScreenshotAs(
  ScenarioState state,
  String path,
) async {
  final result = await captureAndCompare(
    state.tester!,
    find.byType(MaterialApp),
    path,
    'newly_installed',
  );
  expect(result['pass'], isTrue);
}
