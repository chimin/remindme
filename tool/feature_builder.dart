// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:bdd_widget_test/src/existing_steps.dart';
import 'package:bdd_widget_test/src/feature_file.dart';
import 'package:bdd_widget_test/src/generator_options.dart';
import 'package:bdd_widget_test/src/step_file.dart';
import 'package:bdd_widget_test/src/util/dart_formatter.dart';
import 'package:build/build.dart';

Builder featureTests(BuilderOptions options) => _FeatureTestBuilder(
  GeneratorOptions.fromMap(options.config),
  'test/screens',
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
    final feature = FeatureFile(
      featureDir: outputDirectory,
      package: input.package,
      input: await buildStep.readAsString(input),
      inputPath: input.path,
      existingSteps: getExistingStepSubfolders(outputDirectory, options),
      generatorOptions: options,
    );
    final output = AssetId(
      input.package,
      input.path
          .replaceFirst('features/', '$outputDirectory/')
          .replaceFirst(RegExp(r'\.feature$'), '_test.dart'),
    );
    await buildStep.writeAsString(output, formatDartCode(feature.dartContent));

    for (final step in feature.getStepFiles().whereType<NewStepFile>()) {
      final file = File(step.filename);
      if (!file.existsSync()) {
        await file.create(recursive: true);
        await file.writeAsString(formatDartCode(step.dartContent));
      }
    }
  }
}
