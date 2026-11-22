import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> defaultWidgetAppearanceControls(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theWidgetAppearanceDialogOpens(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowColorAndOpacityControls(ScenarioState state) =>
    state.advance();

Future<void> aWidgetTextColorThatCanBeEdited(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theTextColorBoxIsTapped(ScenarioState state) => state.advance();

Future<void> theResultShouldOpenTheColorPicker(ScenarioState state) =>
    state.advance();

Future<void> aWidgetColorPickerScreenshotFixture(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theColorPickerDialogOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldMatchTheGoldenScreenshot(ScenarioState state) =>
    state.advance();

Future<void> aWidgetAppearanceScreenshotFixture(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theAppearanceDialogIsSaved(ScenarioState state) => state.advance();

Future<void> theResultShouldCloseTheDialog(ScenarioState state) =>
    state.advance();

Future<void> theUserSavesWidgetAppearance(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldCloseTheDialog(ScenarioState state) =>
    state.advance();

Future<void> customWidgetColorsThatCanBeReset(ScenarioState state) async {
  await state.prepare('4');
}

Future<void> theWidgetAppearanceResetIsRequested(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRestoreDefaults(ScenarioState state) =>
    state.advance();

Future<void> theUserConfirmsTheAppearanceReset(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldRestoreDefaults(ScenarioState state) =>
    state.advance();

Future<void> theResetAppearanceIsSaved(ScenarioState state) => state.advance();

Future<void> customWidgetColorsWhoseEditsCanBeCancelled(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theAppearanceEditsAreCancelled(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRetainSavedColors(ScenarioState state) =>
    state.advance();

Future<void> theAppearanceResetConfirmationIsCancelled(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldRetainSavedColors(ScenarioState state) =>
    state.advance();

Future<void> theAppearanceDialogIsCancelled(ScenarioState state) =>
    state.advance();
