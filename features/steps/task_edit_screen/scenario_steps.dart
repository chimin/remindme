import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> aSelectedTaskListWithoutAnExistingTask(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theNewTaskEditorOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldShowEmptyForm(ScenarioState state) =>
    state.advance();

Future<void> aTaskAvailableForDeletion(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theEditorOpensAndTaskDeletionIsRequested(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowConfirmation(ScenarioState state) =>
    state.advance();

Future<void> aTaskWhoseDeletionCanBeCancelled(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theUserRequestsOrConfirmsTaskDeletion(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRetainTheEditor(ScenarioState state) =>
    state.advance();

Future<void> aTaskWhoseDeletionWillSucceed(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theResultShouldReturnToThePreviousScreen(ScenarioState state) =>
    state.advance();

Future<void> aTaskWhoseDeletionIsPending(ScenarioState state) async {
  await state.prepare('4');
}

Future<void> theResultShouldDisableSaveAndDeleteActions(ScenarioState state) =>
    state.advance();

Future<void> aTaskWhoseDeletionWillFail(ScenarioState state) async {
  await state.prepare('5');
}

Future<void> theResultShouldShowAnErrorAndRetainTheEditor(
  ScenarioState state,
) => state.advance();

Future<void> aRepeatingTaskWithExtensibleMetadata(ScenarioState state) async {
  await state.prepare('6');
}

Future<void> theUserEditsAndSavesTheTask(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldPreserveExtensibleMetadata(ScenarioState state) =>
    state.advance();

Future<void> theRepeatingTaskIsSaved(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldPreserveExtensibleMetadata(
  ScenarioState state,
) => state.advance();

Future<void> aRepeatSelectionWithoutADueDate(ScenarioState state) async {
  await state.prepare('7');
}

Future<void> theResultShouldRequireADueDate(ScenarioState state) =>
    state.advance();

Future<void> aTaskWithRecurrenceThatCanBeDisabled(ScenarioState state) async {
  await state.prepare('8');
}

Future<void> theResultShouldRemoveOnlyRecurrence(ScenarioState state) =>
    state.advance();

Future<void> aTaskWithAnUnknownRecurrenceRule(ScenarioState state) async {
  await state.prepare('9');
}

Future<void> theResultShouldPreserveAnUnknownRule(ScenarioState state) =>
    state.advance();

Future<void> anEditorWithReducedKeyboardSpace(ScenarioState state) async {
  await state.prepare('10');
}

Future<void> theResultShouldRemainReachable(ScenarioState state) =>
    state.advance();

Future<void> anEditableDueDateField(ScenarioState state) async {
  await state.prepare('11');
}

Future<void> theDueDateFieldIsTapped(ScenarioState state) => state.advance();

Future<void> theResultShouldOpenThePickerFromTheFieldSurface(
  ScenarioState state,
) => state.advance();

Future<void> theUserTapsNoDueDate(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldOpenThePickerFromTheFieldSurface(
  ScenarioState state,
) => state.advance();

Future<void> theSelectedDueDateIsAccepted(ScenarioState state) =>
    state.advance();

Future<void> theDueDateIsCleared(ScenarioState state) => state.advance();

Future<void> theTaskWithoutADueDateIsSaved(ScenarioState state) =>
    state.advance();

Future<void> anIncompleteTaskWithEditorActions(ScenarioState state) async {
  await state.prepare('12');
}

Future<void> theTaskEditorOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldPlaceSaveAfterDelete(ScenarioState state) =>
    state.advance();

Future<void> aCompletedTaskWithReadOnlyFields(ScenarioState state) async {
  await state.prepare('13');
}

Future<void> theResultShouldPreventFieldChanges(ScenarioState state) =>
    state.advance();

Future<void> theCompletedTaskDueDateFieldIsTapped(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldPreventFieldChanges(ScenarioState state) =>
    state.advance();

Future<void> anIncompleteTaskWithEditedFields(ScenarioState state) async {
  await state.prepare('14');
}

Future<void> theTaskIsMarkedCompleted(ScenarioState state) => state.advance();

Future<void> theResultShouldSaveEditedFieldsAndReturnHome(
  ScenarioState state,
) => state.advance();

Future<void> aCompletedTaskThatCanBecomeIncomplete(ScenarioState state) async {
  await state.prepare('15');
}

Future<void> theCompletedTaskEditorOpens(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRetainFieldsAndEnableEditing(ScenarioState state) =>
    state.advance();

Future<void> theTaskIsMarkedIncomplete(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldRetainFieldsAndEnableEditing(
  ScenarioState state,
) => state.advance();

Future<void> theUnlockedTitleIsEditedAndSaved(ScenarioState state) =>
    state.advance();

Future<void> anIncompleteTaskWithInvalidFields(ScenarioState state) async {
  await state.prepare('16');
}

Future<void> aCompletedTaskWithAnEmptyTitle(ScenarioState state) async {
  await state.prepare('17');
}

Future<void> theResultShouldSkipValidation(ScenarioState state) =>
    state.advance();

Future<void> aCompletedTaskWhoseUpdateWillFail(ScenarioState state) async {
  await state.prepare('18');
}

Future<void> theResultShouldRemainReadOnly(ScenarioState state) =>
    state.advance();

Future<void> anIncompleteTaskWhoseUpdateIsPending(ScenarioState state) async {
  await state.prepare('19');
}

Future<void> theCompletionCallbackIsInvokedTwiceWhileSavingIsPending(
  ScenarioState state,
) => state.advance();

Future<void> theResultShouldDisableOtherActions(ScenarioState state) =>
    state.advance();

Future<void> thePendingTaskSaveCompletes(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldDisableOtherActions(ScenarioState state) =>
    state.advance();

Future<void> editedTaskFieldsWhoseSaveWillFail(ScenarioState state) async {
  await state.prepare('20');
}

Future<void> theResultShouldRetainEditedFields(ScenarioState state) =>
    state.advance();

Future<void> aCompletedTaskAvailableForDeletion(ScenarioState state) async {
  await state.prepare('21');
}

Future<void> theResultShouldRemainAvailable(ScenarioState state) =>
    state.advance();
