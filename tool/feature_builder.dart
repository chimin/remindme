// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:bdd_widget_test/src/existing_steps.dart';
import 'package:bdd_widget_test/src/feature_file.dart';
import 'package:bdd_widget_test/src/generator_options.dart';
import 'package:bdd_widget_test/src/step_file.dart';
import 'package:bdd_widget_test/src/step_generator.dart';
import 'package:bdd_widget_test/src/util/dart_formatter.dart';
import 'package:build/build.dart';

Builder featureTests(BuilderOptions options) => _FeatureTestBuilder(
  GeneratorOptions.fromMap(options.config),
  'test/features',
);

Builder patrolFeatureTests(BuilderOptions options) => _FeatureTestBuilder(
  GeneratorOptions.fromMap(options.config),
  'patrol_test',
);

class _FeatureTestBuilder implements Builder {
  _FeatureTestBuilder(this.options, this.outputDirectory);

  final GeneratorOptions options;
  final String outputDirectory;

  @override
  Map<String, List<String>> get buildExtensions => {
    '^features/{{}}.feature': ['$outputDirectory/{{}}_test.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final ordinary = outputDirectory == 'test/features';
    final outputPath = input.path
        .replaceFirst('features/', '$outputDirectory/')
        .replaceFirst(RegExp(r'\.feature$'), '_test.dart');
    final directory = outputPath.substring(0, outputPath.lastIndexOf('/'));
    final category = ordinary
        ? input.path.split('/').last.replaceFirst('.feature', '')
        : 'app_journey';
    final relativeSteps =
        '${directory.split('/').map((_) => '..').join('/')}/features/steps';
    final categoryOptions = ordinary
        ? GeneratorOptions.fromMap({
            'stepFolderName': '$relativeSteps/$category',
            'customHeaders': [
              "import 'package:flutter_test/flutter_test.dart';",
              "import '$relativeSteps/scenario_runner.dart';",
              "import '$relativeSteps/$category/scenario_context.dart';",
            ],
          })
        : options;
    final feature = FeatureFile(
      featureDir: directory,
      package: input.package,
      input: await buildStep.readAsString(input),
      inputPath: input.path,
      existingSteps: getExistingStepSubfolders(directory, categoryOptions),
      generatorOptions: categoryOptions,
    );
    var content = feature.dartContent;
    if (ordinary) {
      final stepsPath = 'features/steps/$category/scenario_steps.dart';
      final steps = await buildStep.readAsString(
        AssetId(input.package, stepsPath),
      );
      for (final step in feature.getStepFiles().whereType<NewStepFile>()) {
        final name = getStepMethodName(step.line);
        if (!RegExp('\\b$name\\s*\\(').hasMatch(steps)) {
          throw StateError('Missing step $name in $stepsPath');
        }
        content = content.replaceAll(
          "import '${step.import}';",
          "import '$relativeSteps/$category/scenario_steps.dart';",
        );
      }
      // Several step functions can share a category file.
      final lines = content.split('\n');
      final imports = <String>{};
      content = lines
          .where((line) => !line.startsWith('import ') || imports.add(line))
          .join('\n');
      content = content.replaceFirst(
        'void main() {',
        'void main() {\n final scenarios = defineScenarios();',
      );
      content = content
          .replaceAll('widgetScenario(', 'widgetScenario(scenarios, ')
          .replaceAll('unitScenario(', 'unitScenario(scenarios, ');
    }
    await buildStep.writeAsString(
      AssetId(input.package, outputPath),
      formatDartCode(content),
    );
    if (ordinary) return;

    for (final step in feature.getStepFiles().whereType<NewStepFile>()) {
      final file = File(step.filename);
      if (!file.existsSync()) {
        await file.create(recursive: true);
        await file.writeAsString(formatDartCode(step.dartContent));
      }
    }
  }
}
