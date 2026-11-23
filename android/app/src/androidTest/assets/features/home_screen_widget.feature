@home_screen_widget @api31
Feature: Home screen widget

  Rule: Launcher pinning

    Scenario: pinWidget should display tasks when pinning is confirmed
      Given four dated fixture tasks are available for the launcher
      When widget pinning is confirmed and the widget is resized and refreshed
      Then the pinned widget shows all four dated tasks and is captured

  Rule: Refreshing an existing widget

    Scenario: refreshWidget should show empty state when no tasks remain
      Given a pinned widget contains four dated tasks
      When all tasks are removed from the pinned widget
      Then the launcher widget shows its empty state and is captured

    Scenario: saveAppearance should update the pinned widget when appearance settings change
      Given a pinned widget contains four dated tasks
      When the pinned widget colors and transparency are changed
      Then the updated launcher widget keeps its tasks and is captured

    Scenario: refreshWidget should show matching categories when tasks span dates
      Given a pinned widget contains four dated tasks
      When the pinned widget is refreshed with tasks spanning date categories
      Then the launcher widget shows all five date categories and is captured
