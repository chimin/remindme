// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/widgets/color_picker.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};
  scenarios['0'] = (state) async {
    const colors = [Color(0xFFFF0000), Color(0xFF123456)];
    late List<String> formatted;
    state.next = () async {
      formatted = colors.map(ColorPicker.formatHex).toList();
      state.next = () async {
        expect(formatted[0], '#FF0000');
        expect(formatted[1], '#123456');
      };
    };
  };
  scenarios['1'] = (state) async {
    const inputs = ['', '#12', 'nothex'];
    late List<Color?> parsed;
    state.next = () async {
      parsed = inputs.map(ColorPicker.parseHex).toList();
      state.next = () async {
        expect(parsed[0], isNull);
        expect(parsed[1], isNull);
        expect(parsed[2], isNull);
      };
    };
  };
  scenarios['2'] = (state) async {
    const inputs = ['#FF0000', '00FF00', '#00F'];
    late List<Color?> parsed;
    state.next = () async {
      parsed = inputs.map(ColorPicker.parseHex).toList();
      state.next = () async {
        expect(parsed[0], const Color(0xFFFF0000));
        expect(parsed[1], const Color(0xFF00FF00));
        expect(parsed[2], const Color(0xFF0000FF));
      };
    };
  };

  scenarios['3'] = (state) async {
    final tester = state.tester!;
    Color? picked;
    state.next = () async {
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
      state.next = () async {
        expect(picked, const Color(0xFF00FF00));
      };
    };
  };

  scenarios['4'] = (state) async {
    final tester = state.tester!;
    Color? picked;
    state.next = () async {
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
      state.next = () async {
        expect(picked, isNotNull);
        expect(picked, isNot(const Color(0xFFFF0000)));
      };
    };
  };
  return scenarios;
}
