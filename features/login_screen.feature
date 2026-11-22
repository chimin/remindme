@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: login screen
  Background:
    Given scenario state is isolated

  Rule: Opening the app

    Scenario: startup should require sign in when no account is remembered
      Given no Google account is remembered
      When the app starts without a remembered account
      Then the result should require sign in

    Scenario: startup should show tasks when sign in succeeds
      Given Google sign in will succeed
      When the app starts with successful sign in
      Then the result should show tasks

    Scenario: opening the app should show the login button when newly installed
      Given the app is newly installed
      When the user opens the app
      Then the app should show the {'Continue with Google'} login button
      And the test should capture a screenshot as {'features/screenshots/login_screen/login_screen_when_newly_installed.png'}

  Rule: Retrying sign in

    Scenario: retry should start sign in again when the previous attempt was canceled
      Given the previous Google sign in attempt can be retried
      When the user retries Google sign in
      Then the result should start sign in again

  Rule: Rebuilding during sign in

    Scenario: rebuild should avoid duplicate prompts when sign in is pending
      Given Google sign in is waiting for a response
      When the repository rebuilds while sign in is pending
      Then the result should avoid duplicate prompts
