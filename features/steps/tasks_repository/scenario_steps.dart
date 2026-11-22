import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> offlineForRefreshRemindersToMirrorSelectedCachedTasks(
  ScenarioState state,
) async {
  await state.prepare('0');
}

Future<void> refreshRemindersIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldMirrorSelectedCachedTasks(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> refreshRemindersContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> theUserIsSignedOutForInitializeToLeaveTheTaskBoxClosed(
  ScenarioState state,
) async {
  await state.prepare('1');
}

Future<void> initializeIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldLeaveTheTaskBoxClosed(ScenarioState state) async {
  await state.advance();
}

Future<void>
anEmptyListWasCachedForReadTasksToReturnAnEmptySnapshotWithoutNetwork(
  ScenarioState state,
) async {
  await state.prepare('2');
}

Future<void> readTasksIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldReturnAnEmptySnapshotWithoutNetwork(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> theServerIsOfflineForReadCachedTasksToReturnSavedTasks(
  ScenarioState state,
) async {
  await state.prepare('3');
}

Future<void> readCachedTasksIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldReturnSavedTasks(ScenarioState state) async {
  await state.advance();
}

Future<void> taskRepeatsForCompleteTaskToRetainHistoryAndCloneMetadata(
  ScenarioState state,
) async {
  await state.prepare('4');
}

Future<void> completeTaskIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRetainHistoryAndCloneMetadata(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> completeTaskContinues(ScenarioState state) async {
  await state.advance();
}

Future<void>
aRecurringTaskIsReopenedForUpdateTaskToCompleteEditedFieldsAndPreserveSuccessors(
  ScenarioState state,
) async {
  await state.prepare('5');
}

Future<void> updateTaskIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldCompleteEditedFieldsAndPreserveSuccessors(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> updateTaskContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> completionRequestsOverlapForCompleteTaskToCreateOneSuccessor(
  ScenarioState state,
) async {
  await state.prepare('6');
}

Future<void> theResultShouldCreateOneSuccessor(ScenarioState state) async {
  await state.advance();
}

Future<void> completionWasSavedOfflineBeforeRestartForSyncToRecoverBothWrites(
  ScenarioState state,
) async {
  await state.prepare('7');
}

Future<void> syncIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRecoverBothWrites(ScenarioState state) async {
  await state.advance();
}

Future<void> syncContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> createResponseIsLostForSyncToReconcileTheExistingClone(
  ScenarioState state,
) async {
  await state.prepare('8');
}

Future<void> theResultShouldReconcileTheExistingClone(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> completionHappenedInGoogleTasksForPullToCloneATask(
  ScenarioState state,
) async {
  await state.prepare('9');
}

Future<void> pullIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldCloneATask(ScenarioState state) async {
  await state.advance();
}

Future<void> cacheIsRebuiltForPullToRespectADeletedSuccessor(
  ScenarioState state,
) async {
  await state.prepare('10');
}

Future<void> theResultShouldRespectADeletedSuccessor(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> aSuccessorIsCompletedForCompleteTaskToRetainTheSeries(
  ScenarioState state,
) async {
  await state.prepare('11');
}

Future<void> theResultShouldRetainTheSeries(ScenarioState state) async {
  await state.advance();
}

Future<void> recurrenceIsAbsentForCompleteTaskToKeepASingleTask(
  ScenarioState state,
) async {
  await state.prepare('12');
}

Future<void> theResultShouldKeepASingleTask(ScenarioState state) async {
  await state.advance();
}

Future<void> refreshedCredentialsAreRejectedForApiRequestToPreserveCachedAccess(
  ScenarioState state,
) async {
  await state.prepare('13');
}

Future<void> apiRequestIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldPreserveCachedAccess(ScenarioState state) async {
  await state.advance();
}

Future<void> theUserDisconnectsForSignOutToClearPendingTasks(
  ScenarioState state,
) async {
  await state.prepare('14');
}

Future<void> signOutIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldClearPendingTasks(ScenarioState state) async {
  await state.advance();
}

Future<void> googleIsOfflineForCreateTaskToRemainEditableAndDeletable(
  ScenarioState state,
) async {
  await state.prepare('15');
}

Future<void> createTaskIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRemainEditableAndDeletable(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
anOfflineEditorRemainsOpenDuringSyncForEditTaskToResolveItsServerIdentity(
  ScenarioState state,
) async {
  await state.prepare('16');
}

Future<void> editTaskIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldResolveItsServerIdentity(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
theSelectedAccountDoesNotOwnTheirListForLinkToRetainLegacyPendingTasks(
  ScenarioState state,
) async {
  await state.prepare('17');
}

Future<void> linkIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldRetainLegacyPendingTasks(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> theSelectedAccountOwnsItsLegacyListForLinkToAdoptTheCache(
  ScenarioState state,
) async {
  await state.prepare('18');
}

Future<void> theResultShouldAdoptTheCache(ScenarioState state) async {
  await state.advance();
}

Future<void>
repositoriesAreComposedForAuthenticationToForwardStateAndPreserveInjectedOwnership(
  ScenarioState state,
) async {
  await state.prepare('19');
}

Future<void> authenticationIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldForwardStateAndPreserveInjectedOwnership(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> authenticationContinues(ScenarioState state) async {
  await state.advance();
}

Future<void> itIsNewerThanTheRemoteEntryForMergetasksToKeepTheLocalEntry(
  ScenarioState state,
) async {
  await state.prepare('20');
}

Future<void> mergetasksIsPerformed(ScenarioState state) async {
  await state.advance();
}

Future<void> theResultShouldKeepTheLocalEntry(ScenarioState state) async {
  await state.advance();
}

Future<void> itIsNewerThanTheLocalEntryForMergetasksToPreferTheRemoteEntry(
  ScenarioState state,
) async {
  await state.prepare('21');
}

Future<void> theResultShouldPreferTheRemoteEntry(ScenarioState state) async {
  await state.advance();
}

Future<void>
newerThanTheRemoteEntryForMergetasksToPreserveALocallyrequestedDeletion(
  ScenarioState state,
) async {
  await state.prepare('22');
}

Future<void> theResultShouldPreserveALocallyrequestedDeletion(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void>
tasksAreAbsentLocallyForMergetasksToAddRemoteonlyTasksAndClearTheDirtyFlag(
  ScenarioState state,
) async {
  await state.prepare('23');
}

Future<void> theResultShouldAddRemoteonlyTasksAndClearTheDirtyFlag(
  ScenarioState state,
) async {
  await state.advance();
}

Future<void> tasksAreAbsentRemotelyForMergetasksToKeepLocalonlyEntries(
  ScenarioState state,
) async {
  await state.prepare('24');
}

Future<void> theResultShouldKeepLocalonlyEntries(ScenarioState state) async {
  await state.advance();
}
