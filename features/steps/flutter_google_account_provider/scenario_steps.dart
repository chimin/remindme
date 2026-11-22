import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> theUserSelectsAnAccountForLinkToAuthorizeTasks(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> linkIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldAuthorizeTasks(ScenarioState state) async {
  await state.advance();
}

Future<void>
accessIsRequestedSilentlyForAuthorizeToRestoreTheRememberedIdentity(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> authorizeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRestoreTheRememberedIdentity(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
restorationReturnsNoAccountForAuthorizeToRequireExplicitReconnection(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> theResultShouldRequireExplicitReconnection(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
restoringTheRememberedAccountForAuthorizeToRejectADifferentIdentity(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldRejectADifferentIdentity(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> scopesNeedInteractiveApprovalForAuthorizeToAvoidConsentUi(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldAvoidConsentUi(ScenarioState state) async {
  await state.advance();
}

Future<void> theLocalConnectionIsRemovedForForgetToRetainGooglePermissions(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> forgetIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRetainGooglePermissions(ScenarioState state) async {
  await state.advance();
}

Future<void> theIosClientIdIsMissingForInitializeToReportConfigurationFailure(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> initializeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldReportConfigurationFailure(
  ScenarioState state,
) async {
  await state.advance();
}
