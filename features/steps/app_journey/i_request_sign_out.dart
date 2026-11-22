import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

Future<void> iRequestSignOut(PatrolIntegrationTester tester) async {
  final $ = tester;
  await $(find.byTooltip('Menu')).tap();
  await $(find.text('Sign out')).tap();
}
