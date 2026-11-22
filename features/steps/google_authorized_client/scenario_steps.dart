import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> theServerRejectsAnExpiredTokenForSendToReplayTheBodyOnce(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> sendIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldReplayTheBodyOnce(ScenarioState state) async {
  await state.advance();
}

Future<void> aFreshTokenIsAlsoRejectedForSendToRequireReconnection(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theResultShouldRequireReconnection(ScenarioState state) async {
  await state.advance();
}

Future<void> theConnectionDropsForSendToAvoidReplayingAWrite(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> theResultShouldAvoidReplayingAWrite(ScenarioState state) async {
  await state.advance();
}

Future<void> theAccountChangesForSendToRejectStaleResponses(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldRejectStaleResponses(ScenarioState state) async {
  await state.advance();
}

Future<void> theirAccountSessionWasReplacedForSendToIgnoreRejectedCredentials(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldIgnoreRejectedCredentials(
  ScenarioState state,
) async {
  await state.advance();
}
