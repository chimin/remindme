@testMethodName:unitScenario
@testerType:ScenarioState
Feature: google authorized client
  Background:
    Given scenario state is isolated

  Rule: Retrying requests after token rejection

    Scenario: send should replay the body once when the server rejects an expired token
      Given the server rejects an expired token for send to replay the body once
      When send is performed
      Then the result should replay the body once

    Scenario: send should require reconnection when a fresh token is also rejected
      Given a fresh token is also rejected for send to require reconnection
      When send is performed
      Then the result should require reconnection

  Rule: Handling connection failures

    Scenario: send should avoid replaying a write when the connection drops
      Given the connection drops for send to avoid replaying a write
      When send is performed
      Then the result should avoid replaying a write

  Rule: Rejecting responses from replaced account sessions

    Scenario: send should reject stale responses when the account changes
      Given the account changes for send to reject stale responses
      When send is performed
      Then the result should reject stale responses

    Scenario: send should ignore rejected credentials when their account session was replaced
      Given their account session was replaced for send to ignore rejected credentials
      When send is performed
      Then the result should ignore rejected credentials
