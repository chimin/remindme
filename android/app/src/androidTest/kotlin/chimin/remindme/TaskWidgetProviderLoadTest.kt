package chimin.remindme

import android.content.Context
import android.content.SharedPreferences
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import es.antonborri.home_widget.HomeWidgetPlugin
import org.junit.Assert
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TaskWidgetProviderLoadTest {

    private fun seedPrefs(context: Context, json: String?) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        if (json == null) editor.remove(TaskWidgetProvider.DATA_KEY)
        else editor.putString(TaskWidgetProvider.DATA_KEY, json)
        editor.commit()
    }

    private fun invokeProvider(context: Context, json: String?) {
        seedPrefs(context, json)
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        TaskWidgetProvider().onUpdate(context, manager, intArrayOf(1))
    }

    @Test
    fun onUpdateShouldNotThrowWhenPrefsEmpty() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        invokeProvider(context, "[]")
    }

    @Test
    fun onUpdateShouldNotThrowWhenPrefsPopulated() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val payload = """
            [
              {"type":"tasklist","title":"My List"},
              {"type":"header","title":"Today","category":"today"},
              {"type":"task","title":"Buy milk","completed":false},
              {"type":"task","title":"Done task","completed":true}
            ]
        """.trimIndent()
        invokeProvider(context, payload)
    }

    @Test
    fun onUpdateShouldNotThrowWhenPrefsMissing() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        seedPrefs(context, null)
        val manager = android.appwidget.AppWidgetManager.getInstance(context)
        TaskWidgetProvider().onUpdate(context, manager, intArrayOf(1))
    }
}
