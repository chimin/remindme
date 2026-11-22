import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> noAccountWasSavedForInitializeToLeaveLinkingToTheForeground(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> initializeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldLeaveLinkingToTheForeground(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> theDeviceIsOfflineForInitializeToPreserveCachedAccountAccess(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theResultShouldPreserveCachedAccountAccess(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> authorizationSucceedsForLinkToRememberTheAccount(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> linkIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRememberTheAccount(ScenarioState state) async {
  await state.advance();
}

Future<void> accountSelectionIsCanceledForLinkToAllowRetry(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldAllowRetry(ScenarioState state) async {
  await state.advance();
}

Future<void> linkContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> requestsOverlapForLinkToShareTheActiveAttempt(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldShareTheActiveAttempt(ScenarioState state) async {
  await state.advance();
}

Future<void> aDifferentAccountIsReturnedForLinkToPreserveTheCacheOwner(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theResultShouldPreserveTheCacheOwner(ScenarioState state) async {
  await state.advance();
}

Future<void> migrationVerificationFailsForLinkToPreserveUnownedData(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> theResultShouldPreserveUnownedData(ScenarioState state) async {
  await state.advance();
}

Future<void> theUserDisconnectsForLinkToIgnoreLateAuthorization(
  ScenarioState state,
) async {
  await state.prepare('7');
}

Future<void> theResultShouldIgnoreLateAuthorization(ScenarioState state) async {
  await state.advance();
}

Future<void> requestsOverlapForTokenRequestToShareSilentAuthorization(
  ScenarioState state,
) async {
  await state.prepare('8');
}

Future<void> tokenRequestIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldShareSilentAuthorization(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> tokenRequestContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> consentIsRequiredForTokenRequestToPreserveTheLinkedAccount(
  ScenarioState state,
) async {
  await state.prepare('9');
}

Future<void> theResultShouldPreserveTheLinkedAccount(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> authorizationSucceedsForReconnectToClearTheWarning(
  ScenarioState state,
) async {
  await state.prepare('10');
}

Future<void> reconnectIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldClearTheWarning(ScenarioState state) async {
  await state.advance();
}

Future<void> cleanupFailsForSignOutToForgetOnlyTheAppConnection(
  ScenarioState state,
) async {
  await state.prepare('11');
}

Future<void> signOutIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldForgetOnlyTheAppConnection(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> postlinkSyncFailsForLinkToRetainAuthorization(
  ScenarioState state,
) async {
  await state.prepare('12');
}

Future<void> theResultShouldRetainAuthorization(ScenarioState state) async {
  await state.advance();
}
