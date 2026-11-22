@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: widget task navigator
  Background:
    Given scenario state is isolated

  Rule: Launching the app from a widget

    Scenario: widget launch should open its owning task when the app starts cold
      Given a cold widget launch for list B
      When the widget launches the app
      Then the result should open its owning task

    Scenario: widget launch should wait for authentication when startup is not ready
      Given a widget launch waiting for authentication
      When the widget launches the app
      Then the result should wait for authentication

      When Google authentication finishes
      Then the final result should wait for authentication

  Rule: Tapping widget task links

    Scenario: widget tap should discard unsaved edits when another task is tapped
      Given tasks in two lists with unsaved editor changes
      When the widget delivers a task link
      Then the result should discard unsaved edits

      When the user returns from the widget task editor
      Then the final result should discard unsaved edits

    Scenario: widget tap should open a read only task when a stale entry is now completed
      Given a stale widget entry for a completed task
      When the widget delivers a task link
      Then the result should open a read only task

    Scenario: widget tap should open one editor when a launch is delivered twice
      Given a widget launch that can be delivered twice
      When the widget delivers a task link
      Then the result should open one editor

      When the user returns after the duplicate widget launch
      Then the final result should open one editor

      When the same widget task is tapped after returning home
      Then the final result should open one editor

    Scenario: widget tap should open Home when the link lacks task identity
      Given a widget link without task identity
      When the widget delivers a task link
      Then the result should open Home

    Scenario: widget tap should refresh once when the task is missing from cache
      Given an uncached task recoverable by refresh
      When the widget delivers a task link
      Then the result should refresh once

    Scenario Outline: widget tap should explain unavailability when the task is <availability>
      Given an unavailable widget task in the selected network state {<offline>}
      When the widget delivers a task link
      Then the result should explain unavailability

      Examples:
        | offline | availability |
        | false | deleted |
        | true | offline and uncached |

    Scenario: widget tap should prefer the latest task when lookups overlap
      Given widget task lookups that can overlap
      When the widget delivers a task link
      Then the result should prefer the latest task
