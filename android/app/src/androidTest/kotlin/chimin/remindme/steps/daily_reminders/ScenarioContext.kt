package chimin.remindme.steps.daily_reminders

import chimin.remindme.*
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.json.JSONObject
import org.junit.Assert.*
import java.util.Calendar
import java.util.TimeZone

class ScenarioContext {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context = instrumentation.targetContext
    val device = UiDevice.getInstance(instrumentation)
    val manager get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    var snapshotSaved = false
    var previousState: String? = null
    lateinit var now: Calendar
    lateinit var next: Calendar
    lateinit var snapshot: JSONObject
    lateinit var summary: Pair<String, List<String>>
    val occurrences = mutableListOf<Pair<Calendar, Calendar>>()
    lateinit var channel: android.app.NotificationChannel
    var disabledNotification = false
    val restoredAlarms = mutableListOf<Pair<Boolean, String>>()

    fun fixture(): JSONObject {
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

    fun waitForNotification(expected: Boolean) {
        repeat(50) {
            if (manager.activeNotifications.any { it.id == 804 } == expected) return
            Thread.sleep(100)
        }
        assertEquals(expected, manager.activeNotifications.any { it.id == 804 })
    }

    fun grantPermission() {
        if (Build.VERSION.SDK_INT >= 33) device.executeShellCommand("pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS")
    }

    fun date(zone: String, year: Int, month: Int, day: Int, hour: Int, minute: Int): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone(zone)).apply {
            clear(); set(year, month - 1, day, hour, minute, 0)
        }

}
