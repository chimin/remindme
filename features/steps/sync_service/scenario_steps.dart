import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void>
foregroundStorageIsOwnedForBackgroundSyncToDeferWithoutCreatingARepository(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> backgroundSyncIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldDeferWithoutCreatingARepository(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> noAccountIsLinkedForBackgroundSyncToReleaseStorage(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theResultShouldReleaseStorage(ScenarioState state) async {
  await state.advance();
}

Future<void> backgroundSyncContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> interactionIsRequiredForBackgroundSyncToAvoidRetryingConsent(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> theResultShouldAvoidRetryingConsent(ScenarioState state) async {
  await state.advance();
}

Future<void> refreshRequestsOverlapForSyncToShareOnePushAndPull(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> syncIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldShareOnePushAndPull(ScenarioState state) async {
  await state.advance();
}

Future<void> syncContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> aSharedRefreshFailsForSyncToAllowRetry(ScenarioState state) async {
  await state.prepare('4');
}

Future<void> theResultShouldAllowRetry(ScenarioState state) async {
  await state.advance();
}

Future<void>
aTasklistIsSelectedForSyncToPushDirtyLocalChangesToRemoteThenPullRemote(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theResultShouldPushDirtyLocalChangesToRemoteThenPullRemote(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> tasksHaveNoLocalChangesForSyncToSkipCleanEntries(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> theResultShouldSkipCleanEntries(ScenarioState state) async {
  await state.advance();
}

Future<void> noTasklistIsSelectedForSyncToDoNothing(ScenarioState state) async {
  await state.prepare('7');
}

Future<void> theResultShouldDoNothing(ScenarioState state) async {
  await state.advance();
}
