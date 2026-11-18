package chimin.remindme

import android.content.Context
import android.appwidget.AppWidgetHostView
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import android.widget.ImageView
import android.widget.ListView
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@SdkSuppress(minSdkVersion = 31)
class TaskWidgetProviderTest {
  private val instrumentation = InstrumentationRegistry.getInstrumentation()
  private val context: Context = instrumentation.targetContext

  private fun withPreferences(block: () -> Unit) {
    val prefs = HomeWidgetPlugin.getData(context)
    val data = prefs.getString(TaskWidgetProvider.DATA_KEY, null)
    val config = prefs.getString(TaskWidgetProvider.CONFIG_KEY, null)
    try {
      block()
    } finally {
      prefs.edit().putString(TaskWidgetProvider.DATA_KEY, data)
        .putString(TaskWidgetProvider.CONFIG_KEY, config).commit()
    }
  }

  private fun saveColors(text: Int, overdue: Int, background: Int, alpha: Int) {
    HomeWidgetPlugin.getData(context).edit().putString(
      TaskWidgetProvider.CONFIG_KEY,
      JSONObject().put("textColor", text.toLong() and 0xFFFFFFFFL)
        .put("overdueColor", overdue.toLong() and 0xFFFFFFFFL)
        .put("backgroundColor", background.toLong() and 0xFFFFFFFFL)
        .put("backgroundAlpha", alpha).toString(),
    ).commit()
  }

  private fun assertColors(view: View, text: Int, overdue: Int, background: Int, alpha: Int) {
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

  @Test
  fun saveAppearanceShouldUpdateAllColorsWhenExistingViewsAreReapplied() = withPreferences {
    HomeWidgetPlugin.getData(context).edit().putString(TaskWidgetProvider.DATA_KEY, """
      [{"type":"tasklist","title":"Tasks"},
       {"type":"header","title":"Overdue","category":"overdue"},
       {"type":"task","title":"Open task","completed":false},
       {"type":"task","title":"Finished task","completed":true},
       {"type":"header","title":"Today","category":"today"}]
    """.trimIndent()).commit()
    instrumentation.runOnMainSync {
      val provider = TaskWidgetProvider()
      val parent = AppWidgetHostView(context)
      saveColors(Color.BLACK, Color.RED, Color.WHITE, 242)
      val first = provider.buildViews(context, 101).apply(context, parent)
      val second = provider.buildViews(context, 102).apply(context, parent)
      parent.addView(first)
      parent.addView(second)
      assertColors(first, Color.BLACK, Color.RED, Color.WHITE, 242)
      for ((text, overdue, bg, alpha) in listOf(
        listOf(Color.WHITE, Color.YELLOW, Color.DKGRAY, 216),
        listOf(Color.GREEN, Color.BLUE, Color.BLACK, 128),
      )) {
        saveColors(text, overdue, bg, alpha)
        provider.buildViews(context, 101).reapply(context, first)
        provider.buildViews(context, 102).reapply(context, second)
        assertColors(first, text, overdue, bg, alpha)
        assertColors(second, text, overdue, bg, alpha)
      }
      first.measure(View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.EXACTLY))
      first.layout(0, 0, 600, 800)
      ScreenshotCapture.captureScreenshot("task_widget/task_widget_when_appearance_is_updated.png",
        ScreenshotCapture.renderToBitmap(first), context)
    }
  }

  @Test
  fun saveAppearanceShouldUpdateEmptyStateWhenNoTasksRemain() = withPreferences {
    instrumentation.runOnMainSync {
      val provider = TaskWidgetProvider()
      HomeWidgetPlugin.getData(context).edit().putString(TaskWidgetProvider.DATA_KEY, "[]").commit()
      saveColors(Color.WHITE, Color.RED, Color.BLACK, 0)
      val view = provider.buildViews(context, 101).apply(context, AppWidgetHostView(context))
      assertEquals(View.VISIBLE, view.findViewById<View>(R.id.empty_view).visibility)
      assertEquals(Color.WHITE, view.findViewById<TextView>(R.id.empty_view).currentTextColor)
      assertEquals(0, view.findViewById<ImageView>(R.id.widget_background).imageAlpha)
      assertEquals(0, view.findViewById<ListView>(R.id.task_list).adapter.count)
    }
  }

  @Test
  fun buildViewsShouldShowMatchingCategoryLabelsWhenTasksSpanDates() = withPreferences {
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
    instrumentation.runOnMainSync {
      val view = TaskWidgetProvider().buildViews(context, 101)
        .apply(context, AppWidgetHostView(context))
      val list = view.findViewById<ListView>(R.id.task_list)
      val expected = listOf("Overdue", "No due date", "Today", "Tomorrow", "Sat, Jan 2, 2027")
      assertEquals(10, list.adapter.count)
      expected.forEachIndexed { index, title ->
        val header = list.adapter.getView(index * 2, null, list)
        assertEquals(title, header.findViewById<TextView>(R.id.group_title).text.toString())
      }
      view.measure(View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY))
      view.layout(0, 0, 600, 1000)
      ScreenshotCapture.captureScreenshot("task_widget/task_widget_when_categories_are_shown.png",
        ScreenshotCapture.renderToBitmap(view), context)
    }
  }


  @Test
  fun taskFillInIntentShouldPreserveIdentityWhenIdsContainReservedCharacters() {
    val uri = TaskWidgetProvider.taskFillInIntent("list /+?&", "task /+?&").data!!
    assertEquals("remindme", uri.scheme)
    assertEquals("task", uri.host)
    assertEquals("/edit", uri.path)
    assertEquals("list /+?&", uri.getQueryParameter("taskListId"))
    assertEquals("task /+?&", uri.getQueryParameter("taskId"))
    assertNotEquals(uri, TaskWidgetProvider.taskFillInIntent("other", "task /+?&").data)
  }

  @Test
  fun taskFillInIntentShouldOpenHomeWhenLegacyPayloadLacksIdentity() {
    for ((list, task) in listOf(null to null, "list" to null, null to "task", "" to "task")) {
      assertEquals("remindme://home", TaskWidgetProvider.taskFillInIntent(list, task).data.toString())
    }
  }

}
