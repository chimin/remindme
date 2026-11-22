@testMethodName:unitScenario
@testerType:ScenarioState
Feature: sync service
  Background:
    Given scenario state is isolated

  Rule: Running background sync

    Scenario: background sync should defer without creating a repository when foreground storage is owned
      Given foreground storage is owned for background sync to defer without creating a repository
      When background sync is performed
      Then the result should defer without creating a repository

    Scenario: background sync should release storage when no account is linked
      Given no account is linked for background sync to release storage
      When background sync is performed
      Then the result should release storage

      When background sync continues
      Then the result should release storage

    Scenario: background sync should avoid retrying consent when interaction is required
      Given interaction is required for background sync to avoid retrying consent
      When background sync is performed
      Then the result should avoid retrying consent

  Rule: Syncing the selected task list

    Scenario: sync should share one push and pull when refresh requests overlap
      Given refresh requests overlap for sync to share one push and pull
      When sync is performed
      Then the result should share one push and pull

      When sync continues
      Then the result should share one push and pull

    Scenario: sync should allow retry when a shared refresh fails
      Given a shared refresh fails for sync to allow retry
      When sync is performed
      Then the result should allow retry

    Scenario: sync should push dirty local changes to remote then pull remote when a tasklist is selected
      Given a tasklist is selected for sync to push dirty local changes to remote then pull remote
      When sync is performed
      Then the result should push dirty local changes to remote then pull remote

    Scenario: sync should skip clean entries when tasks have no local changes
      Given tasks have no local changes for sync to skip clean entries
      When sync is performed
      Then the result should skip clean entries

    Scenario: sync should do nothing when no tasklist is selected
      Given no tasklist is selected for sync to do nothing
      When sync is performed
      Then the result should do nothing
