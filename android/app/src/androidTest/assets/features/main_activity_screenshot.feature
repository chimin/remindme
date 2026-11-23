@main_activity_screenshot
Feature: Main activity screenshots

  Rule: Fixture screen captures

    Scenario: capture should show task listing when four dated tasks exist
      Given the screenshot fixture is installed
      When the four dated task fixture is launched
      Then the task listing screenshot is saved

    Scenario: capture should show add task when add button is tapped
      Given the dated task listing is open
      When the add task button is tapped and the keyboard is dismissed
      Then the add task screenshot is saved

  Rule: Cold and warm widget navigation

    @api31
    Scenario: widgetTap should open the selected task when the app is cold or already running
      Given the current widget navigation fixture is selected
      When the first widget task is tapped after closing the activity
      Then the first task editor opens with a save action and is captured

      When the second widget task is tapped with the app running
      Then the second task opens in the task editor

      When back is pressed from the widget task editor
      Then the task home opens without an older editor

    @api31 @legacy_widget
    Scenario: widgetTap should open the selected task when using the legacy service
      Given the legacy widget navigation fixture is selected
      When the first widget task is tapped after closing the activity
      Then the first task editor opens with a save action and is captured

      When the second widget task is tapped with the app running
      Then the second task opens in the task editor

      When back is pressed from the widget task editor
      Then the task home opens without an older editor
