package chimin.remindme.support

import chimin.remindme.*
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.ParcelFileDescriptor
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import java.io.File
import java.util.regex.Pattern
import org.junit.Assert.assertTrue

open class ScreenshotFixture {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context = instrumentation.targetContext
    val device = UiDevice.getInstance(instrumentation)
    val timeout = 20_000L

    fun taskSelector(title: String) =
        By.desc(Pattern.compile("(?s).*" + Pattern.quote(title) + ".*"))

    fun launchFixture() {
        device.wakeUp()
        device.executeShellCommand("wm dismiss-keyguard")
        device.executeShellCommand("am start -W -a es.antonborri.home_widget.action.LAUNCH -d remindme://home -n " + context.packageName + "/.MainActivity")
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

    fun capture(name: String) {
        device.waitForIdle()
        val directory = File(context.getExternalFilesDir("test_output"), "golden")
        val outFile = File(directory, name)
        check(outFile.parentFile!!.isDirectory || outFile.parentFile!!.mkdirs())
        val signature = byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10)
        // Read screencap directly; UiAutomation bitmap capture can stop returning frames.
        repeat(3) {
            val descriptor = instrumentation.uiAutomation.executeShellCommand("screencap -p")
            val png = ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
            if (png.size > signature.size && png.copyOfRange(0, signature.size).contentEquals(signature)) {
                outFile.writeBytes(png)
                return
            }
            device.waitForIdle()
        }
        throw AssertionError("Screenshot failed: $name")
    }

    fun pinWidget(requestNew: Boolean = false) {
        val manager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context, TaskWidgetProvider::class.java)
        assertTrue("Launcher must support pinning widgets", manager.isRequestPinAppWidgetSupported)
        if (requestNew || manager.getAppWidgetIds(provider).isEmpty()) {
            instrumentation.runOnMainSync {
                assertTrue(manager.requestPinAppWidget(provider, null, null))
            }
            val confirm = device.wait(Until.findObject(By.text(
                java.util.regex.Pattern.compile("(?i)add( to home screen)?"))), timeout)
            checkNotNull(confirm) { "Widget pin confirmation did not appear; use an English emulator" }
            confirm.click()
            device.waitForIdle()
            if (device.hasObject(By.text(Pattern.compile("(?i).*touch.*hold.*")))) device.pressBack()
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
        val bottom = device.wait(Until.findObject(By.res(Pattern.compile(".*:id/widget_resize_bottom_handle"))), 3000)
        if (bottom != null) {
            val point = bottom.visibleCenter
            device.drag(point.x, point.y, point.x, device.displayHeight * 2 / 3, 60)
            device.pressBack()
        } else {
            device.pressBack()
        }
    }

    fun verifyWidget() {
        for (title in listOf("Renew library books", "Pick up groceries",
                "Plan weekend trip", "Book dentist appointment")) {
            assertTrue("Widget must show all four tasks; resize it taller: $title",
                device.wait(Until.hasObject(By.text(title)), timeout))
        }
    }

    fun finishFixtureActivities() {
        // Destroy the Flutter activity/engine without killing instrumentation.
        instrumentation.runOnMainSync {
            val monitor = ActivityLifecycleMonitorRegistry.getInstance()
            listOf(Stage.RESUMED, Stage.STARTED, Stage.STOPPED, Stage.PAUSED, Stage.CREATED)
                .flatMap { monitor.getActivitiesInStage(it).toList() }
                .distinct().filterIsInstance<MainActivity>().forEach { it.finish() }
        }
        instrumentation.waitForIdleSync()
    }
}
