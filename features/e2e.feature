@testMethodName:patrolScenario
@testerName:tester
@testerType:PatrolIntegrationTester
Feature: Google Tasks lifecycle
  Background:
    # Patrol also resets native Tasks authorization before the app can sign in.
    Given the app starts with clean local data
    And I capture screenshot {'01_sign_in_required'} and compare with the golden reference

  Scenario: task lifecycle should create edit and delete a task when Google Tasks permission is granted
    # Fresh Google sign-in and Google Tasks permission confirmation are mandatory.
    # Before EVERY run, unlink Remind Me at https://myaccount.google.com/connections.
    # Clearing app data or signing out does not revoke Google's saved consent.
    # Do not remove or weaken the consent checks: silent sign-in must fail.
    When I start Google sign in
    And I continue Google sign in to {'02_account_selected'} if shown
    And I capture screenshot {'02_account_selected'} and compare with the golden reference
    And I continue Google sign in to {'02_development_warning'} if shown
    And I capture screenshot {'02_development_warning'} and compare with the golden reference
    And I continue Google sign in to {'03_development_confirmation'} if shown
    And I capture screenshot {'03_development_confirmation'} and compare with the golden reference
    And I continue Google sign in to {'04_tasks_consent'} if shown
    And I capture screenshot {'04_tasks_consent'} and compare with the golden reference
    And I continue Google sign in to {'05_tasks_confirmation'} if shown
    And I capture screenshot {'05_tasks_confirmation'} and compare with the golden reference
    And I finish Google sign in
    And I allow notification permission if prompted
    Then the selected accounts task list should load
    And I capture screenshot {'06_home'} and compare with the golden reference

    When I enter a task title and notes
    And I capture screenshot {'07_new_task_form'} and compare with the golden reference
    And I save the task
    Then the task should exist in Google Tasks
    And I capture screenshot {'08_created'} and compare with the golden reference

    When I edit the tasks title and notes
    And I capture screenshot {'09_edited_task_form'} and compare with the golden reference
    And I save the task
    Then the same Google task should contain the changes
    And I capture screenshot {'10_edited'} and compare with the golden reference

    When I open the task for deletion
    And I capture screenshot {'11_before_delete'} and compare with the golden reference
    And I request task deletion
    And I capture screenshot {'12_delete_confirmation'} and compare with the golden reference
    And I confirm task deletion
    Then the task should be absent from Google Tasks
    And I capture screenshot {'13_deleted'} and compare with the golden reference

    When I request sign out
    And I capture screenshot {'14_sign_out_confirmation'} and compare with the golden reference
    And I confirm sign out
    And I capture screenshot {'15_sign_in_required'} and compare with the golden reference
    And I cancel account selection
    Then the login screen should appear
    And I capture screenshot {'16_sign_in_canceled'} and compare with the golden reference
