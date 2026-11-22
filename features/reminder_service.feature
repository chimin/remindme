@testMethodName:unitScenario
@testerType:ScenarioState
Feature: reminder service
  Background:
    Given scenario state is isolated

  Rule: Loading and saving reminder settings

    Scenario: load should enable reminders at eight when settings are absent
      Given settings are absent for load to enable reminders at eight
      When load is performed
      Then the result should enable reminders at eight

    Scenario: save should restore enabled state and time when settings reload
      Given settings reload for save to restore enabled state and time
      When save is performed
      Then the result should restore enabled state and time

  Rule: Refreshing scheduled reminders

    Scenario: refresh should leave cancellation last when previous work is delayed
      Given previous work is delayed for refresh to leave cancellation last
      When refresh is performed
      Then the result should leave cancellation last

    Scenario: refresh should replace with disabled settings when reminders are disabled
      Given reminders are disabled for refresh to replace with disabled settings
      When refresh is performed
      Then the result should replace with disabled settings

    Scenario: refresh should continue processing when the platform denies a request
      Given the platform denies a request for refresh to continue processing
      When refresh is performed
      Then the result should continue processing

    Scenario: refresh should request immediate delivery when the app opens
      Given the app opens for refresh to request immediate delivery
      When refresh is performed
      Then the result should request immediate delivery
