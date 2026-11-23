package chimin.remindme.steps.main_activity_screenshot

import chimin.remindme.*
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import chimin.remindme.support.ScreenshotFixture

class ScenarioContext : ScreenshotFixture() {
    var legacyService = false

    fun findWidgetTask(title: String): androidx.test.uiautomator.UiObject2 {
        // Home can return to the launcher's default page rather than the widget page.
        repeat(10) {
            val row = device.wait(Until.findObject(By.text(title)), 1000)
            if (row != null) {
                // Inline and service collections attach clicks to different ancestors.
                var task: androidx.test.uiautomator.UiObject2? = row
                while (task != null && !task.isClickable) task = task.parent
                if (task != null) return task
                Thread.sleep(100)
                return@repeat
            }
            device.swipe(device.displayWidth * 9 / 10, device.displayHeight * 2 / 3,
                device.displayWidth / 10, device.displayHeight * 2 / 3, 30)
        }
        error("Widget task was not visible: $title")
    }

    fun publishLegacyViews() {
        if (!legacyService) return
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, TaskWidgetProvider::class.java)
        instrumentation.runOnMainSync {
            for (id in manager.getAppWidgetIds(provider)) {
                manager.updateAppWidget(id, TaskWidgetProvider().buildViews(context, id, false))
                manager.notifyAppWidgetViewDataChanged(id, R.id.task_list)
            }
        }
        device.waitForIdle()
    }
}
