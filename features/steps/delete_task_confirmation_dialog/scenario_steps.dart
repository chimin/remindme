import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> aTaskTitledWaterPlants(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theDeletionDialogOpensOrIsDismissed(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldDisplayTheTaskTitle(ScenarioState state) =>
    state.advance();

Future<void> aTaskDeletionDialogWithTheSelectedDismissalAction(
  ScenarioState state,
  String action,
) async {
  await state.prepare('1:$action');
}

Future<void> theResultShouldReturnTheSelectedResult(ScenarioState state) =>
    state.advance();
