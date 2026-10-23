package chimin.remindme

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Implementation of the RemindMe home-screen widget.
 *
 * Reads the latest grouped task snapshot (serialized to JSON by [WidgetService]
 * in Dart and stored via `home_widget`'s shared `HomeWidgetPreferences`) and
 * renders it as a list of group headers and task rows.
 *
 * Each data item is either the task list title (`type: "tasklist"`, with a
 * `title`), a group header (`type: "header"`, with a `category` of
 * "today" / "overdue" / "noDueDate" / "future") or a task (`type: "task"`,
 * with a `title` and `completed` flag). Tapping the widget opens the app.
 *
 * `onUpdate` is intentionally defensive: any per-item or per-widget rendering
 * error is logged and skipped so the widget always loads (showing at least the
 * empty state) rather than reporting "can't load widget" to the launcher.
 */
class TaskWidgetProvider : AppWidgetProvider() {

  companion object {
    private const val TAG = "TaskWidgetProvider"
    const val DATA_KEY = "task_widget_data"
    const val CONFIG_KEY = "task_widget_config"
  }

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

  private fun loadColorConfig(prefs: SharedPreferences?): WidgetColorConfig {
    val defaults = WidgetColorConfig(
      textColor = 0xFF000000.toInt(),
      overdueColor = 0xFFF44336.toInt(),
      backgroundColor = 0x80FFFFFF.toInt(),
    )
    if (prefs == null) return defaults
    val raw = prefs.getString(CONFIG_KEY, null) ?: return defaults
    return try {
      val obj = JSONObject(raw)
      val text = obj.optInt("textColor", defaults.textColor)
      val overdue = obj.optInt("overdueColor", defaults.overdueColor)
      val bg = obj.optInt("backgroundColor", 0xFFFFFFFF.toInt())
      val alpha = obj.optInt("backgroundAlpha", 0x80)
      WidgetColorConfig(
        textColor = text,
        overdueColor = overdue,
        backgroundColor = (bg and 0x00FFFFFF) or ((alpha and 0xFF) shl 24),
      )
    } catch (e: JSONException) {
      Log.e(TAG, "Failed to parse widget color config, using defaults", e)
      defaults
    }
  }
  private fun loadItems(prefs: SharedPreferences): List<WidgetItem> {
    val raw = prefs.getString(DATA_KEY, null) ?: return emptyList()
    return try {
      val array = JSONArray(raw)
      val items = mutableListOf<WidgetItem>()
      for (i in 0 until array.length()) {
        val obj: JSONObject = array.getJSONObject(i)
        when (obj.optString("type", "")) {
          "tasklist" -> items.add(
            WidgetItem(
              type = "tasklist",
              title = obj.optString("title", ""),
              completed = false,
              category = "",
            ),
          )
          "header" -> items.add(
            WidgetItem(
              type = "header",
              title = obj.optString("title", ""),
              completed = false,
              category = obj.optString("category", ""),
            ),
          )
          "task" -> {
            // The widget only shows outstanding items; completed tasks are
            // skipped even if the stored snapshot still contains them.
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
      items
    } catch (e: JSONException) {
      Log.e(TAG, "Failed to parse widget data, showing empty", e)
      emptyList()
    }
  }

  private fun openAppIntent(context: Context): PendingIntent {
    val intent = Intent(context, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
    }
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    } else {
      PendingIntent.FLAG_UPDATE_CURRENT
    }
    return PendingIntent.getActivity(context, 0, intent, flags)
  }

  private fun buildItemViews(
    context: Context,
    item: WidgetItem,
    pending: PendingIntent?,
    colorConfig: WidgetColorConfig,
  ): RemoteViews {
    val pkg = context.packageName
    return when (item.type) {
      "tasklist" -> RemoteViews(pkg, R.layout.task_widget_title).apply {
        setTextViewText(R.id.task_list_title, item.title)
        setInt(R.id.task_list_title, "setTextColor", colorConfig.textColor)
        setInt(R.id.task_list_title, "setBackgroundColor", colorConfig.backgroundColor)
        if (pending != null) setOnClickPendingIntent(R.id.task_list_title, pending)
      }
      "header" -> RemoteViews(pkg, R.layout.task_widget_group).apply {
        setTextViewText(R.id.group_title, item.title)
        setInt(
          R.id.group_title,
          "setTextColor",
          if (item.category == "overdue") {
            colorConfig.overdueColor
          } else {
            colorConfig.textColor
          },
        )
        if (pending != null) setOnClickPendingIntent(R.id.group_title, pending)
        setInt(R.id.group_title, "setBackgroundColor", colorConfig.backgroundColor)
      }
      else -> RemoteViews(pkg, R.layout.task_widget_item).apply {
        setTextViewText(R.id.title, item.title)
        setTextViewText(
          R.id.checkbox,
          if (item.completed) "\u2713" else "\u25CB",
        )
        setInt(R.id.checkbox, "setTextColor", colorConfig.textColor)
        if (item.completed) {
          setInt(
            R.id.title,
            "setTextColor",
            ContextCompat.getColor(context, R.color.widget_task_completed),
          )
        } else {
          setInt(R.id.title, "setTextColor", colorConfig.textColor)
        }
        setInt(R.id.task_item_root, "setBackgroundColor", colorConfig.backgroundColor)
        if (pending != null) setOnClickPendingIntent(R.id.task_item_root, pending)
      }
    }
  }

  private fun buildBaseViews(context: Context, pending: PendingIntent?, colorConfig: WidgetColorConfig): RemoteViews {
    return RemoteViews(context.packageName, R.layout.task_widget).apply {
      if (pending != null) {
        setOnClickPendingIntent(R.id.widget_root, pending)
        setOnClickPendingIntent(R.id.empty_view, pending)
      }
      setInt(R.id.empty_view, "setTextColor", colorConfig.textColor)
      setInt(R.id.empty_view, "setBackgroundColor", colorConfig.backgroundColor)
      setViewVisibility(R.id.empty_view, View.VISIBLE)
    }
  }

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
  ) {
    val prefs = try {
      HomeWidgetPlugin.getData(context)
    } catch (e: Exception) {
      Log.e(TAG, "HomeWidgetPlugin.getData failed", e)
      null
    }
    val items = if (prefs != null) loadItems(prefs) else emptyList()
    val colorConfig = loadColorConfig(prefs)
    val hasTasks = items.any { it.type == "task" }
    val pending = try {
      openAppIntent(context)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to create open-app PendingIntent", e)
      null
    }

    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.task_widget)
      try {
        views.removeAllViews(R.id.container)
        for (item in items) {
          try {
            views.addView(R.id.container, buildItemViews(context, item, pending, colorConfig))
          } catch (e: Exception) {
            Log.e(TAG, "Failed to render item '${item.title}', skipping", e)
          }
        }
        views.setViewVisibility(
          R.id.empty_view,
          if (hasTasks) View.GONE else View.VISIBLE,
        )
        views.setInt(R.id.empty_view, "setTextColor", colorConfig.textColor)
        views.setInt(R.id.empty_view, "setBackgroundColor", colorConfig.backgroundColor)
        if (pending != null) {
          views.setOnClickPendingIntent(R.id.widget_root, pending)
          views.setOnClickPendingIntent(R.id.empty_view, pending)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (e: Exception) {
        Log.e(TAG, "Failed to update widget $widgetId, rendering fallback", e)
        val fallback = buildBaseViews(context, pending, colorConfig)
        appWidgetManager.updateAppWidget(widgetId, fallback)
      }
    }
  }
}
