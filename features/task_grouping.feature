@testMethodName:unitScenario
@testerType:ScenarioState
Feature: task grouping
  Background:
    Given scenario state is isolated

  Rule: Building widget task groups and headers

    Scenario: buildWidgetDisplayItems should produce no display items when tasks are empty
      Given tasks are empty for buildWidgetDisplayItems to produce no display items
      When buildWidgetDisplayItems is performed
      Then the result should produce no display items

    Scenario: buildWidgetDisplayItems should use the No due date group when tasks have no due dates
      Given tasks have no due dates for buildWidgetDisplayItems to use the No due date group
      When buildWidgetDisplayItems is performed
      Then the result should use the No due date group

    Scenario: buildWidgetDisplayItems should use the No due date group when due dates are unparseable
      Given due dates are unparseable for buildWidgetDisplayItems to use the No due date group
      When buildWidgetDisplayItems is performed
      Then the result should use the No due date group

    Scenario: buildWidgetDisplayItems should order headers and tasks when due dates span categories
      Given due dates span categories for buildWidgetDisplayItems to order headers and tasks
      When buildWidgetDisplayItems is performed
      Then the result should order headers and tasks

    Scenario: buildWidgetDisplayItems should reserve the overdue category for overdue headers when tasks span past and current dates
      Given tasks span past and current dates for buildWidgetDisplayItems to reserve the overdue category for overdue headers
      When buildWidgetDisplayItems is performed
      Then the result should reserve the overdue category for overdue headers

    Scenario: buildWidgetDisplayItems should match home screen headers when tasks span categories
      Given tasks span categories for buildWidgetDisplayItems to match home screen headers
      When buildWidgetDisplayItems is performed
      Then the result should match home screen headers

      When buildWidgetDisplayItems continues
      Then the result should match home screen headers

    Scenario: buildWidgetDisplayItems should show Tomorrow when dates cross a month boundary
      Given dates cross a month boundary for buildWidgetDisplayItems to show Tomorrow
      When buildWidgetDisplayItems is performed
      Then the result should show Tomorrow

  Rule: Adding task list identity to widget items

    Scenario: buildWidgetDisplayItems should add task list name first when task list name is given
      Given task list name is given for buildWidgetDisplayItems to add task list name first
      When buildWidgetDisplayItems is performed
      Then the result should add task list name first

    Scenario: buildWidgetDisplayItems should add task list name when there are no tasks
      Given there are no tasks for buildWidgetDisplayItems to add task list name
      When buildWidgetDisplayItems is performed
      Then the result should add task list name

    Scenario: buildWidgetDisplayItems should skip task list name when task list name is blank
      Given task list name is blank for buildWidgetDisplayItems to skip task list name
      When buildWidgetDisplayItems is performed
      Then the result should skip task list name

    Scenario: buildWidgetDisplayItems should skip task list name when task list name is not given
      Given task list name is not given for buildWidgetDisplayItems to skip task list name
      When buildWidgetDisplayItems is performed
      Then the result should skip task list name

    Scenario: buildWidgetDisplayItems should identify the owning list when navigation is enabled
      Given navigation is enabled for buildWidgetDisplayItems to identify the owning list
      When buildWidgetDisplayItems is performed
      Then the result should identify the owning list

      When buildWidgetDisplayItems continues
      Then the result should identify the owning list

  Rule: Filtering completed tasks

    Scenario: buildWidgetDisplayItems should exclude completed tasks when open and completed tasks are mixed
      Given open and completed tasks are mixed for buildWidgetDisplayItems to exclude completed tasks
      When buildWidgetDisplayItems is performed
      Then the result should exclude completed tasks

    Scenario: buildWidgetDisplayItems should drop groups with only completed tasks when completion empties a group
      Given completion empties a group for buildWidgetDisplayItems to drop groups with only completed tasks
      When buildWidgetDisplayItems is performed
      Then the result should drop groups with only completed tasks

    Scenario: groupTasksByDueDate should include completed tasks when no completion filter is supplied
      Given no completion filter is supplied for groupTasksByDueDate to include completed tasks
      When groupTasksByDueDate is performed
      Then the result should include completed tasks

    Scenario: groupTasksByDueDate should exclude completed tasks when showCompleted is false
      Given showCompleted is false for groupTasksByDueDate to exclude completed tasks
      When groupTasksByDueDate is performed
      Then the result should exclude completed tasks

    Scenario: groupTasksByDueDate should drop groups with only completed tasks when showCompleted is false
      Given showCompleted is false for groupTasksByDueDate to drop groups with only completed tasks
      When groupTasksByDueDate is performed
      Then the result should drop groups with only completed tasks

  Rule: Formatting task dates and group titles

    Scenario: formatTaskDate should use relative labels when dates cross a year boundary
      Given dates cross a year boundary for formatTaskDate to use relative labels
      When formatTaskDate is performed
      Then the result should use relative labels

    Scenario: formatTaskDate should preserve calendar days when a due date uses UTC
      Given a due date uses UTC for formatTaskDate to preserve calendar days
      When formatTaskDate is performed
      Then the result should preserve calendar days

    Scenario: formatTaskGroupTitle should preserve named headers when title is not a date
      Given title is not a date for formatTaskGroupTitle to preserve named headers
      When formatTaskGroupTitle is performed
      Then the result should preserve named headers
