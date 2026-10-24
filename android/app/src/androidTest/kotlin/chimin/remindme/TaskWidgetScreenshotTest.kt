package chimin.remindme

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONArray

@RunWith(AndroidJUnit4::class)
class TaskWidgetScreenshotTest {

    private fun renderView(view: View, w: Int, h: Int): android.graphics.Bitmap {
        val wSpec = View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY)
        val hSpec = View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY)
        view.measure(wSpec, hSpec)
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        return ScreenshotCapture.renderToBitmap(view)
    }

    private fun inflateListItem(context: android.content.Context, type: String): View {
        return when (type) {
            "tasklist" -> LayoutInflater.from(context).inflate(R.layout.task_widget_title, null, false)
            "header" -> LayoutInflater.from(context).inflate(R.layout.task_widget_group, null, false)
            else -> LayoutInflater.from(context).inflate(R.layout.task_widget_item, null, false)
        }
    }

    @Test
    fun captureEmptyStateWidgetScreenshot() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val view = LayoutInflater.from(context).inflate(R.layout.task_widget, null, false)
        val bitmap = renderView(view, 400, 600)
        ScreenshotCapture.captureScreenshot("task_widget_empty_state.png", bitmap, context)
    }

    @Test
    fun capturePopulatedWidgetScreenshot() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val view = LayoutInflater.from(context).inflate(R.layout.task_widget, null, false)
        val listView = view.findViewById<ListView>(R.id.task_list)

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

        val adapterData = mutableListOf<Map<String, Any>>()
        val adapter = object : android.widget.BaseAdapter() {
            override fun getCount(): Int = adapterData.size
            private val data = adapterData
            override fun getItem(position: Int): Any = data[position]
            override fun getItemId(position: Int): Long = position.toLong()
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val item = data[position]
                val type = item["type"] as String
                val itemTitle = item["title"] as String
                val category = item["category"] as String
                val completed = item["completed"] as Boolean

                val v = inflateListItem(context, type)
                when (type) {
                    "tasklist" -> {
                        v.findViewById<TextView>(R.id.task_list_title).text = itemTitle
                    }
                    "header" -> {
                        val title = v.findViewById<TextView>(R.id.group_title)
                        title.text = itemTitle
                        if (category == "overdue") {
                            title.setTextColor(0xFFF44336.toInt())
                        }
                    }
                    "task" -> {
                        val title = v.findViewById<TextView>(R.id.title)
                        val checkbox = v.findViewById<TextView>(R.id.checkbox)
                        title.text = itemTitle
                        checkbox.text = if (completed) "\u2714" else "\u25A1"
                    }
                }
                return v
            }
        }

        for (i in 0 until payload.length()) {
            val obj = payload.getJSONObject(i)
            adapterData.add(mapOf(
                "type" to obj.getString("type"),
                "title" to obj.getString("title"),
                "category" to obj.optString("category", ""),
                "completed" to obj.optBoolean("completed", false),
            ))
        }
        listView.adapter = adapter

        val emptyView = view.findViewById<View>(R.id.empty_view)
        emptyView.visibility = View.GONE

        val bitmap = renderView(view, 400, 600)
        ScreenshotCapture.captureScreenshot("task_widget_populated.png", bitmap, context)
    }
}
