package chimin.remindme

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import chimin.remindme.reminders.DailyReminderReceiver
import org.junit.After
import org.junit.Before
import java.io.File
import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import chimin.remindme.reminders.DailyReminders
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Calendar
import java.util.TimeZone

@RunWith(AndroidJUnit4::class)
class DailyRemindersPluginTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)
    private val manager get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var previousState: String? = null

    @Before fun rememberState() {
        previousState = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE).getString("state", null)
    }

    @After fun restoreState() {
        if (InstrumentationRegistry.getArguments().getString("armDailyReminder") == "true") return
        DailyReminders.replace(context, JSONObject(previousState ?: "{}"))
        device.pressHome()
    }

    private fun fixture(): JSONObject {
        val today = Calendar.getInstance()
        val yesterday = today.clone() as Calendar
        yesterday.add(Calendar.DAY_OF_MONTH, -1)
        fun task(title: String, day: Calendar) = JSONObject().put("title", title)
            .put("year", day.get(Calendar.YEAR)).put("month", day.get(Calendar.MONTH) + 1)
            .put("day", day.get(Calendar.DAY_OF_MONTH))
        return JSONObject().put("active", true).put("enabled", true).put("hour", 8).put("minute", 0)
            .put("tasks", org.json.JSONArray().put(task("Renew library books", yesterday))
                .put(task("Pick up groceries", today)))
    }

    private fun waitForNotification(expected: Boolean) {
        repeat(50) {
            if (manager.activeNotifications.any { it.id == 804 } == expected) return
            Thread.sleep(100)
        }
        assertEquals(expected, manager.activeNotifications.any { it.id == 804 })
    }

    private fun grantPermission() {
        if (Build.VERSION.SDK_INT >= 33) device.executeShellCommand("pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS")
    }

    private fun date(zone: String, year: Int, month: Int, day: Int, hour: Int, minute: Int): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
            clear(); set(year, month - 1, day, hour, minute, 0)
        }

    @Test fun nextOccurrence_shouldUseTomorrow_whenTimeHasPassed() {
        val now = date("Asia/Singapore", 2026, 11, 22, 8, 0)
        val next = DailyReminders.nextOccurrence(now, 8, 0)
        assertEquals(23, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
        assertTrue(next.timeInMillis > now.timeInMillis)
    }

    @Test fun nextOccurrence_shouldPreserveLocalHour_whenDSTStarts() {
        val now = date("America/New_York", 2026, 3, 7, 9, 0)
        val next = DailyReminders.nextOccurrence(now, 8, 0)
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(8, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(22L * 60 * 60 * 1000, next.timeInMillis - now.timeInMillis)
    }

    @Test fun nextOccurrence_shouldRestoreChosenHour_whenTodayHasMissingDSTHour() {
        val now = date("America/New_York", 2026, 3, 8, 12, 0)
        val next = DailyReminders.nextOccurrence(now, 2, 30)
        assertEquals(9, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(2, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(30, next.get(Calendar.MINUTE))
    }

    @Test fun nextOccurrence_shouldUseLocalDate_whenTimezoneChanges() {
        for (zone in listOf("Asia/Singapore", "America/New_York", "Pacific/Auckland")) {
            val now = date(zone, 2026, 11, 22, 7, 59)
            val next = DailyReminders.nextOccurrence(now, 8, 0)
            assertEquals(22, next.get(Calendar.DAY_OF_MONTH))
            assertEquals(60_000L, next.timeInMillis - now.timeInMillis)
        }
    }

    @Test fun summary_shouldExcludeIneligibleTasks_whenSnapshotHasMixedStates() {
        val state = JSONObject("""{"tasks":[
          {"title":"Overdue","year":2026,"month":11,"day":21},
          {"title":"Today","year":2026,"month":11,"day":22},
          {"title":"Future","year":2026,"month":11,"day":23},
          {"title":"Completed","year":2026,"month":11,"day":21,"completed":true},
          {"title":"Deleted","year":2026,"month":11,"day":21,"deleted":true},
          {"title":"Undated","year":null}, {"title":"Invalid"}
        ]}""")
        val (counts, titles) = DailyReminders.summary(state, date("Asia/Singapore", 2026, 11, 22, 0, 0))
        assertEquals("1 overdue · 1 today", counts)
        assertEquals(listOf("Overdue", "Today"), titles)
    }

    @Test fun summary_shouldReturnEmpty_whenNoTasksQualify() {
        assertTrue(DailyReminders.summary(JSONObject("""{"tasks":[]}"""), Calendar.getInstance()).second.isEmpty())
    }
    @Test fun receive_shouldPostExpandableSummaryAndOpenHome_whenTasksAreDue() {
        grantPermission()
        DailyReminders.replace(context, fixture())
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        waitForNotification(true)
        val posted = manager.activeNotifications.single { it.id == 804 }.notification
        assertEquals("1 overdue \u00b7 1 today", posted.extras.getString("android.title"))
        assertTrue(posted.extras.getCharSequence("android.bigText").toString().contains("Pick up groceries"))
        device.openNotification()
        assertTrue(device.wait(Until.hasObject(By.text("1 overdue \u00b7 1 today")), 10000))
        val directory = File(context.getExternalFilesDir("test_output"), "golden/daily_reminder")
        directory.mkdirs()
        assertTrue(device.takeScreenshot(File(directory, "daily_reminder_when_tasks_are_due.png")))
        device.findObject(By.text("1 overdue \u00b7 1 today")).click()
        assertTrue(device.wait(Until.hasObject(By.pkg(context.packageName)), 20000))
    }

    @Test fun replace_shouldClearSnapshotAndNotification_whenSignedOut() {
        grantPermission()
        DailyReminders.replace(context, fixture())
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        DailyReminders.replace(context, JSONObject("""{"active":false,"enabled":true,"tasks":[]}"""))
        assertFalse(manager.activeNotifications.any { it.id == 804 })
        val saved = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE).getString("state", null)!!
        assertEquals(0, JSONObject(saved).getJSONArray("tasks").length())
    }

    @Test fun receive_shouldSkipNotification_whenPermissionWasDenied() {
        if (Build.VERSION.SDK_INT < 33) return
        // Revoke permission before starting this isolated instrumentation case.
        org.junit.Assume.assumeTrue(context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED)
        DailyReminders.replace(context, fixture())
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        waitForNotification(false)
        assertFalse(manager.areNotificationsEnabled())
    }

    @Test fun receive_shouldSkipNotification_whenDisabledOrEmpty() {
        grantPermission()
        val disabled = fixture().put("enabled", false)
        DailyReminders.replace(context, disabled)
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        assertFalse(manager.activeNotifications.any { it.id == 804 })
        DailyReminders.replace(context, fixture().put("tasks", org.json.JSONArray()))
        DailyReminderReceiver().onReceive(context, Intent("chimin.remindme.DAILY_REMINDER"))
        assertFalse(manager.activeNotifications.any { it.id == 804 })
    }

    @Test fun receive_shouldRestoreOneAlarmWithoutPosting_whenBootOrClockChanges() {
        DailyReminders.replace(context, fixture())
        for (action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            DailyReminderReceiver().onReceive(context, Intent(action))
            assertFalse(manager.activeNotifications.any { it.id == 804 })
            val dump = device.executeShellCommand("dumpsys alarm")
            assertTrue(dump.contains("chimin.remindme.DAILY_REMINDER"))
        }
    }

    @Test fun createChannel_shouldProvideSystemSoundSettings_whenChannelIsCreated() {
        if (Build.VERSION.SDK_INT < 26) return
        DailyReminders.createChannel(context)
        val channel = manager.getNotificationChannel(DailyReminders.CHANNEL)
        assertEquals("Daily task reminders", channel.name.toString())
        assertNotNull(channel.sound)
        val intent = Intent(android.provider.Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(android.provider.Settings.EXTRA_CHANNEL_ID, DailyReminders.CHANNEL)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        assertTrue(device.wait(Until.hasObject(By.pkg("com.android.settings")), 10000))
    }

    @Test fun armAlarm_shouldRetainSchedule_whenClosedAppDeliveryIsRequested() {
        org.junit.Assume.assumeTrue(InstrumentationRegistry.getArguments().getString("armDailyReminder") == "true")
        grantPermission()
        DailyReminders.replace(context, fixture())
        val intent = Intent(context, DailyReminderReceiver::class.java).setAction("chimin.remindme.DAILY_REMINDER")
        val pending = android.app.PendingIntent.getBroadcast(context, 804, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)
        (context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager)
            .set(android.app.AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 15000, pending)
    }

    @Test fun nextOccurrence_shouldSkipRepeatedHour_whenReminderAlreadyFired() {
        val now = date("America/New_York", 2026, 11, 1, 1, 30)
        val next = DailyReminders.nextOccurrence(now, 1, 30, tomorrow = true)
        assertEquals(2, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(1, next.get(Calendar.HOUR_OF_DAY))
        assertTrue(next.timeInMillis > now.timeInMillis)
    }

    @Test fun replace_shouldPostAndKeepSummary_whenTheAppOpensAndTasksRefresh() {
        grantPermission()
        DailyReminders.replace(context, fixture().put("notifyNow", true))
        waitForNotification(true)
        val updated = fixture()
        updated.getJSONArray("tasks").getJSONObject(1).put("title", "Updated groceries")
        DailyReminders.replace(context, updated)
        waitForNotification(true)
        val notification = manager.activeNotifications.single { it.id == 804 }.notification
        assertTrue(notification.extras.getCharSequence("android.bigText").toString().contains("Updated groceries"))
        DailyReminders.replace(context, fixture().put("enabled", false).put("notifyNow", true))
        waitForNotification(false)
    }

}
