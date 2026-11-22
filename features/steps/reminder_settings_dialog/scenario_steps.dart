import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> defaultRemindersThatCanBeCancelled(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theReminderSwitchChangesAndTheDialogIsCancelled(
  ScenarioState state,
) => state.advance();

Future<void> theResultShouldDiscardChanges(ScenarioState state) =>
    state.advance();

Future<void> defaultRemindersThatCanBeSaved(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theReminderSwitchChangesAndTheDialogIsSaved(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldReturnEditedSettings(ScenarioState state) =>
    state.advance();

Future<void> defaultReminderControls(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theReminderSettingsOpen(ScenarioState state) => state.advance();

Future<void> theResultShouldShowTheReminderControls(ScenarioState state) =>
    state.advance();

Future<void> theReminderSwitchIsToggledOffAndOn(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldShowTheReminderControls(ScenarioState state) =>
    state.advance();

Future<void> aReminderTimeThatCanBeEdited(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theReminderTimePickerOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldReturnTheNewTime(ScenarioState state) =>
    state.advance();

Future<void> theUserSelects2115InKeyboardMode(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldReturnTheNewTime(ScenarioState state) =>
    state.advance();

Future<void> theReminderTimePickerReopens(ScenarioState state) =>
    state.advance();

Future<void> theTimePickerClosesAndTheReminderSettingsAreSaved(
  ScenarioState state,
) => state.advance();

Future<void> aReminderTimeSelectionThatCanBeCancelled(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theTimePickerOpensForCancellation(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldKeepTheTime(ScenarioState state) => state.advance();

Future<void> theUserOpensAndCancelsTheTimePicker(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldKeepTheTime(ScenarioState state) =>
    state.advance();

Future<void> theReminderSettingsAreSaved(ScenarioState state) =>
    state.advance();
