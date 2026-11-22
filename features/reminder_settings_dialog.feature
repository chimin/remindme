@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: reminder settings dialog
  Background:
    Given scenario state is isolated

  Rule: Saving and cancelling reminder changes

    Scenario: cancel should discard changes when the switch was changed
      Given default reminders that can be cancelled
      When the reminder switch changes and the dialog is cancelled
      Then the result should discard changes

    Scenario: save should return edited settings when the switch was changed
      Given default reminders that can be saved
      When the reminder switch changes and the dialog is saved
      Then the result should return edited settings

  Rule: Displaying reminder controls

    Scenario: display should show the reminder controls when settings open
      Given default reminder controls
      When the reminder settings open
      Then the result should show the reminder controls

      When the reminder switch is toggled off and on
      Then the final result should show the reminder controls

  Rule: Selecting and cancelling reminder times

    Scenario: select time should return the new time when saved
      Given a reminder time that can be edited
      When the reminder time picker opens
      Then the result should return the new time

      When the user selects 21 15 in keyboard mode
      Then the final result should return the new time

      When the reminder time picker reopens
      Then the final result should return the new time

      When the time picker closes and the reminder settings are saved
      Then the final result should return the new time

    Scenario: cancel picker should keep the time when selection is cancelled
      Given a reminder time selection that can be cancelled
      When the time picker opens for cancellation
      Then the result should keep the time

      When the user opens and cancels the time picker
      Then the final result should keep the time

      When the reminder settings are saved
      Then the final result should keep the time
