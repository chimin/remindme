import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> settingsAreAbsentForLoadToEnableRemindersAtEight(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> loadIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldEnableRemindersAtEight(ScenarioState state) async {
  await state.advance();
}

Future<void> settingsReloadForSaveToRestoreEnabledStateAndTime(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> saveIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRestoreEnabledStateAndTime(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> previousWorkIsDelayedForRefreshToLeaveCancellationLast(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> refreshIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldLeaveCancellationLast(ScenarioState state) async {
  await state.advance();
}

Future<void> remindersAreDisabledForRefreshToReplaceWithDisabledSettings(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldReplaceWithDisabledSettings(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> thePlatformDeniesARequestForRefreshToContinueProcessing(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldContinueProcessing(ScenarioState state) async {
  await state.advance();
}

Future<void> theAppOpensForRefreshToRequestImmediateDelivery(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theResultShouldRequestImmediateDelivery(
  ScenarioState state,
) async {
  await state.advance();
}
