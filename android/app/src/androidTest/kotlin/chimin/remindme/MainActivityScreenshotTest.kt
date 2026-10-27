package chimin.remindme

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import java.util.regex.Pattern
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Runs against the dedicated lib/main_screenshot.dart build, never a signed-in account. */
@RunWith(AndroidJUnit4::class)
class MainActivityScreenshotTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)
    private val timeout = 20_000L

    // Task rows merge title and date into a multiline accessibility label.
    private fun taskSelector(title: String) =
        By.desc(Pattern.compile("(?s).*" + Pattern.quote(title) + ".*"))

    private fun launchFixture() {
        device.wakeUp()
        device.executeShellCommand("wm dismiss-keyguard")
        device.executeShellCommand("am start -W -n " + context.packageName + "/.MainActivity")
        for (title in listOf("Renew library books", "Pick up groceries",
                "Plan weekend trip", "Book dentist appointment")) {
            var attempts = 0
            while (!device.wait(Until.hasObject(taskSelector(title)), 3000) && attempts++ < 4) {
                device.swipe(device.displayWidth / 2, device.displayHeight * 4 / 5,
                    device.displayWidth / 2, device.displayHeight / 3, 30)
            }
            assertTrue("Missing fixture task: $title", device.hasObject(taskSelector(title)))
        }
        repeat(3) {
            device.swipe(device.displayWidth / 2, device.displayHeight / 3,
                device.displayWidth / 2, device.displayHeight * 4 / 5, 30)
        }
        device.waitForIdle()
    }

    private fun capture(name: String) {
        device.waitForIdle()
        val directory = File(context.getExternalFilesDir("test_output"), "golden")
        check(directory.isDirectory || directory.mkdirs())
        assertTrue("Screenshot failed: $name", device.takeScreenshot(File(directory, name)))
    }

    @Test
    fun captureShouldShowTaskListingWhenFourDatedTasksExist() {
        launchFixture()
        capture("task_listing.png")
    }

    @Test
    fun captureShouldShowAddTaskWhenAddButtonIsTapped() {
        launchFixture()
        // Use the extended FAB's accessible action label.
        val add = device.wait(Until.findObject(By.desc("Add task")), timeout)
        checkNotNull(add) { "Add task button was not accessible" }
        add.click()
        assertTrue("Add task screen did not open",
            device.wait(Until.hasObject(By.descContains("New task")), timeout))
        device.pressBack() // Dismiss the autofocus keyboard for the store screenshot.
        assertTrue(device.wait(Until.hasObject(By.descContains("New task")), timeout))
        capture("add_task.png")
    }

    @Test
    fun captureShouldShowHomeWidgetWhenFourDatedTasksExist() {
        launchFixture()
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, TaskWidgetProvider::class.java)
        assertTrue("Launcher must support pinning widgets", manager.isRequestPinAppWidgetSupported)
        if (manager.getAppWidgetIds(provider).isEmpty()) {
            instrumentation.runOnMainSync {
                assertTrue(manager.requestPinAppWidget(provider, null, null))
            }
            val confirm = device.wait(Until.findObject(By.text(
                java.util.regex.Pattern.compile("(?i)add( to home screen)?"))), timeout)
            checkNotNull(confirm) { "Widget pin confirmation did not appear; use an English emulator" }
            confirm.click()
        }
        manager.notifyAppWidgetViewDataChanged(manager.getAppWidgetIds(provider), R.id.task_list)
        device.pressHome()
        // Existing widgets may be on a different launcher page.
        val widgetSelector = By.res(context.packageName, "task_list")
        var page = 0
        while (!device.wait(Until.hasObject(widgetSelector), 1500) && page++ < 10) {
            device.swipe(device.displayWidth * 9 / 10, device.displayHeight * 2 / 3,
                device.displayWidth / 10, device.displayHeight * 2 / 3, 30)
        }
        val widget = device.findObject(By.res(context.packageName, "widget_root"))
        checkNotNull(widget) { "Pinned widget was not found on the launcher pages" }
        assertTrue("Widget fixture did not render",
            device.wait(Until.hasObject(By.text("Renew library books")), timeout))
        // Launcher3 / Pixel Launcher expose resize handles after a long press.
        // Grow the real widget to show every task without scrolling.
        widget.longClick()
        val bottom = device.wait(Until.findObject(By.res(device.launcherPackageName,
            "widget_resize_bottom_handle")), 3000)
        if (bottom != null) {
            val point = bottom.visibleCenter
            device.drag(point.x, point.y, point.x, device.displayHeight * 2 / 3, 60)
            device.pressBack()
        } else {
            device.pressBack()
        }
        for (title in listOf("Renew library books", "Pick up groceries",
                "Plan weekend trip", "Book dentist appointment")) {
            assertTrue("Widget must show all four tasks; resize it taller: $title",
                device.wait(Until.hasObject(By.text(title)), timeout))
        }
        capture("home_screen_widget.png")
    }
}
