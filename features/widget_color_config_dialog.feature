@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: widget color config dialog
  Background:
    Given scenario state is isolated

  Rule: Opening appearance controls

    Scenario: opening should show color and opacity controls when the dialog opens
      Given default widget appearance controls
      When the widget appearance dialog opens
      Then the result should show color and opacity controls

  Rule: Opening the color picker

    Scenario: tapping a color box should open the color picker when a color is edited
      Given a widget text color that can be edited
      When the text color box is tapped
      Then the result should open the color picker

    Scenario: color picker dialog should match the golden screenshot when opened
      Given a widget color picker screenshot fixture
      When the color picker dialog opens
      Then the result should match the golden screenshot

  Rule: Saving widget appearance

    Scenario: saving should close the dialog when appearance is saved
      Given a widget appearance screenshot fixture
      When the appearance dialog is saved
      Then the result should close the dialog

      When the user saves widget appearance
      Then the final result should close the dialog

  Rule: Resetting and cancelling appearance changes

    Scenario: reset should restore defaults when confirmation is accepted
      Given custom widget colors that can be reset
      When the widget appearance reset is requested
      Then the result should restore defaults

      When the user confirms the appearance reset
      Then the final result should restore defaults

      When the reset appearance is saved
      Then the final result should restore defaults

    Scenario: appearance should retain saved colors when edits are cancelled
      Given custom widget colors whose edits can be cancelled
      When the appearance edits are cancelled
      Then the result should retain saved colors

      When the appearance reset confirmation is cancelled
      Then the final result should retain saved colors

      When the appearance dialog is cancelled
      Then the final result should retain saved colors
