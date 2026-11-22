import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> notesAreEditedForEncodeToPreserveUnknownFields(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> encodeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldPreserveUnknownFields(ScenarioState state) async {
  await state.advance();
}

Future<void> metadataIsMalformedForParseToPreserveNotes(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> parseIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldPreserveNotes(ScenarioState state) async {
  await state.advance();
}

Future<void> metadataVersionIsUnsupportedForParseToPreserveNotes(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> februaryHasFewerDaysForNextDueToRestoreAnchorDay(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> nextDueIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRestoreAnchorDay(ScenarioState state) async {
  await state.advance();
}

Future<void> aTaskIsOverdueForNextDueToSkipMissedDates(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldSkipMissedDates(ScenarioState state) async {
  await state.advance();
}

Future<void> theNextLeapYearArrivesForNextDueToRestoreLeapDay(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theResultShouldRestoreLeapDay(ScenarioState state) async {
  await state.advance();
}

Future<void> intervalIsInvalidForNextDueToIgnoreRecurrence(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> theResultShouldIgnoreRecurrence(ScenarioState state) async {
  await state.advance();
}
