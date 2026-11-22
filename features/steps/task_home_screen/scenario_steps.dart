import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> visibleTasksWithAnExpiredSession(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theSessionIsRenewed(ScenarioState state) => state.advance();

Future<void> theResultShouldPreserveVisibleTasks(ScenarioState state) =>
    state.advance();

Future<void> theUserTapsSignIn(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldPreserveVisibleTasks(ScenarioState state) =>
    state.advance();

Future<void> aTaskThatCanBeSwipedForDeletion(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theTaskIsSwipedForDeletion(ScenarioState state) => state.advance();

Future<void> theResultShouldShowConfirmation(ScenarioState state) =>
    state.advance();

Future<void> aSwipedTaskWhoseDeletionCanBeCancelled(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theTaskIsSwipedAndDeletionIsHandled(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRetainTheTask(ScenarioState state) =>
    state.advance();

Future<void> aSwipedTaskWhoseDeletionWillSucceed(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> theResultShouldRemoveTheTask(ScenarioState state) =>
    state.advance();

Future<void> aCachedStartupSnapshotWithPendingNetworkRequests(
  ScenarioState state,
  bool empty,
) async {
  await state.prepare('4:$empty');
}

Future<void> theAppLoadsItsCachedTaskSnapshot(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldDisplayTheSelectedExampleSnapshot(
  ScenarioState state,
) => state.advance();

Future<void> metadataFailsAndFreshTaskResultsArrive(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldDisplayTheSelectedExampleSnapshot(
  ScenarioState state,
) => state.advance();

Future<void> thePendingRefreshCompletes(ScenarioState state) => state.advance();

Future<void> aTaskListLoadedWithTheSelectedScreenshotExample(
  ScenarioState state,
  String variant,
) async {
  await state.prepare('5:$variant');
}

Future<void> theTaskListLoads(ScenarioState state) => state.advance();

Future<void> theResultShouldMatchTheSelectedExampleScreenshot(
  ScenarioState state,
) => state.advance();

Future<void> editableWidgetAppearanceSettings(
  ScenarioState state,
  bool save,
) async {
  await state.prepare('6:$save');
}

Future<void> theWidgetAppearanceSettingsAreEdited(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldMatchTheSelectedOutcome(ScenarioState state) =>
    state.advance();

Future<void> completedTasksWhoseDeletionIsPending(ScenarioState state) async {
  await state.prepare('7');
}

Future<void> completedTaskDeletionStarts(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowProgressPopupOverListing(ScenarioState state) =>
    state.advance();

Future<void> theUserTapsOutsideTheDeletionProgressPopup(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldShowProgressPopupOverListing(
  ScenarioState state,
) => state.advance();

Future<void> repeatingTasksWithMetadata(ScenarioState state) async {
  await state.prepare('8');
}

Future<void> theTaskHomeScreenOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldHideMetadata(ScenarioState state) =>
    state.advance();

Future<void> theRepeatingTaskOpens(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldHideMetadata(ScenarioState state) =>
    state.advance();

Future<void> tasksInEveryDueDateCategory(ScenarioState state) async {
  await state.prepare('9');
}

Future<void> theResultShouldShow7Tasks2Overdue1NoDueDate2Today2Future(
  ScenarioState state,
) => state.advance();

Future<void> completedTasksWithSavedVisibilityDisabled(
  ScenarioState state,
) async {
  await state.prepare('10');
}

Future<void> theResultShouldShowCompletedTasks(ScenarioState state) =>
    state.advance();

Future<void> aSignedInTaskListWithASignOutAction(ScenarioState state) async {
  await state.prepare('11');
}

Future<void> theUserRequestsSignOut(ScenarioState state) => state.advance();

Future<void> multipleAvailableTaskLists(ScenarioState state) async {
  await state.prepare('12');
}

Future<void> theTaskListMenuOpens(ScenarioState state) => state.advance();

Future<void> theResultShouldShowAvailableLists(ScenarioState state) =>
    state.advance();

Future<void> theTasksListMenuOpens(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldShowAvailableLists(ScenarioState state) =>
    state.advance();

Future<void> aTaskListMenuWithAnotherList(ScenarioState state) async {
  await state.prepare('13');
}

Future<void> anotherTaskListIsSelected(ScenarioState state) => state.advance();

Future<void> theResultShouldSwitchTheSelectedList(ScenarioState state) =>
    state.advance();

Future<void> anOpenTaskListMenuAndAnOverflowAction(ScenarioState state) async {
  await state.prepare('14');
}

Future<void> theOverflowMenuIsRequested(ScenarioState state) => state.advance();

Future<void> theResultShouldNotOpen(ScenarioState state) => state.advance();

Future<void> theOverflowIconIsTappedBehindTheOpenListMenu(
  ScenarioState state,
) => state.advance();

Future<void> theFinalResultShouldNotOpen(ScenarioState state) =>
    state.advance();

Future<void> taskListAndOverflowMenus(ScenarioState state) async {
  await state.prepare('15');
}

Future<void> theResultShouldAlignWithTheTaskListMenu(ScenarioState state) =>
    state.advance();

Future<void> aTaskListWithAppearanceAndSignOutActions(
  ScenarioState state,
) async {
  await state.prepare('16');
}

Future<void> theResultShouldShowAppearanceAndSignOut(ScenarioState state) =>
    state.advance();

Future<void> tasksWithPastCurrentFutureAndMissingDates(
  ScenarioState state,
) async {
  await state.prepare('17');
}

Future<void> theResultShouldShowAllTasksAndAnIconAction(ScenarioState state) =>
    state.advance();

Future<void> theAddTaskActionIsTapped(ScenarioState state) => state.advance();

Future<void> theFinalResultShouldShowAllTasksAndAnIconAction(
  ScenarioState state,
) => state.advance();

Future<void> allTaskCategoriesWithCollapseControls(ScenarioState state) async {
  await state.prepare('18');
}

Future<void> theCategoryHeadingsAreUsed(ScenarioState state) => state.advance();

Future<void> theResultShouldLimitCollapseAndCounts(ScenarioState state) =>
    state.advance();

Future<void> theFutureCategoryHeadingIsTapped(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldLimitCollapseAndCounts(ScenarioState state) =>
    state.advance();

Future<void> oneCompletedTaskAndOneOpenTask(ScenarioState state) async {
  await state.prepare('19');
}

Future<void> completedTaskDeletionIsRequested(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldShowTheTaskCount(ScenarioState state) =>
    state.advance();

Future<void> completedTaskDeletionIsCancelled(ScenarioState state) =>
    state.advance();

Future<void> theFinalResultShouldShowTheTaskCount(ScenarioState state) =>
    state.advance();
