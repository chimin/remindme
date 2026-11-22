import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> tasksAreEmptyForBuildwidgetdisplayitemsToProduceNoDisplayItems(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> buildwidgetdisplayitemsIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldProduceNoDisplayItems(ScenarioState state) async {
  await state.advance();
}

Future<void>
tasksHaveNoDueDatesForBuildwidgetdisplayitemsToUseTheNoDueDateGroup(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> theResultShouldUseTheNoDueDateGroup(ScenarioState state) async {
  await state.advance();
}

Future<void>
dueDatesAreUnparseableForBuildwidgetdisplayitemsToUseTheNoDueDateGroup(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void>
dueDatesSpanCategoriesForBuildwidgetdisplayitemsToOrderHeadersAndTasks(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> theResultShouldOrderHeadersAndTasks(ScenarioState state) async {
  await state.advance();
}

Future<void>
tasksSpanPastAndCurrentDatesForBuildwidgetdisplayitemsToReserveTheOverdueCategoryForOverdueHeaders(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> theResultShouldReserveTheOverdueCategoryForOverdueHeaders(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
taskListNameIsGivenForBuildwidgetdisplayitemsToAddTaskListNameFirst(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> theResultShouldAddTaskListNameFirst(ScenarioState state) async {
  await state.advance();
}

Future<void> thereAreNoTasksForBuildwidgetdisplayitemsToAddTaskListName(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> theResultShouldAddTaskListName(ScenarioState state) async {
  await state.advance();
}

Future<void> taskListNameIsBlankForBuildwidgetdisplayitemsToSkipTaskListName(
  ScenarioState state,
) async {
  await state.prepare('7');
}

Future<void> theResultShouldSkipTaskListName(ScenarioState state) async {
  await state.advance();
}

Future<void> taskListNameIsNotGivenForBuildwidgetdisplayitemsToSkipTaskListName(
  ScenarioState state,
) async {
  await state.prepare('8');
}

Future<void>
openAndCompletedTasksAreMixedForBuildwidgetdisplayitemsToExcludeCompletedTasks(
  ScenarioState state,
) async {
  await state.prepare('9');
}

Future<void> theResultShouldExcludeCompletedTasks(ScenarioState state) async {
  await state.advance();
}

Future<void>
completionEmptiesAGroupForBuildwidgetdisplayitemsToDropGroupsWithOnlyCompletedTasks(
  ScenarioState state,
) async {
  await state.prepare('10');
}

Future<void> theResultShouldDropGroupsWithOnlyCompletedTasks(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
noCompletionFilterIsSuppliedForGrouptasksbyduedateToIncludeCompletedTasks(
  ScenarioState state,
) async {
  await state.prepare('11');
}

Future<void> grouptasksbyduedateIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldIncludeCompletedTasks(ScenarioState state) async {
  await state.advance();
}

Future<void> showcompletedIsFalseForGrouptasksbyduedateToExcludeCompletedTasks(
  ScenarioState state,
) async {
  await state.prepare('12');
}

Future<void>
showcompletedIsFalseForGrouptasksbyduedateToDropGroupsWithOnlyCompletedTasks(
  ScenarioState state,
) async {
  await state.prepare('13');
}

Future<void> datesCrossAYearBoundaryForFormattaskdateToUseRelativeLabels(
  ScenarioState state,
) async {
  await state.prepare('14');
}

Future<void> formattaskdateIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldUseRelativeLabels(ScenarioState state) async {
  await state.advance();
}

Future<void> aDueDateUsesUtcForFormattaskdateToPreserveCalendarDays(
  ScenarioState state,
) async {
  await state.prepare('15');
}

Future<void> theResultShouldPreserveCalendarDays(ScenarioState state) async {
  await state.advance();
}

Future<void>
tasksSpanCategoriesForBuildwidgetdisplayitemsToMatchHomeScreenHeaders(
  ScenarioState state,
) async {
  await state.prepare('16');
}

Future<void> theResultShouldMatchHomeScreenHeaders(ScenarioState state) async {
  await state.advance();
}

Future<void> buildwidgetdisplayitemsContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> datesCrossAMonthBoundaryForBuildwidgetdisplayitemsToShowTomorrow(
  ScenarioState state,
) async {
  await state.prepare('17');
}

Future<void> theResultShouldShowTomorrow(ScenarioState state) async {
  await state.advance();
}

Future<void> titleIsNotADateForFormattaskgrouptitleToPreserveNamedHeaders(
  ScenarioState state,
) async {
  await state.prepare('18');
}

Future<void> formattaskgrouptitleIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldPreserveNamedHeaders(ScenarioState state) async {
  await state.advance();
}

Future<void>
navigationIsEnabledForBuildwidgetdisplayitemsToIdentifyTheOwningList(
  ScenarioState state,
) async {
  await state.prepare('19');
}

Future<void> theResultShouldIdentifyTheOwningList(ScenarioState state) async {
  await state.advance();
}
