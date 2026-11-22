@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: task home screen
  Background:
    Given scenario state is isolated

  Rule: Renewing sign in

    Scenario: sign in should preserve visible tasks when the session needs renewal
      Given visible tasks with an expired session
      When the session is renewed
      Then the result should preserve visible tasks

      When the user taps Sign in
      Then the final result should preserve visible tasks

  Rule: Loading cached tasks at startup

    Scenario Outline: startup should display the <snapshot> snapshot when network requests are pending
      Given a cached startup snapshot with pending network requests {<empty>}
      When the app loads its cached task snapshot
      Then the result should display the selected example snapshot

      When metadata fails and fresh task results arrive
      Then the final result should display the selected example snapshot

      When the pending refresh completes
      Then the final result should display the selected example snapshot

      Examples:
        | empty | snapshot |
        | false | saved |
        | true | empty |

  Rule: Signing out

    Scenario: sign out should show confirmation when the sign out action is tapped
      Given a signed in task list with a sign out action
      When the user requests sign out
      Then the result should show confirmation

  Rule: Displaying task lists

    Scenario Outline: listing should match the <variant> screenshot when its tasks are loaded
      Given a task list loaded with the selected screenshot example {<variant>}
      When the task list loads
      Then the result should match the selected example screenshot

      Examples:
        | variant |
        | 'empty' |
        | 'single_task_per_category' |
        | 'multiple_tasks_per_category' |
        | 'mixed_overdue_dates' |
        | 'today_and_tomorrow' |
        | 'future_dates' |
        | 'repeating_tasks_with_notes' |
        | 'long_titles_and_notes' |

    Scenario: home screen should hide metadata when repeating tasks are listed
      Given repeating tasks with metadata
      When the task home screen opens
      Then the result should hide metadata

      When the repeating task opens
      Then the final result should hide metadata

    Scenario: home screen should show 7 tasks 2 overdue 1 no due date 2 today 2 future when signed in
      Given tasks in every due date category
      When the task home screen opens
      Then the result should show 7 tasks 2 overdue 1 no due date 2 today 2 future

    Scenario: listing should show completed tasks when the saved visibility setting is false
      Given completed tasks with saved visibility disabled
      When the task list loads
      Then the result should show completed tasks

    Scenario: listing should show all tasks and an icon action when the home screen opens
      Given tasks with past current future and missing dates
      When the task list loads
      Then the result should show all tasks and an icon action

      When the Add task action is tapped
      Then the final result should show all tasks and an icon action

  Rule: Interacting with category headings

    Scenario: category bars should limit collapse and counts when all categories are present
      Given all task categories with collapse controls
      When the category headings are used
      Then the result should limit collapse and counts

      When the future category heading is tapped
      Then the final result should limit collapse and counts

  Rule: Swiping tasks for deletion

    Scenario: swipe delete should show confirmation when a task is swiped
      Given a task that can be swiped for deletion
      When the task is swiped for deletion
      Then the result should show confirmation

    Scenario: swipe delete should retain the task when confirmation is cancelled
      Given a swiped task whose deletion can be cancelled
      When the task is swiped and deletion is handled
      Then the result should retain the task

    Scenario: swipe delete should remove the task when deletion is confirmed
      Given a swiped task whose deletion will succeed
      When the task is swiped and deletion is handled
      Then the result should remove the task

  Rule: Deleting completed tasks

    Scenario: delete completed tasks should show progress popup over listing when deletion is in progress
      Given completed tasks whose deletion is pending
      When completed task deletion starts
      Then the result should show progress popup over listing

      When the user taps outside the deletion progress popup
      Then the final result should show progress popup over listing

    Scenario: delete confirmation should show the task count when completed tasks exist
      Given one completed task and one open task
      When completed task deletion is requested
      Then the result should show the task count

      When completed task deletion is cancelled
      Then the final result should show the task count

  Rule: Editing widget appearance

    Scenario Outline: widget appearance should <result> when edits are <outcome>
      Given editable widget appearance settings {<save>}
      When the widget appearance settings are edited
      Then the result should match the selected outcome

      Examples:
        | save | result | outcome |
        | true | save settings before refreshing | saved |
        | false | keep settings unchanged | cancelled |

  Rule: Opening and switching task lists

    Scenario: task list menu should show available lists when app title is tapped
      Given multiple available task lists
      When the task list menu opens
      Then the result should show available lists

      When the Tasks list menu opens
      Then the final result should show available lists

    Scenario: selecting a task list should switch the selected list when menu item is tapped
      Given a task list menu with another list
      When another task list is selected
      Then the result should switch the selected list

  Rule: Opening overflow menus

    Scenario: overflow menu should not open when the task list menu is open
      Given an open task list menu and an overflow action
      When the overflow menu is requested
      Then the result should not open

      When the overflow icon is tapped behind the open list menu
      Then the final result should not open

    Scenario: overflow menu should align with the task list menu when opened
      Given task list and overflow menus
      When the overflow menu is requested
      Then the result should align with the task list menu

    Scenario: overflow menu should show appearance and sign out when opened
      Given a task list with appearance and sign out actions
      When the overflow menu is requested
      Then the result should show appearance and sign out
