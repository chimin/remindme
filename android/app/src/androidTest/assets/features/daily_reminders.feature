@daily_reminders
Feature: Daily reminders

  Rule: Local scheduling

    Scenario: nextOccurrence should use tomorrow when time has passed
      Given the Singapore clock is at the reminder time
      When the next eight oclock reminder is calculated
      Then the reminder is tomorrow at eight

    Scenario: nextOccurrence should preserve local hour when DST starts
      Given the New York clock is before the spring transition
      When the next morning reminder is calculated across DST
      Then the reminder keeps eight oclock after twenty two hours

    Scenario: nextOccurrence should restore chosen hour when today has missing DST hour
      Given the New York clock is after the missing spring hour
      When the next two thirty reminder is calculated
      Then the reminder uses two thirty tomorrow

    Scenario: nextOccurrence should use local date when timezone changes
      Given three local timezones are available
      When the reminder is calculated one minute before eight in each timezone
      Then each reminder keeps the local date and is one minute away

    Scenario: nextOccurrence should skip repeated hour when reminder already fired
      Given the New York clock is in the repeated autumn hour
      When the already fired one thirty reminder is calculated
      Then the repeated hour is skipped until tomorrow

  Rule: Notification summaries

    Scenario: summary should exclude ineligible tasks when snapshot has mixed states
      Given a reminder snapshot contains mixed task states
      When the mixed snapshot is summarized for November twenty second
      Then only overdue and today tasks appear in the summary

    Scenario: summary should return empty when no tasks qualify
      Given a reminder snapshot has no tasks
      When the empty snapshot is summarized
      Then the summary has no task titles

  Rule: Notification delivery and refresh

    Scenario: receive should post expandable summary and open home when tasks are due
      Given due reminders have notification permission
      When the daily reminder broadcast is received
      Then an expandable reminder summary contains the due tasks
      And the app symbol is visible in the status bar and captured

      When the reminder notification shade is opened
      Then the reminder notification is visible and captured

      When the reminder notification is expanded
      Then the expanded reminder notification is visible and captured

      When the reminder summary notification is tapped
      Then the reminder opens the app home

    Scenario: replace should clear snapshot and notification when signed out
      Given a due reminder notification is posted
      When the account signs out
      Then the notification and saved tasks are cleared

    @api33 @permission_denied
    Scenario: receive should skip notification when permission was denied
      Given notification permission was revoked before instrumentation
      When a daily reminder is received without permission
      Then notifications remain disabled and no reminder appears

    Scenario: receive should skip notification when disabled or empty
      Given notification permission is granted for suppression checks
      When disabled and empty reminder snapshots are received
      Then neither disabled nor empty reminders post notifications

    Scenario: replace should post and keep summary when the app opens and tasks refresh
      Given notification permission is granted for refresh
      When the app opens with immediate reminders enabled
      Then a reminder notification is posted immediately

      When the grocery task title is refreshed
      Then the posted summary contains the refreshed task title

      When reminders are disabled while immediate delivery is requested
      Then the refreshed reminder notification is removed

  Rule: Alarm restoration and settings

    Scenario: receive should restore one alarm without posting when boot or clock changes
      Given an active reminder schedule is saved
      When boot package and clock change broadcasts are received
      Then each broadcast restores the alarm without a notification

    Scenario: createChannel should provide system sound settings when channel is created
      Given the device supports notification channels
      When the reminder channel and its sound settings are opened
      Then the named channel has sound and system settings are displayed

    @arm_alarm
    Scenario: armAlarm should retain schedule when closed app delivery is requested
      Given closed app alarm arming is explicitly requested
      When a reminder alarm is armed fifteen seconds ahead
      Then the armed schedule is retained for manual closed app observation
