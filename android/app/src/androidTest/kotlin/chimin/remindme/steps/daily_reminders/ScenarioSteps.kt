package chimin.remindme.steps.daily_reminders

import chimin.remindme.*
import io.cucumber.java.en.Given
import io.cucumber.java.en.When
import io.cucumber.java.en.Then
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import chimin.remindme.reminders.DailyReminders
import chimin.remindme.reminders.DailyReminderReceiver
import org.json.JSONObject
import org.junit.Assert.*
import java.io.File
import java.util.Calendar

class ScenarioSteps {
    private val state = ScenarioContext()

    @io.cucumber.java.Before("@daily_reminders")
    fun rememberState(): Unit = with(state) {
        previousState = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE).getString("state", null)
        snapshotSaved = true
        DailyReminders.replace(context, JSONObject("{}"))
        waitForNotification(false)
    }

    @io.cucumber.java.After("@daily_reminders")
    fun restoreState(): Unit = with(state) {
        if (snapshotSaved && InstrumentationRegistry.getArguments().getString("armDailyReminder") != "true") {
            DailyReminders.replace(context, JSONObject(previousState ?: "{}"))
            device.pressHome()
        }
    }

    @Given("the Singapore clock is at the reminder time")
    fun theSingaporeClockIsAtTheReminderTime(): Unit = with(state) {
        now = date("Asia/Singapore", 2026, 11, 22, 8, 0)
    }

    @When("the next eight oclock reminder is calculated")
    fun theNextEightOclockReminderIsCalculated(): Unit = with(state) {
        next = DailyReminders.nextOccurrence(now, 8, 0)
    }

    @Then("the reminder is tomorrow at eight")
    fun theReminderIsTomorrowAtEight(): Unit = with(state) {
        assertEquals(23, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
        assertTrue(next.timeInMillis > now.timeInMillis)
    }

    @Given("the New York clock is before the spring transition")
    fun theNewYorkClockIsBeforeTheSpringTransition(): Unit = with(state) {
        now = date("America/New_York", 2026, 3, 7, 9, 0)
    }

    @When("the next morning reminder is calculated across DST")
    fun theNextMorningReminderIsCalculatedAcrossDst(): Unit = with(state) {
        next = DailyReminders.nextOccurrence(now, 8, 0)
    }

    @Then("the reminder keeps eight oclock after twenty two hours")
    fun theReminderKeepsEightOclockAfterTwentyTwoHours(): Unit = with(state) {
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(8, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(22L * 60 * 60 * 1000, next.timeInMillis - now.timeInMillis)
    }

    @Given("the New York clock is after the missing spring hour")
    fun theNewYorkClockIsAfterTheMissingSpringHour(): Unit = with(state) {
        now = date("America/New_York", 2026, 3, 8, 12, 0)
    }

    @When("the next two thirty reminder is calculated")
    fun theNextTwoThirtyReminderIsCalculated(): Unit = with(state) {
        next = DailyReminders.nextOccurrence(now, 2, 30)
    }

    @Then("the reminder uses two thirty tomorrow")
    fun theReminderUsesTwoThirtyTomorrow(): Unit = with(state) {
        assertEquals(9, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(2, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(30, next.get(Calendar.MINUTE))
    }

    @Given("three local timezones are available")
    fun threeLocalTimezonesAreAvailable(): Unit = with(state) {
        occurrences.clear()
    }

    @When("the reminder is calculated one minute before eight in each timezone")
    fun theReminderIsCalculatedOneMinuteBeforeEightInEachTimezone(): Unit = with(state) {
        for (zone in listOf("Asia/Singapore", "America/New_York", "Pacific/Auckland")) {
            val local = date(zone, 2026, 11, 22, 7, 59)
            occurrences.add(local to DailyReminders.nextOccurrence(local, 8, 0))
        }
    }

    @Then("each reminder keeps the local date and is one minute away")
    fun eachReminderKeepsTheLocalDateAndIsOneMinuteAway(): Unit = with(state) {
        for ((local, reminder) in occurrences) {
            assertEquals(22, reminder.get(Calendar.DAY_OF_MONTH))
            assertEquals(60_000L, reminder.timeInMillis - local.timeInMillis)
        }
    }

    @Given("the New York clock is in the repeated autumn hour")
    fun theNewYorkClockIsInTheRepeatedAutumnHour(): Unit = with(state) {
        now = date("America/New_York", 2026, 11, 1, 1, 30)
    }

    @When("the already fired one thirty reminder is calculated")
    fun theAlreadyFiredOneThirtyReminderIsCalculated(): Unit = with(state) {
        next = DailyReminders.nextOccurrence(now, 1, 30, tomorrow = true)
    }

    @Then("the repeated hour is skipped until tomorrow")
    fun theRepeatedHourIsSkippedUntilTomorrow(): Unit = with(state) {
        assertEquals(2, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(1, next.get(Calendar.HOUR_OF_DAY))
        assertTrue(next.timeInMillis > now.timeInMillis)
    }

    @Given("a reminder snapshot contains mixed task states")
    fun aReminderSnapshotContainsMixedTaskStates(): Unit = with(state) {
        snapshot = JSONObject("""{"tasks":[
          {"title":"Overdue","year":2026,"month":11,"day":21},
          {"title":"Today","year":2026,"month":11,"day":22},
          {"title":"Future","year":2026,"month":11,"day":23},
          {"title":"Completed","year":2026,"month":11,"day":21,"completed":true},
          {"title":"Deleted","year":2026,"month":11,"day":21,"deleted":true},
          {"title":"Undated","year":null}, {"title":"Invalid"}
        ]}""")
    }

    @When("the mixed snapshot is summarized for November twenty second")
    fun theMixedSnapshotIsSummarizedForNovemberTwentySecond(): Unit = with(state) {
        summary = DailyReminders.summary(snapshot, date("Asia/Singapore", 2026, 11, 22, 0, 0))
    }

    @Then("only overdue and today tasks appear in the summary")
    fun onlyOverdueAndTodayTasksAppearInTheSummary(): Unit = with(state) {
        assertEquals("1 overdue \u00b7 1 today", summary.first)
        assertEquals(listOf("Overdue", "Today"), summary.second)
    }

    @Given("a reminder snapshot has no tasks")
    fun aReminderSnapshotHasNoTasks(): Unit = with(state) {
        snapshot = JSONObject("""{"tasks":[]}""")
    }

    @When("the empty snapshot is summarized")
    fun theEmptySnapshotIsSummarized(): Unit = with(state) {
        summary = DailyReminders.summary(snapshot, Calendar.getInstance())
    }

    @Then("the summary has no task titles")
    fun theSummaryHasNoTaskTitles(): Unit = with(state) {
        assertTrue(summary.second.isEmpty())
    }

    @Given("due reminders have notification permission")
    fun dueRemindersHaveNotificationPermission(): Unit = with(state) {
        grantPermission()
        DailyReminders.replace(context, fixture())
    }

    @When("the daily reminder broadcast is received")
    fun theDailyReminderBroadcastIsReceived(): Unit = with(state) {
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
    }

    @Then("an expandable reminder summary contains the due tasks")
    fun checkExpandableSummary(): Unit = with(state) {
        waitForNotification(true)
        val posted = manager.activeNotifications.single { it.id == 804 }.notification
        assertEquals("1 overdue \u00b7 1 today", posted.extras.getString("android.title"))
        assertTrue(posted.extras.getCharSequence("android.bigText").toString().contains("Pick up groceries"))
    }

    @When("the reminder notification shade is opened")
    fun openNotificationShade(): Unit = with(state) {
        device.openNotification()
    }

    @Then("the reminder notification is visible and captured")
    fun captureNotification(): Unit = with(state) {
        assertTrue(device.wait(Until.hasObject(By.text("1 overdue \u00b7 1 today")), 10000))
        val directory = File(context.getExternalFilesDir("test_output"), "golden/daily_reminder")
        directory.mkdirs()
        assertTrue(device.takeScreenshot(File(directory, "daily_reminder_when_tasks_are_due.png")))
    }

    @When("the reminder summary notification is tapped")
    fun tapNotification(): Unit = with(state) {
        device.findObject(By.text("1 overdue \u00b7 1 today")).click()
    }

    @Then("the reminder opens the app home")
    fun checkReminderHome(): Unit = with(state) {
        assertTrue(device.wait(Until.hasObject(By.pkg(context.packageName)), 20000))
    }

    @Given("a due reminder notification is posted")
    fun aDueReminderNotificationIsPosted(): Unit = with(state) {
        grantPermission()
        DailyReminders.replace(context, fixture())
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
    }

    @When("the account signs out")
    fun theAccountSignsOut(): Unit = with(state) {
        DailyReminders.replace(context, JSONObject("""{"active":false,"enabled":true,"tasks":[]}"""))
    }

    @Then("the notification and saved tasks are cleared")
    fun theNotificationAndSavedTasksAreCleared(): Unit = with(state) {
        waitForNotification(false)
        assertFalse(manager.activeNotifications.any { it.id == 804 })
        val saved = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE).getString("state", null)!!
        assertEquals(0, JSONObject(saved).getJSONArray("tasks").length())
    }

    @Given("notification permission was revoked before instrumentation")
    fun notificationPermissionWasRevokedBeforeInstrumentation(): Unit = with(state) {
        org.junit.Assume.assumeTrue("Revoke POST_NOTIFICATIONS before this isolated run",
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED)
        DailyReminders.replace(context, fixture())
    }

    @When("a daily reminder is received without permission")
    fun aDailyReminderIsReceivedWithoutPermission(): Unit = with(state) {
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
    }

    @Then("notifications remain disabled and no reminder appears")
    fun notificationsRemainDisabledAndNoReminderAppears(): Unit = with(state) {
        waitForNotification(false)
        assertFalse(manager.areNotificationsEnabled())
    }

    @Given("notification permission is granted for suppression checks")
    fun notificationPermissionIsGrantedForSuppressionChecks(): Unit = with(state) {
        grantPermission()
    }

    @When("disabled and empty reminder snapshots are received")
    fun disabledAndEmptyReminderSnapshotsAreReceived(): Unit = with(state) {
        DailyReminders.replace(context, fixture().put("enabled", false))
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        waitForNotification(false)
        disabledNotification = manager.activeNotifications.any { it.id == 804 }
        DailyReminders.replace(context, fixture().put("tasks", org.json.JSONArray()))
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
    }

    @Then("neither disabled nor empty reminders post notifications")
    fun neitherDisabledNorEmptyRemindersPostNotifications(): Unit = with(state) {
        waitForNotification(false)
        assertFalse(disabledNotification)
        assertFalse(manager.activeNotifications.any { it.id == 804 })
    }

    @Given("notification permission is granted for refresh")
    fun notificationPermissionIsGrantedForRefresh(): Unit = with(state) {
        grantPermission()
    }

    @When("the app opens with immediate reminders enabled")
    fun openWithReminders(): Unit = with(state) {
        DailyReminders.replace(context, fixture().put("notifyNow", true))
    }

    @Then("a reminder notification is posted immediately")
    fun checkImmediateReminder(): Unit = with(state) {
        waitForNotification(true)
    }

    @When("the grocery task title is refreshed")
    fun refreshGroceryTitle(): Unit = with(state) {
        val updated = fixture()
        updated.getJSONArray("tasks").getJSONObject(1).put("title", "Updated groceries")
        DailyReminders.replace(context, updated)
    }

    @Then("the posted summary contains the refreshed task title")
    fun checkRefreshedSummary(): Unit = with(state) {
        repeat(50) {
            val text = manager.activeNotifications.singleOrNull { it.id == 804 }?.notification
                ?.extras?.getCharSequence("android.bigText").toString()
            if (text.contains("Updated groceries")) return@with
            Thread.sleep(100)
        }
        val notification = manager.activeNotifications.single { it.id == 804 }.notification
        assertTrue(notification.extras.getCharSequence("android.bigText").toString().contains("Updated groceries"))
    }

    @When("reminders are disabled while immediate delivery is requested")
    fun disableImmediateReminder(): Unit = with(state) {
        DailyReminders.replace(context, fixture().put("enabled", false).put("notifyNow", true))
    }

    @Then("the refreshed reminder notification is removed")
    fun checkRemovedReminder(): Unit = with(state) {
        waitForNotification(false)
    }

    @Given("an active reminder schedule is saved")
    fun anActiveReminderScheduleIsSaved(): Unit = with(state) {
        DailyReminders.replace(context, fixture())
    }

    @When("boot package and clock change broadcasts are received")
    fun bootPackageAndClockChangeBroadcastsAreReceived(): Unit = with(state) {
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            DailyReminderReceiver().onReceive(context, Intent(action))
            restoredAlarms.add(manager.activeNotifications.any { it.id == 804 } to device.executeShellCommand("dumpsys alarm"))
        }
    }

    @Then("each broadcast restores the alarm without a notification")
    fun eachBroadcastRestoresTheAlarmWithoutANotification(): Unit = with(state) {
        for ((posted, dump) in restoredAlarms) {
            assertFalse(posted)
            assertTrue(dump.contains("chimin.remindme.DAILY_REMINDER"))
        }
    }

    @Given("the device supports notification channels")
    fun theDeviceSupportsNotificationChannels(): Unit = with(state) {
        org.junit.Assume.assumeTrue("Notification channels require API 26+", Build.VERSION.SDK_INT >= 26)
    }

    @When("the reminder channel and its sound settings are opened")
    fun theReminderChannelAndItsSoundSettingsAreOpened(): Unit = with(state) {
        DailyReminders.createChannel(context)
        channel = manager.getNotificationChannel(DailyReminders.CHANNEL)
        val intent = Intent(android.provider.Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(android.provider.Settings.EXTRA_CHANNEL_ID, DailyReminders.CHANNEL)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    @Then("the named channel has sound and system settings are displayed")
    fun theNamedChannelHasSoundAndSystemSettingsAreDisplayed(): Unit = with(state) {
        assertEquals("Daily task reminders", channel.name.toString())
        assertNotNull(channel.sound)
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.settings")), 10000))
    }

    @Given("closed app alarm arming is explicitly requested")
    fun closedAppAlarmArmingIsExplicitlyRequested(): Unit = with(state) {
        org.junit.Assume.assumeTrue("Pass -e armDailyReminder true to retain the armed alarm",
            InstrumentationRegistry.getArguments().getString("armDailyReminder") == "true")
    }

    @When("a reminder alarm is armed fifteen seconds ahead")
    fun aReminderAlarmIsArmedFifteenSecondsAhead(): Unit = with(state) {
        grantPermission()
        DailyReminders.replace(context, fixture())
        val intent = Intent(context, DailyReminderReceiver::class.java).setAction("chimin.remindme.DAILY_REMINDER")
        val pending = android.app.PendingIntent.getBroadcast(context, 804, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        (context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager)
            .set(android.app.AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 15000, pending)
    }

    @Then("the armed schedule is retained for manual closed app observation")
    fun theArmedScheduleIsRetainedForManualClosedAppObservation(): Unit = with(state) {
        // Delivery is observed manually after instrumentation exits.
    }
}
