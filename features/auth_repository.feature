@testMethodName:unitScenario
@testerType:ScenarioState
Feature: auth repository
  Background:
    Given scenario state is isolated

  Rule: Initializing the account connection

    Scenario: initialize should leave linking to the foreground when no account was saved
      Given no account was saved for initialize to leave linking to the foreground
      When initialize is performed
      Then the result should leave linking to the foreground

    Scenario: initialize should preserve cached account access when the device is offline
      Given the device is offline for initialize to preserve cached account access
      When initialize is performed
      Then the result should preserve cached account access

  Rule: Linking a Google account

    Scenario: link should remember the account when authorization succeeds
      Given authorization succeeds for link to remember the account
      When link is performed
      Then the result should remember the account

    Scenario: link should allow retry when account selection is canceled
      Given account selection is canceled for link to allow retry
      When link is performed
      Then the result should allow retry

      When link continues
      Then the result should allow retry

    Scenario: link should share the active attempt when requests overlap
      Given requests overlap for link to share the active attempt
      When link is performed
      Then the result should share the active attempt

    Scenario: link should preserve the cache owner when a different account is returned
      Given a different account is returned for link to preserve the cache owner
      When link is performed
      Then the result should preserve the cache owner

    Scenario: link should preserve unowned data when migration verification fails
      Given migration verification fails for link to preserve unowned data
      When link is performed
      Then the result should preserve unowned data

    Scenario: link should ignore late authorization when the user disconnects
      Given the user disconnects for link to ignore late authorization
      When link is performed
      Then the result should ignore late authorization

    Scenario: link should retain authorization when post-link sync fails
      Given post-link sync fails for link to retain authorization
      When link is performed
      Then the result should retain authorization

  Rule: Requesting tokens and reconnecting

    Scenario: token request should share silent authorization when requests overlap
      Given requests overlap for token request to share silent authorization
      When token request is performed
      Then the result should share silent authorization

      When token request continues
      Then the result should share silent authorization

    Scenario: token request should preserve the linked account when consent is required
      Given consent is required for token request to preserve the linked account
      When token request is performed
      Then the result should preserve the linked account

    Scenario: reconnect should clear the warning when authorization succeeds
      Given authorization succeeds for reconnect to clear the warning
      When reconnect is performed
      Then the result should clear the warning

  Rule: Signing out

    Scenario: sign out should forget only the app connection when cleanup fails
      Given cleanup fails for sign out to forget only the app connection
      When sign out is performed
      Then the result should forget only the app connection
