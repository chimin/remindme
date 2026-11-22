import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> noGoogleAccountIsRemembered(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theAppStartsWithoutARememberedAccount(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRequireSignIn(ScenarioState state) =>
    state.advance();

Future<void> thePreviousGoogleSignInAttemptCanBeRetried(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theUserRetriesGoogleSignIn(ScenarioState state) => state.advance();

Future<void> theResultShouldStartSignInAgain(ScenarioState state) =>
    state.advance();

Future<void> googleSignInIsWaitingForAResponse(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theRepositoryRebuildsWhileSignInIsPending(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldAvoidDuplicatePrompts(ScenarioState state) =>
    state.advance();

Future<void> googleSignInWillSucceed(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theAppStartsWithSuccessfulSignIn(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowTasks(ScenarioState state) => state.advance();
