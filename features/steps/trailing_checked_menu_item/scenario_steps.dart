import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> aCheckedTaskListMenuItem(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theConfiguredTaskListMenuOpens(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowTheCheckmarkOnTheRight(ScenarioState state) =>
    state.advance();

Future<void> anUncheckedTaskListMenuItem(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theResultShouldHideTheCheckmark(ScenarioState state) =>
    state.advance();

Future<void> aCheckedTaskListMenuItemWithSemantics(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theResultShouldReportTheCheckedStateToAccessibilityTools(
  ScenarioState state,
) => state.advance();

Future<void> aCheckedTaskListMenuItemWithALongLabel(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theResultShouldFitTheMenuWidth(ScenarioState state) =>
    state.advance();
