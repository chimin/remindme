import 'dart:io';

import 'package:build/build.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/feature_builder.dart';

class _MemoryBuildStep implements BuildStep {
  _MemoryBuildStep(String input, this.assets)
    : inputId = AssetId('remindme', input);

  @override
  final AssetId inputId;
  final Map<String, String> assets;
  final outputs = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #readAsString) {
      final id = invocation.positionalArguments.first as AssetId;
      return Future<String>.value(
        assets[id.path] ?? File(id.path).readAsStringSync(),
      );
    }
    if (invocation.memberName == #writeAsString) {
      final id = invocation.positionalArguments[0] as AssetId;
      outputs[id.path] = invocation.positionalArguments[1] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

const _feature = '''
@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: Shared wording
  Scenario: opening should use its category when another category shares a step
    Given a shared condition
''';

void main() {
  test(
    'generation should use feature basenames when ordinary feature outputs are configured',
    () {
      final extensions = featureTests(BuilderOptions.empty).buildExtensions;
      expect(extensions, {
        '^features/{{}}.feature': ['test/features/{{}}_test.dart'],
      });
    },
  );

  test(
    'generation should isolate step imports when two categories share a step name',
    () async {
      final builder = featureTests(BuilderOptions.empty);
      for (final category in ['login_screen', 'color_picker']) {
        final step = _MemoryBuildStep('features/$category.feature', {
          'features/$category.feature': _feature,
          'features/steps/$category/scenario_steps.dart':
              'Future<void> aSharedCondition(ScenarioState state) async {}',
        });
        await builder.build(step);
        expect(step.outputs.keys, ['test/features/${category}_test.dart']);
        final output = step.outputs.values.single;
        expect(
          output,
          contains(
            "import '../../features/steps/$category/scenario_steps.dart';",
          ),
        );
        expect(
          output,
          isNot(
            contains(
              '/${category == 'login_screen' ? 'color_picker' : 'login_screen'}/',
            ),
          ),
        );
        expect(output, contains('widgetScenario(scenarios,'));
      }
    },
  );

  test(
    'generation should reject missing steps when only another category supplies them',
    () async {
      final step = _MemoryBuildStep('features/login_screen.feature', {
        'features/login_screen.feature': _feature,
        'features/steps/login_screen/scenario_steps.dart': '',
        'features/steps/color_picker/scenario_steps.dart':
            'Future<void> aSharedCondition(ScenarioState state) async {}',
      });
      await expectLater(
        featureTests(BuilderOptions.empty).build(step),
        throwsStateError,
      );
      expect(step.outputs, isEmpty);
    },
  );

  test(
    'generation should retain runner overrides when unit and widget scenarios share a feature',
    () async {
      final step = _MemoryBuildStep('features/color_picker.feature', {
        'features/color_picker.feature':
            '''
$_feature
  @testMethodName:unitScenario
  Scenario: parsing should use an ordinary test when no widget is needed
    Given a shared condition
''',
        'features/steps/color_picker/scenario_steps.dart':
            'Future<void> aSharedCondition(ScenarioState state) async {}',
      });
      await featureTests(BuilderOptions.empty).build(step);
      final output = step.outputs.values.single;
      expect(output, contains('widgetScenario(scenarios,'));
      expect(output, contains('unitScenario(scenarios,'));
    },
  );
}
