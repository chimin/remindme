package chimin.remindme

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import java.io.File
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HomeScreenWidgetTest {

    private val context: Context =
        InstrumentationRegistry.getInstrumentation().targetContext
    private val device: UiDevice = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    @Test
    fun taskWidgetShouldBePinnedToHomeScreen() {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val provider = ComponentName(context.packageName, TaskWidgetProvider::class.java.name)

        // Request pinning which triggers a confirmation dialog
        appWidgetManager.requestPinAppWidget(provider, null, null)

        // Confirm the widget by clicking "Add to home screen" button
        confirmWidgetPin()

        // Dismiss the "Touch & hold" hint overlay if present
        dismissTouchAndHoldHint()

        // Wait for widget to render
        Thread.sleep(2000)

        context.sendBroadcast(
            android.content.Intent("android.appwidget.action.APPWIDGET_UPDATE").apply {
                setPackage("chimin.remindme")
            }
        )

        // Wait for widget to update
        Thread.sleep(3000)

        // Capture home screen screenshot
        captureHomeScreenScreenshot()
    }

    private fun confirmWidgetPin() {
        var attempts = 0
        while (attempts < 10) {
            device.waitForIdle(1000)
            val addButton = device.findObject(By.text("Add to home screen"))
            if (addButton != null) {
                Log.d("HomeScreenWidgetTest", "Clicking 'Add to home screen' to pin widget")
                addButton.click()
                device.waitForIdle(2000)
                return
            }
            Thread.sleep(500)
            attempts++
        }
        Log.w("HomeScreenWidgetTest", "No 'Add to home screen' button found after 10 attempts")
    }

    private fun dismissTouchAndHoldHint() {
        try {
            device.waitForIdle(1000)
            val hint = device.findObject(By.textContains("touch and hold"))
            if (hint != null) {
                Log.d("HomeScreenWidgetTest", "Dismissing 'touch and hold' hint")
                device.pressKeyCode(4) // Back button to dismiss hint
                device.waitForIdle(1000)
            }
        } catch (e: Exception) {
            Log.d("HomeScreenWidgetTest", "No hint dialog found to dismiss: ${e.message}")
        }
    }

    private fun captureHomeScreenScreenshot() {
        val outFile = File("/sdcard/Pictures/home_screen_widget.png")
        outFile.parentFile?.mkdirs()
        val success = device.takeScreenshot(outFile, 100f, 2) // 100f = quality, 2 = PNG format
        if (success) {
            Log.d("HomeScreenWidgetTest", "Home screen screenshot saved to ${outFile.absolutePath}")
        } else {
            throw AssertionError("Failed to capture home screen screenshot")
        }
    }
}