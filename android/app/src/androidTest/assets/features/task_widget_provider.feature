@task_widget_provider @api31
Feature: Task widget provider

  Rule: Widget appearance

    Scenario: saveAppearance should update all colors when existing views are reapplied
      Given two widget views use the original appearance
      When the first updated appearance is reapplied to both widgets
      Then both widget views use all the updated colors

      When the second updated appearance is reapplied to both widgets
      Then both widget views use all the updated colors

    Scenario: saveAppearance should update empty state when no tasks remain
      Given the widget has no tasks and a transparent background
      When the empty widget views are built
      Then the empty state uses the saved appearance

  Rule: Widget categories

    Scenario: buildViews should show matching category labels when tasks span dates
      Given widget tasks span all five date categories
      When the categorized widget views are built
      Then the widget shows all matching category labels

  Rule: Task navigation identity

    Scenario: taskFillInIntent should preserve identity when IDs contain reserved characters
      Given task identities contain reserved characters
      When a widget intent is built with reserved characters
      Then the widget intent preserves both encoded identities

    Scenario: taskFillInIntent should open home when legacy payload lacks identity
      Given legacy task identities may be absent
      When widget intents are built with incomplete identities
      Then each incomplete identity opens home
