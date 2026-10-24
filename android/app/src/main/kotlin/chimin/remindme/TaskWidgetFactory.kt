package chimin.remindme

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

class TaskWidgetFactory(context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

  private val TAG = "TaskWidgetFactory"
  private val context: Context
  private val items = mutableListOf<WidgetItem>()

  private data class WidgetItem(
    val type: String,
    val title: String,
    val completed: Boolean,
    val category: String,
  )

  private data class WidgetColorConfig(
    val textColor: Int,
    val overdueColor: Int,
    val backgroundColor: Int,
  )

  private var colorConfig = WidgetColorConfig(
    textColor = 0xFF000000.toInt(),
    overdueColor = 0xFFF44336.toInt(),
    backgroundColor = 0x80FFFFFF.toInt(),
  )

  init {
    this.context = context
    loadColorConfig()
  }

  override fun onCreate() {
    loadItems()
  }

  private fun loadColorConfig() {
    val prefs = HomeWidgetPlugin.getData(context) ?: return
    val raw = prefs.getString("task_widget_config", null) ?: return
    try {
      val obj = JSONObject(raw)
      val text = obj.optInt("textColor", 0xFF000000.toInt())
      val overdue = obj.optInt("overdueColor", 0xFFF44336.toInt())
      val bg = obj.optInt("backgroundColor", 0xFFFFFFFF.toInt())
      val alpha = obj.optInt("backgroundAlpha", 0x80)
      colorConfig = WidgetColorConfig(
        textColor = text,
        overdueColor = overdue,
        backgroundColor = (bg and 0x00FFFFFF) or ((alpha and 0xFF) shl 24),
      )
    } catch (e: JSONException) {
      Log.e(TAG, "Failed to parse widget color config", e)
    }
  }

  override fun onDataSetChanged() {
    loadItems()
  }

  override fun onDestroy() {
    items.clear()
  }

  override fun getCount(): Int = items.size

  override fun getViewAt(position: Int): RemoteViews {
    val item = items[position]
    val views = RemoteViews(context.packageName, when (item.type) {
      "header" -> R.layout.task_widget_group
      else -> R.layout.task_widget_item
    })

    when (item.type) {
      "header" -> {
        views.setTextViewText(R.id.group_title, item.title)
        if (item.category == "overdue") {
          views.setInt(R.id.group_title, "setTextColor", colorConfig.overdueColor)
        } else {
          views.setInt(R.id.group_title, "setTextColor", colorConfig.textColor)
        }
        views.setInt(R.id.group_title, "setBackgroundColor", colorConfig.backgroundColor)
      }
      else -> {
        views.setTextViewText(R.id.title, item.title)
        views.setTextViewText(
          R.id.checkbox,
          if (item.completed) "\u2714" else "\u25A1",
        )
        views.setInt(R.id.checkbox, "setTextColor", colorConfig.textColor)
        views.setInt(R.id.title, "setTextColor", colorConfig.textColor)
        views.setInt(R.id.task_item_root, "setBackgroundColor", colorConfig.backgroundColor)
      }
    }
    return views
  }

  override fun getLoadingView(): RemoteViews? = null

  override fun getViewTypeCount(): Int = 2

  override fun getItemId(position: Int): Long = position.toLong()

  override fun hasStableIds(): Boolean = true

  private fun loadItems() {
    items.clear()
    val prefs = HomeWidgetPlugin.getData(context)
    val raw = prefs?.getString("task_widget_data", null) ?: return
    try {
      val array = JSONArray(raw)
      for (i in 0 until array.length()) {
        val obj: JSONObject = array.getJSONObject(i)
        when (obj.optString("type", "")) {
          "header" -> items.add(
            WidgetItem(
              type = "header",
              title = obj.optString("title", ""),
              completed = false,
              category = obj.optString("category", ""),
            ),
          )
          "task" -> {
            if (!obj.optBoolean("completed", false)) {
              items.add(
                WidgetItem(
                  type = "task",
                  title = obj.optString("title", "(no title)"),
                  completed = false,
                  category = "",
                ),
              )
            }
          }
        }
      }
    } catch (e: JSONException) {
      Log.e(TAG, "Failed to parse widget data", e)
    }
  }
}