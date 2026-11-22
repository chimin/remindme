@testMethodName:unitScenario
@testerType:ScenarioState
Feature: android google account provider
  Background:
    Given scenario state is isolated

  Rule: Linking and reconnecting Google accounts

    Scenario: link should pin authorization to the selected account when linking starts
      Given linking starts for link to pin authorization to the selected account
      When link is performed
      Then the result should pin authorization to the selected account

    Scenario: reconnect should bypass account selection when an account is remembered
      Given an account is remembered for reconnect to bypass account selection
      When reconnect is performed
      Then the result should bypass account selection

  Rule: Authorizing the remembered Google account

    Scenario: authorize should prohibit native UI when restoring silently
      Given restoring silently for authorize to prohibit native UI
      When authorize is performed
      Then the result should prohibit native UI

    Scenario: authorize should normalize native resolution when interaction is required
      Given interaction is required for authorize to normalize native resolution
      When authorize is performed
      Then the result should normalize native resolution
