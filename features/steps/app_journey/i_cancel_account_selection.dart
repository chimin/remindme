import 'package:patrol/patrol.dart';

Future<void> iCancelAccountSelection(PatrolIntegrationTester tester) async {
  final $ = tester;
  await $.platform.android.pressBack();
}
