Feature: First launch
  Scenario: opening the app should show the login button when newly installed
    Given the app is newly installed
    When the user opens the app
    Then the app should show the {'Continue with Google'} login button
    And the test should capture a screenshot as {'features/screenshots/login_screen/login_screen_when_newly_installed.png'}
