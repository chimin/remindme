import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
  });
}
