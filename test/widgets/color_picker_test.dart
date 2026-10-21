import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/widgets/color_picker.dart';

void main() {
  test('formatHex should render six digit uppercase hex', () {
    expect(ColorPicker.formatHex(const Color(0xFFFF0000)), '#FF0000');
    expect(ColorPicker.formatHex(const Color(0xFF123456)), '#123456');
  });

  test('parseHex should return null when value is invalid', () {
    expect(ColorPicker.parseHex(''), isNull);
    expect(ColorPicker.parseHex('#12'), isNull);
    expect(ColorPicker.parseHex('nothex'), isNull);
  });

  test('parseHex should accept long and short hex', () {
    expect(ColorPicker.parseHex('#FF0000'), const Color(0xFFFF0000));
    expect(ColorPicker.parseHex('00FF00'), const Color(0xFF00FF00));
    expect(ColorPicker.parseHex('#00F'), const Color(0xFF0000FF));
  });

  testWidgets(
    'picking a color should call onChanged with the new color',
    (WidgetTester tester) async {
      Color? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPicker(
              color: const Color(0xFFFF0000),
              onChanged: (c) => picked = c,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '#00FF00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(picked, const Color(0xFF00FF00));
    },
  );

  testWidgets(
    'dragging the hue slider should change the selected color',
    (WidgetTester tester) async {
      Color? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ColorPicker(
                color: const Color(0xFFFF0000),
                onChanged: (c) => picked = c,
              ),
            ),
          ),
        ),
      );

      final hueSlider = find.byType(GestureDetector).at(1);
      await tester.tapAt(tester.getCenter(hueSlider));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked, isNot(const Color(0xFFFF0000)));
    },
  );
}
