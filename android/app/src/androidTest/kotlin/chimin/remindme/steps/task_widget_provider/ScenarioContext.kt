package chimin.remindme.steps.task_widget_provider

import chimin.remindme.*
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import androidx.test.platform.app.InstrumentationRegistry
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import org.junit.Assert.*

class ScenarioContext {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val context: Context = instrumentation.targetContext
    val prefs get() = HomeWidgetPlugin.getData(context)
    var snapshotSaved = false
    var previousData: String? = null
    var previousConfig: String? = null
    lateinit var view: View
    lateinit var first: View
    lateinit var second: View
    var expectedColors = emptyList<Int>()
    var taskListId = ""
    var taskId = ""
    lateinit var uri: android.net.Uri
    val fallbackUris = mutableListOf<String>()

    fun saveColors(text: Int, overdue: Int, background: Int, alpha: Int) {
        HomeWidgetPlugin.getData(context).edit().putString(
          TaskWidgetProvider.CONFIG_KEY,
          JSONObject().put("textColor", text.toLong() and 0xFFFFFFFFL)
            .put("overdueColor", overdue.toLong() and 0xFFFFFFFFL)
            .put("backgroundColor", background.toLong() and 0xFFFFFFFFL)
            .put("backgroundAlpha", alpha).toString(),
        ).commit()
    }

    fun assertColors(view: View, text: Int, overdue: Int, background: Int, alpha: Int) {
        assertEquals(text, view.findViewById<TextView>(R.id.task_list_title).currentTextColor)
        assertEquals(text, view.findViewById<TextView>(R.id.empty_view).currentTextColor)
        for (id in listOf(R.id.widget_title_background, R.id.widget_background)) {
          val image = view.findViewById<ImageView>(id)
          assertEquals(alpha, image.imageAlpha)
          val bitmap = Bitmap.createBitmap(80, 80, Bitmap.Config.ARGB_8888)
          image.drawable.setBounds(0, 0, 80, 80)
          image.drawable.draw(Canvas(bitmap))
          val pixel = bitmap.getPixel(40, 40)
          // ARGB_8888 round-trips through premultiplied alpha when drawn.
          for (shift in listOf(0, 8, 16)) {
            assertTrue(kotlin.math.abs(((background ushr shift) and 255) -
              ((pixel ushr shift) and 255)) <= 1)
          }
          assertEquals(alpha, Color.alpha(pixel))
        }
        val list = view.findViewById<ListView>(R.id.task_list)
        val adapter = list.adapter
        assertEquals(3, adapter.count)
        val header = adapter.getView(0, null, list)
        assertEquals(overdue, header.findViewById<TextView>(R.id.group_title).currentTextColor)
        val task = adapter.getView(1, null, list)
        assertEquals("Open task", task.findViewById<TextView>(R.id.title).text.toString())
        assertEquals(text, task.findViewById<TextView>(R.id.title).currentTextColor)
        assertEquals(text, task.findViewById<TextView>(R.id.checkbox).currentTextColor)
        val today = adapter.getView(2, null, list)
        assertEquals(text, today.findViewById<TextView>(R.id.group_title).currentTextColor)
    }
}
