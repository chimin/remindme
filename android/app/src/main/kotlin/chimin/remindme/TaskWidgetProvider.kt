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
 * Each data item is either a header (`type: "header"`, with a `category` of
 * "today" / "overdue" / "future") or a task (`type: "task"`, with a `title` and
 * `completed` flag). Tapping the widget opens the app.
 *
 * `onUpdate` is intentionally defensive: any per-item or per-widget rendering
 * error is logged and skipped so the widget always loads (showing at least the
 * empty state) rather than reporting "can't load widget" to the launcher.
 */
class TaskWidgetProvider : AppWidgetProvider() {

  companion object {
    private const val TAG = "TaskWidgetProvider"
    const val DATA_KEY = "task_widget_data"
  }

  private data class WidgetItem(
    val type: String,
    val title: String,
    val completed: Boolean,
    val category: String,
  )

  private fun loadItems(prefs: SharedPreferences): List<WidgetItem> {
    val raw = prefs.getString(DATA_KEY, null) ?: return emptyList()
    return try {
      val array = JSONArray(raw)
      val items = mutableListOf<WidgetItem>()
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
          "task" -> items.add(
            WidgetItem(
              type = "task",
              title = obj.optString("title", "(no title)"),
              completed = obj.optBoolean("completed", false),
              category = "",
            ),
          )
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

  private fun headerColor(context: Context, category: String): Int {
    return when (category) {
      "overdue" -> ContextCompat.getColor(context, R.color.widget_overdue)
      else -> ContextCompat.getColor(context, R.color.widget_group_header)
    }
  }

  private fun buildItemViews(
    context: Context,
    item: WidgetItem,
    pending: PendingIntent?,
  ): RemoteViews {
    val pkg = context.packageName
    return if (item.type == "header") {
      RemoteViews(pkg, R.layout.task_widget_group).apply {
        setTextViewText(R.id.group_title, item.title)
        setInt(R.id.group_title, "setTextColor", headerColor(context, item.category))
        if (pending != null) setOnClickPendingIntent(R.id.group_title, pending)
      }
    } else {
      RemoteViews(pkg, R.layout.task_widget_item).apply {
        setTextViewText(R.id.title, item.title)
        setTextViewText(
          R.id.checkbox,
          if (item.completed) "\u2713" else "\u25CB",
        )
        if (item.completed) {
          setInt(
            R.id.title,
            "setTextColor",
            ContextCompat.getColor(context, R.color.widget_task_completed),
          )
        }
        if (pending != null) setOnClickPendingIntent(R.id.task_item_root, pending)
      }
    }
  }

  private fun buildBaseViews(context: Context, pending: PendingIntent?): RemoteViews {
    return RemoteViews(context.packageName, R.layout.task_widget).apply {
      if (pending != null) {
        setOnClickPendingIntent(R.id.widget_root, pending)
        setOnClickPendingIntent(R.id.empty_view, pending)
      }
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
            views.addView(R.id.container, buildItemViews(context, item, pending))
          } catch (e: Exception) {
            Log.e(TAG, "Failed to render item '${item.title}', skipping", e)
          }
        }
        views.setViewVisibility(
          R.id.empty_view,
          if (items.isEmpty()) View.VISIBLE else View.GONE,
        )
        if (pending != null) {
          views.setOnClickPendingIntent(R.id.widget_root, pending)
          views.setOnClickPendingIntent(R.id.empty_view, pending)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (e: Exception) {
        Log.e(TAG, "Failed to update widget $widgetId, rendering fallback", e)
        val fallback = buildBaseViews(context, pending)
        appWidgetManager.updateAppWidget(widgetId, fallback)
      }
    }
  }
}
