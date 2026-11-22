import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> aColdWidgetLaunchForListB(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theWidgetLaunchesTheApp(ScenarioState state) => state.advance();

Future<void> theResultShouldOpenItsOwningTask(ScenarioState state) =>
    state.advance();

Future<void> tasksInTwoListsWithUnsavedEditorChanges(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theWidgetDeliversATaskLink(ScenarioState state) => state.advance();

Future<void> theResultShouldDiscardUnsavedEdits(ScenarioState state) =>
    state.advance();

Future<void> theUserReturnsFromTheWidgetTaskEditor(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldDiscardUnsavedEdits(ScenarioState state) =>
    state.advance();

Future<void> aWidgetLaunchWaitingForAuthentication(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theResultShouldWaitForAuthentication(ScenarioState state) =>
    state.advance();

Future<void> googleAuthenticationFinishes(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldWaitForAuthentication(ScenarioState state) =>
    state.advance();

Future<void> aStaleWidgetEntryForACompletedTask(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theResultShouldOpenAReadOnlyTask(ScenarioState state) =>
    state.advance();

Future<void> aWidgetLaunchThatCanBeDeliveredTwice(ScenarioState state) async {
  await state.prepare('4');
}

Future<void> theResultShouldOpenOneEditor(ScenarioState state) =>
    state.advance();

Future<void> theUserReturnsAfterTheDuplicateWidgetLaunch(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldOpenOneEditor(ScenarioState state) =>
    state.advance();

Future<void> theSameWidgetTaskIsTappedAfterReturningHome(ScenarioState state) =>
    state.advance();

Future<void> anUncachedTaskRecoverableByRefresh(ScenarioState state) async {
  await state.prepare('5');
}

Future<void> theResultShouldRefreshOnce(ScenarioState state) => state.advance();

Future<void> anUnavailableWidgetTaskInTheSelectedNetworkState(
  ScenarioState state,
  bool offline,
) async {
  await state.prepare('6:$offline');
}

Future<void> theResultShouldExplainUnavailability(ScenarioState state) =>
    state.advance();

Future<void> widgetTaskLookupsThatCanOverlap(ScenarioState state) async {
  await state.prepare('7');
}

Future<void> theResultShouldPreferTheLatestTask(ScenarioState state) =>
    state.advance();

Future<void> aWidgetLinkWithoutTaskIdentity(ScenarioState state) async {
  await state.prepare('8');
}

Future<void> theResultShouldOpenHome(ScenarioState state) => state.advance();
