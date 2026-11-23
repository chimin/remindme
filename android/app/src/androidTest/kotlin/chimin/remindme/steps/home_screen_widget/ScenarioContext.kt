package chimin.remindme.steps.home_screen_widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.Color
import chimin.remindme.TaskWidgetProvider
import chimin.remindme.support.ScreenshotFixture
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class ScenarioContext : ScreenshotFixture() {
    val prefs get() = HomeWidgetPlugin.getData(context)
    var previousData: String? = null
    var previousConfig: String? = null
    var snapshotSaved = false
    var screenshotName = "home_screen_widget_when_four_dated_tasks_exist"

    fun rememberPreferences() {
        previousData = prefs.getString(TaskWidgetProvider.DATA_KEY, null)
        previousConfig = prefs.getString(TaskWidgetProvider.CONFIG_KEY, null)
        snapshotSaved = true
        finishFixtureActivities()
        prefs.edit().remove(TaskWidgetProvider.CONFIG_KEY).commit()
    }

    fun restorePreferences() {
        if (!snapshotSaved) return
        finishFixtureActivities()
        prefs.edit().putString(TaskWidgetProvider.DATA_KEY, previousData)
            .putString(TaskWidgetProvider.CONFIG_KEY, previousConfig).commit()
        refreshWidget()
    }

    fun refreshWidget() {
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, TaskWidgetProvider::class.java)
        instrumentation.runOnMainSync {
            TaskWidgetProvider().onUpdate(context, manager, manager.getAppWidgetIds(provider))
        }
        device.waitForIdle()
    }

    fun saveAppearance() {
        prefs.edit().putString(TaskWidgetProvider.CONFIG_KEY,
            JSONObject().put("textColor", Color.WHITE.toLong() and 0xFFFFFFFFL)
                .put("overdueColor", Color.YELLOW.toLong() and 0xFFFFFFFFL)
                .put("backgroundColor", Color.DKGRAY.toLong() and 0xFFFFFFFFL)
                .put("backgroundAlpha", 216).toString()).commit()
    }

    fun saveCategories() {
        HomeWidgetPlugin.getData(context).edit()
          .remove(TaskWidgetProvider.CONFIG_KEY)
          .putString(TaskWidgetProvider.DATA_KEY, """
            [{"type":"tasklist","title":"Tasks"},
             {"type":"header","title":"Overdue","category":"overdue"},
             {"type":"task","title":"Pay invoice","completed":false},
             {"type":"header","title":"No due date","category":"noDueDate"},
             {"type":"task","title":"Organize notes","completed":false},
             {"type":"header","title":"Today","category":"today"},
             {"type":"task","title":"Send report","completed":false},
             {"type":"header","title":"Tomorrow","category":"future"},
             {"type":"task","title":"Collect parcel","completed":false},
             {"type":"header","title":"Sat, Jan 2, 2027","category":"future"},
             {"type":"task","title":"Call the dentist","completed":false}]
          """.trimIndent()).commit()
    }

    fun captureWidget(failed: Boolean = false) {
        capture("home_screen_widget/${screenshotName}${if (failed) "_FAILED" else ""}.png")
    }
}
