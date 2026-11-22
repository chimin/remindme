@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: task edit screen
  Background:
    Given scenario state is isolated

  Rule: Opening task editors

    Scenario: add task page should show empty form when task list selected
      Given a selected task list without an existing task
      When the new task editor opens
      Then the result should show empty form

    Scenario: editor should place Save after Delete when an incomplete task opens
      Given an incomplete task with editor actions
      When the task editor opens
      Then the result should place Save after Delete

    Scenario: delete should remain available when a completed task is viewed
      Given a completed task available for deletion
      When the completed task editor opens
      Then the result should remain available

    Scenario: editor should prevent field changes when a completed task opens
      Given a completed task with read only fields
      When the task editor opens
      Then the result should prevent field changes

      When the completed task due date field is tapped
      Then the final result should prevent field changes

  Rule: Deleting tasks

    Scenario: delete task should show confirmation when the delete button is tapped
      Given a task available for deletion
      When the editor opens and task deletion is requested
      Then the result should show confirmation

    Scenario: delete task should retain the editor when confirmation is cancelled
      Given a task whose deletion can be cancelled
      When the user requests or confirms task deletion
      Then the result should retain the editor

    Scenario: delete task should return to the previous screen when deletion is confirmed
      Given a task whose deletion will succeed
      When the user requests or confirms task deletion
      Then the result should return to the previous screen

    Scenario: delete task should disable save and delete actions when deletion is pending
      Given a task whose deletion is pending
      When the user requests or confirms task deletion
      Then the result should disable save and delete actions

    Scenario: delete task should show an error and retain the editor when deletion fails
      Given a task whose deletion will fail
      When the user requests or confirms task deletion
      Then the result should show an error and retain the editor

  Rule: Saving tasks

    Scenario: save should remain reachable when the keyboard reduces available height
      Given an editor with reduced keyboard space
      When the user edits and saves the task
      Then the result should remain reachable

    Scenario: save should preserve extensible metadata when a repeating task is edited
      Given a repeating task with extensible metadata
      When the user edits and saves the task
      Then the result should preserve extensible metadata

      When the repeating task is saved
      Then the final result should preserve extensible metadata

    Scenario: save should require a due date when repeat is selected
      Given a repeat selection without a due date
      When the user edits and saves the task
      Then the result should require a due date

    Scenario: save should remove only recurrence when repeat is disabled
      Given a task with recurrence that can be disabled
      When the user edits and saves the task
      Then the result should remove only recurrence

    Scenario: save should preserve an unknown rule when repeat is unchanged
      Given a task with an unknown recurrence rule
      When the user edits and saves the task
      Then the result should preserve an unknown rule

  Rule: Selecting due dates

    Scenario: due date should open the picker from the field surface when tapped
      Given an editable due date field
      When the due date field is tapped
      Then the result should open the picker from the field surface

      When the user taps No due date
      Then the final result should open the picker from the field surface

      When the selected due date is accepted
      Then the final result should open the picker from the field surface

      When the due date is cleared
      Then the final result should open the picker from the field surface

      When the task without a due date is saved
      Then the final result should open the picker from the field surface

  Rule: Marking tasks completed

    Scenario: mark completed should save edited fields and return home when an incomplete task is submitted
      Given an incomplete task with edited fields
      When the task is marked completed
      Then the result should save edited fields and return home

    Scenario: mark completed should retain the editor when validation fails
      Given an incomplete task with invalid fields
      When the task is marked completed
      Then the result should retain the editor

    Scenario: mark completed should disable other actions when the update is pending
      Given an incomplete task whose update is pending
      When the completion callback is invoked twice while saving is pending
      Then the result should disable other actions

      When the pending task save completes
      Then the final result should disable other actions

    Scenario: mark completed should retain edited fields when saving fails
      Given edited task fields whose save will fail
      When the task is marked completed
      Then the result should retain edited fields

  Rule: Marking tasks incomplete

    Scenario: mark incomplete should retain fields and enable editing when completion is reversed
      Given a completed task that can become incomplete
      When the completed task editor opens
      Then the result should retain fields and enable editing

      When the task is marked incomplete
      Then the final result should retain fields and enable editing

      When the unlocked title is edited and saved
      Then the final result should retain fields and enable editing

    Scenario: mark incomplete should skip validation when a completed task has an empty title
      Given a completed task with an empty title
      When the task is marked incomplete
      Then the result should skip validation

    Scenario: mark incomplete should remain read only when the update fails
      Given a completed task whose update will fail
      When the task is marked incomplete
      Then the result should remain read only
