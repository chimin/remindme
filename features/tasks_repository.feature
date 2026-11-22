@testMethodName:unitScenario
@testerType:ScenarioState
Feature: tasks repository
  Background:
    Given scenario state is isolated

  Rule: Refreshing reminders from cached tasks

    Scenario: refresh reminders should mirror selected cached tasks when offline
      Given offline for refresh reminders to mirror selected cached tasks
      When refresh reminders is performed
      Then the result should mirror selected cached tasks

      When refresh reminders continues
      Then the result should mirror selected cached tasks

      When refresh reminders continues
      Then the result should mirror selected cached tasks

      When refresh reminders continues
      Then the result should mirror selected cached tasks

  Rule: Initializing and reading the task cache

    Scenario: initialize should leave the task box closed when the user is signed out
      Given the user is signed out for initialize to leave the task box closed
      When initialize is performed
      Then the result should leave the task box closed

    Scenario: read tasks should return an empty snapshot without network when an empty list was cached
      Given an empty list was cached for read tasks to return an empty snapshot without network
      When read tasks is performed
      Then the result should return an empty snapshot without network

    Scenario: read cached tasks should return saved tasks when the server is offline
      Given the server is offline for read cached tasks to return saved tasks
      When read cached tasks is performed
      Then the result should return saved tasks

  Rule: Completing and reopening recurring tasks

    Scenario: complete task should retain history and clone metadata when task repeats
      Given task repeats for complete task to retain history and clone metadata
      When complete task is performed
      Then the result should retain history and clone metadata

      When complete task continues
      Then the result should retain history and clone metadata

      When complete task continues
      Then the result should retain history and clone metadata

    Scenario: update task should complete edited fields and preserve successors when a recurring task is reopened
      Given a recurring task is reopened for update task to complete edited fields and preserve successors
      When update task is performed
      Then the result should complete edited fields and preserve successors

      When update task continues
      Then the result should complete edited fields and preserve successors

      When update task continues
      Then the result should complete edited fields and preserve successors

    Scenario: complete task should create one successor when completion requests overlap
      Given completion requests overlap for complete task to create one successor
      When complete task is performed
      Then the result should create one successor

    Scenario: complete task should retain the series when a successor is completed
      Given a successor is completed for complete task to retain the series
      When complete task is performed
      Then the result should retain the series

      When complete task continues
      Then the result should retain the series

    Scenario: complete task should keep a single task when recurrence is absent
      Given recurrence is absent for complete task to keep a single task
      When complete task is performed
      Then the result should keep a single task

  Rule: Syncing recurring task occurrences

    Scenario: sync should recover both writes when completion was saved offline before restart
      Given completion was saved offline before restart for sync to recover both writes
      When sync is performed
      Then the result should recover both writes

      When sync continues
      Then the result should recover both writes

    Scenario: sync should reconcile the existing clone when create response is lost
      Given create response is lost for sync to reconcile the existing clone
      When sync is performed
      Then the result should reconcile the existing clone

      When sync continues
      Then the result should reconcile the existing clone

      When sync continues
      Then the result should reconcile the existing clone

    Scenario: pull should clone a task when completion happened in Google Tasks
      Given completion happened in Google Tasks for pull to clone a task
      When pull is performed
      Then the result should clone a task

    Scenario: pull should respect a deleted successor when cache is rebuilt
      Given cache is rebuilt for pull to respect a deleted successor
      When pull is performed
      Then the result should respect a deleted successor

  Rule: Managing account connections and cache ownership

    Scenario: API request should preserve cached access when refreshed credentials are rejected
      Given refreshed credentials are rejected for API request to preserve cached access
      When API request is performed
      Then the result should preserve cached access

    Scenario: sign out should clear pending tasks when the user disconnects
      Given the user disconnects for sign out to clear pending tasks
      When sign out is performed
      Then the result should clear pending tasks

    Scenario: link should retain legacy pending tasks when the selected account does not own their list
      Given the selected account does not own their list for link to retain legacy pending tasks
      When link is performed
      Then the result should retain legacy pending tasks

    Scenario: link should adopt the cache when the selected account owns its legacy list
      Given the selected account owns its legacy list for link to adopt the cache
      When link is performed
      Then the result should adopt the cache

    Scenario: authentication should forward state and preserve injected ownership when repositories are composed
      Given repositories are composed for authentication to forward state and preserve injected ownership
      When authentication is performed
      Then the result should forward state and preserve injected ownership

      When authentication continues
      Then the result should forward state and preserve injected ownership

      When authentication continues
      Then the result should forward state and preserve injected ownership

  Rule: Editing and deleting tasks created offline

    Scenario: create task should remain editable and deletable when Google is offline
      Given Google is offline for create task to remain editable and deletable
      When create task is performed
      Then the result should remain editable and deletable

    Scenario: edit task should resolve its server identity when an offline editor remains open during sync
      Given an offline editor remains open during sync for edit task to resolve its server identity
      When edit task is performed
      Then the result should resolve its server identity

  Rule: Merging local and remote tasks

    Scenario: mergeTasks should keep the local entry when it is newer than the remote entry
      Given it is newer than the remote entry for mergeTasks to keep the local entry
      When mergeTasks is performed
      Then the result should keep the local entry

    Scenario: mergeTasks should prefer the remote entry when it is newer than the local entry
      Given it is newer than the local entry for mergeTasks to prefer the remote entry
      When mergeTasks is performed
      Then the result should prefer the remote entry

    Scenario: mergeTasks should preserve a locally-requested deletion when newer than the remote entry
      Given newer than the remote entry for mergeTasks to preserve a locally-requested deletion
      When mergeTasks is performed
      Then the result should preserve a locally-requested deletion

    Scenario: mergeTasks should add remote-only tasks and clear the dirty flag when tasks are absent locally
      Given tasks are absent locally for mergeTasks to add remote-only tasks and clear the dirty flag
      When mergeTasks is performed
      Then the result should add remote-only tasks and clear the dirty flag

    Scenario: mergeTasks should keep local-only entries when tasks are absent remotely
      Given tasks are absent remotely for mergeTasks to keep local-only entries
      When mergeTasks is performed
      Then the result should keep local-only entries
