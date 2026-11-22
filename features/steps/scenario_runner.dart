import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ScenarioFactory = Future<void> Function(ScenarioState state);
typedef ScenarioCases = Map<String, ScenarioFactory>;

// Continuations keep each scenario's typed locals alive across Gherkin steps.
class ScenarioState {
  ScenarioState(this.cases, [this.tester]);

  final ScenarioCases cases;
  final WidgetTester? tester;
  Future<void> Function()? next;
  bool _prepared = false;
  bool _initialized = false;

  void initialize() {
    if (_initialized) throw StateError('Scenario state is already initialized');
    _initialized = true;
    addTearDown(() => next = null);
    final widgetTester = tester;
    if (widgetTester == null) return;
    addTearDown(() {
      final messenger = widgetTester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        null,
      );
      messenger.setMockStreamHandler(
        const EventChannel('home_widget/updates'),
        null,
      );
    });
  }

  Future<void> prepare(String key) async {
    if (!_initialized) throw StateError('Scenario state is not initialized');
    if (_prepared) throw StateError('A scenario is already prepared');
    _prepared = true;
    final factory = cases[key];
    if (factory == null) throw StateError('Unknown scenario: $key');
    await factory(this);
  }

  Future<void> advance() async {
    final action = next;
    if (action == null) throw StateError('No scenario step remains');
    next = null;
    await action();
  }

  void verifyComplete() {
    if (next != null) throw StateError('Scenario has unexecuted steps');
  }
}

void widgetScenario(
  ScenarioCases cases,
  String description,
  Future<void> Function(ScenarioState) body,
) {
  testWidgets(description, (tester) async {
    final state = ScenarioState(cases, tester);
    await body(state);
    state.verifyComplete();
  });
}

void unitScenario(
  ScenarioCases cases,
  String description,
  Future<void> Function(ScenarioState) body,
) {
  test(description, () async {
    final state = ScenarioState(cases);
    await body(state);
    state.verifyComplete();
  });
}
