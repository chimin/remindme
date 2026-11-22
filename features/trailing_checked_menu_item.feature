@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: trailing checked menu item
  Background:
    Given scenario state is isolated

  Scenario: menu item should show the checkmark on the right when the item is checked
    Given a checked task list menu item
    When the configured task list menu opens
    Then the result should show the checkmark on the right

  Scenario: menu item should hide the checkmark when the item is not checked
    Given an unchecked task list menu item
    When the configured task list menu opens
    Then the result should hide the checkmark

  Scenario: menu item should report the checked state to accessibility tools when the item is checked
    Given a checked task list menu item with semantics
    When the configured task list menu opens
    Then the result should report the checked state to accessibility tools

  Scenario: menu item should fit the menu width when the label is long
    Given a checked task list menu item with a long label
    When the configured task list menu opens
    Then the result should fit the menu width

