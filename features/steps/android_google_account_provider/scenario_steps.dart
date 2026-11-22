import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> linkingStartsForLinkToPinAuthorizationToTheSelectedAccount(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> linkIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldPinAuthorizationToTheSelectedAccount(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> restoringSilentlyForAuthorizeToProhibitNativeUi(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> authorizeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldProhibitNativeUi(ScenarioState state) async {
  await state.advance();
}

Future<void> anAccountIsRememberedForReconnectToBypassAccountSelection(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> reconnectIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldBypassAccountSelection(ScenarioState state) async {
  await state.advance();
}

Future<void> interactionIsRequiredForAuthorizeToNormalizeNativeResolution(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldNormalizeNativeResolution(
  ScenarioState state,
) async {
  await state.advance();
}
