package chimin.remindme

import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONArray

/**
 * Captures two widget screenshot scenarios and pulls them into
 * android/app/test/screenshots via the screenshotTests Gradle task.
 *   - an empty task list (renders the empty-state view)
 *   - the populated task fixture used by the Flutter task_home_screen_test.dart
 */
@RunWith(AndroidJUnit4::class)
class TaskWidgetScreenshotTest {

    private fun renderView(view: View, w: Int, h: Int): android.graphics.Bitmap {
        val wSpec = View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY)
        val hSpec = View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY)
        view.measure(wSpec, hSpec)
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        return ScreenshotCapture.renderToBitmap(view)
    }

    @Test
    fun captureEmptyStateWidgetScreenshot() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val inflater = android.view.LayoutInflater.from(context)
        val view = inflater.inflate(R.layout.task_widget, null, false)
        val bitmap = renderView(view, 400, 600)
        ScreenshotCapture.captureScreenshot("task_widget_empty_state.png", bitmap, context)
    }

    @Test
    fun capturePopulatedWidgetScreenshot() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val inflater = android.view.LayoutInflater.from(context)
        val view = inflater.inflate(R.layout.task_widget, null, false)
        val container = view.findViewById<LinearLayout>(R.id.container)
        val emptyView = view.findViewById<View>(R.id.empty_view)

        val payload = JSONArray("""
            [
              {"type":"tasklist","title":"Tasks"},
              {"type":"header","title":"Overdue","category":"overdue"},
              {"type":"task","title":"Overdue task 1","completed":false},
              {"type":"task","title":"Overdue task 2","completed":false},
              {"type":"header","title":"No due date","category":"noDueDate"},
              {"type":"task","title":"Task without due date","completed":false},
              {"type":"header","title":"Today","category":"today"},
              {"type":"task","title":"Today task 1","completed":false},
              {"type":"task","title":"Today task 2","completed":true},
              {"type":"header","title":"2026-XX-XX","category":"future"},
              {"type":"task","title":"Future task 1","completed":false},
              {"type":"task","title":"Future task 2","completed":false}
            ]
        """.trimIndent())

        for (i in 0 until payload.length()) {
            val obj = payload.getJSONObject(i)
            when (obj.getString("type")) {
                "tasklist" -> {
                    val item = inflater.inflate(R.layout.task_widget_title, null, false)
                    item.findViewById<View>(R.id.task_list_title).let {
                        (it as TextView).text = obj.getString("title")
                    }
                    container.addView(item)
                }
                "header" -> {
                    val item = inflater.inflate(R.layout.task_widget_group, null, false)
                    val title = item.findViewById<View>(R.id.group_title) as TextView
                    title.text = obj.getString("title")
                    if (obj.getString("category") == "overdue") {
                        title.setTextColor(0xFFF44336.toInt())
                    }
                    container.addView(item)
                }
                "task" -> {
                    val item = inflater.inflate(R.layout.task_widget_item, null, false)
                    val title = item.findViewById<View>(R.id.title) as TextView
                    val checkbox = item.findViewById<View>(R.id.checkbox) as TextView
                    title.text = obj.getString("title")
                    checkbox.text = if (obj.getBoolean("completed")) "\u2713" else "\u25CB"
                    container.addView(item)
                }
            }
        }
        emptyView.visibility = View.GONE

        val bitmap = renderView(view, 400, 600)
        ScreenshotCapture.captureScreenshot("task_widget_populated.png", bitmap, context)
    }
}