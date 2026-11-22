@testMethodName:unitScenario
@testerType:ScenarioState
Feature: task metadata
  Background:
    Given scenario state is isolated

  Rule: Encoding and parsing metadata

    Scenario: encode should preserve unknown fields when notes are edited
      Given notes are edited for encode to preserve unknown fields
      When encode is performed
      Then the result should preserve unknown fields

    Scenario: parse should preserve notes when metadata is malformed
      Given metadata is malformed for parse to preserve notes
      When parse is performed
      Then the result should preserve notes

    Scenario: parse should preserve notes when metadata version is unsupported
      Given metadata version is unsupported for parse to preserve notes
      When parse is performed
      Then the result should preserve notes

  Rule: Calculating the next due date

    Scenario: next due should restore anchor day when February has fewer days
      Given February has fewer days for next due to restore anchor day
      When next due is performed
      Then the result should restore anchor day

    Scenario: next due should skip missed dates when a task is overdue
      Given a task is overdue for next due to skip missed dates
      When next due is performed
      Then the result should skip missed dates

    Scenario: next due should restore leap day when the next leap year arrives
      Given the next leap year arrives for next due to restore leap day
      When next due is performed
      Then the result should restore leap day

    Scenario: next due should ignore recurrence when interval is invalid
      Given interval is invalid for next due to ignore recurrence
      When next due is performed
      Then the result should ignore recurrence
