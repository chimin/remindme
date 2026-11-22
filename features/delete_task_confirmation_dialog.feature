@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: delete task confirmation dialog
  Background:
    Given scenario state is isolated

  Scenario: confirmation dialog should display the task title when opened
    Given a task titled Water plants
    When the deletion dialog opens or is dismissed
    Then the result should display the task title

  Scenario Outline: confirmation dialog should return <expected> when <trigger>
    Given a task deletion dialog with the selected dismissal action {<action>}
    When the deletion dialog opens or is dismissed
    Then the result should return the selected result

    Examples:
      | action | expected | trigger |
      | 'Delete' | true | Delete is tapped |
      | 'Cancel' | false | Cancel is tapped |
      | 'barrier' | null | the barrier is tapped |
      | 'back' | null | back navigation is requested |

