@testMethodName:unitScenario
@testerType:ScenarioState
Feature: flutter google account provider
  Background:
    Given scenario state is isolated

  Rule: Linking and forgetting Google accounts

    Scenario: link should authorize tasks when the user selects an account
      Given the user selects an account for link to authorize tasks
      When link is performed
      Then the result should authorize tasks

    Scenario: forget should retain Google permissions when the local connection is removed
      Given the local connection is removed for forget to retain Google permissions
      When forget is performed
      Then the result should retain Google permissions

  Rule: Authorizing the remembered Google account

    Scenario: authorize should restore the remembered identity when access is requested silently
      Given access is requested silently for authorize to restore the remembered identity
      When authorize is performed
      Then the result should restore the remembered identity

    Scenario: authorize should require explicit reconnection when restoration returns no account
      Given restoration returns no account for authorize to require explicit reconnection
      When authorize is performed
      Then the result should require explicit reconnection

    Scenario: authorize should reject a different identity when restoring the remembered account
      Given restoring the remembered account for authorize to reject a different identity
      When authorize is performed
      Then the result should reject a different identity

    Scenario: authorize should avoid consent UI when scopes need interactive approval
      Given scopes need interactive approval for authorize to avoid consent UI
      When authorize is performed
      Then the result should avoid consent UI

  Rule: Validating sign-in configuration

    Scenario: initialize should report configuration failure when the iOS client ID is missing
      Given the iOS client ID is missing for initialize to report configuration failure
      When initialize is performed
      Then the result should report configuration failure
