package chimin.remindme.reminders

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Calendar

class DailyRemindersPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "chimin.remindme/reminders")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "replace" -> DailyReminders.replace(context, JSONObject(call.arguments as Map<*, *>))
                "requestPermission" -> {
                    DailyReminders.createChannel(context)
                    val foreground = activity
                    if (Build.VERSION.SDK_INT >= 33 && foreground != null &&
                        foreground.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        val prefs = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE)
                        if (!prefs.getBoolean("permission_requested", false)) {
                            prefs.edit().putBoolean("permission_requested", true).apply()
                            foreground.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 804)
                        }
                    }
                }
                "openChannelSettings" -> {
                    DailyReminders.createChannel(context)
                    val intent = if (Build.VERSION.SDK_INT >= 26) {
                        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            .putExtra(Settings.EXTRA_CHANNEL_ID, DailyReminders.CHANNEL)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.parse("package:${context.packageName}"))
                    }
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                else -> { result.notImplemented(); return }
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("reminders", error.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null) }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener { intent ->
            if (intent.getBooleanExtra("dailyReminder", false)) channel.invokeMethod("openHome", null)
            false
        }
    }
    override fun onDetachedFromActivity() { activity = null }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
}

object DailyReminders {
    const val CHANNEL = "daily_task_reminders"
    private const val ID = 804
    private const val ACTION = "chimin.remindme.DAILY_REMINDER"

    private fun manager(context: Context) = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private fun alarm(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun pending(context: Context) = PendingIntent.getBroadcast(context, ID,
        Intent(context, DailyReminderReceiver::class.java).setAction(ACTION),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun prefs(context: Context) = context.getSharedPreferences("daily_reminders", Context.MODE_PRIVATE)
    private fun state(context: Context) = JSONObject(prefs(context).getString("state", "{}") ?: "{}")

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Daily task reminders", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Daily summary of overdue and today tasks"
            channel.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            channel.enableVibration(true)
            channel.enableLights(true)
            manager(context).createNotificationChannel(channel)
        }
    }

    @Synchronized fun replace(context: Context, state: JSONObject) {
        val notifyNow = state.optBoolean("notifyNow")
        state.remove("notifyNow")
        // Commit the snapshot before returning to Dart or scheduling an alarm.
        if (!prefs(context).edit().putString("state", state.toString()).commit()) {
            throw IllegalStateException("Unable to save reminder snapshot")
        }
        reconcile(context)
        val displayed = Build.VERSION.SDK_INT >= 23 && manager(context).activeNotifications.any { it.id == ID }
        if (notifyNow || displayed) post(context, state, onlyAlertOnce = !notifyNow)
    }

    fun nextOccurrence(now: Calendar, hour: Int, minute: Int, tomorrow: Boolean = false): Calendar {
        val next = now.clone() as Calendar
        next.set(Calendar.HOUR_OF_DAY, hour)
        next.set(Calendar.MINUTE, minute)
        next.set(Calendar.SECOND, 0)
        next.set(Calendar.MILLISECOND, 0)
        if (tomorrow || next.timeInMillis <= now.timeInMillis) {
            next.timeInMillis = now.timeInMillis
            next.add(Calendar.DAY_OF_MONTH, 1)
            next.set(Calendar.HOUR_OF_DAY, hour)
            next.set(Calendar.MINUTE, minute)
            next.set(Calendar.SECOND, 0)
            next.set(Calendar.MILLISECOND, 0)
        }
        return next
    }

    @Synchronized fun reconcile(context: Context, tomorrow: Boolean = false) {
        val state = state(context)
        alarm(context).cancel(pending(context))
        if (!state.optBoolean("active") || !state.optBoolean("enabled")) {
            manager(context).cancel(ID)
            return
        }
        createChannel(context)
        val next = nextOccurrence(Calendar.getInstance(), state.optInt("hour", 8), state.optInt("minute", 0), tomorrow)
        alarm(context).set(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending(context))
    }

    fun summary(state: JSONObject, today: Calendar): Pair<String, List<String>> {
        val day = today.get(Calendar.YEAR) * 10000 + (today.get(Calendar.MONTH) + 1) * 100 + today.get(Calendar.DAY_OF_MONTH)
        var overdue = 0
        var dueToday = 0
        val titles = mutableListOf<String>()
        val tasks = state.optJSONArray("tasks")
        if (tasks != null) for (index in 0 until tasks.length()) {
            val task = tasks.optJSONObject(index) ?: continue
            if (task.optBoolean("completed") || task.optBoolean("deleted") || task.isNull("year")) continue
            val due = task.optInt("year") * 10000 + task.optInt("month") * 100 + task.optInt("day")
            if (due > day) continue
            if (due == day) dueToday++ else overdue++
            titles.add(task.optString("title", "(Untitled)"))
        }
        val counts = listOfNotNull(
            if (overdue > 0) "$overdue overdue" else null,
            if (dueToday > 0) "$dueToday today" else null,
        ).joinToString(" · ")
        return Pair(counts, titles)
    }

    private fun post(context: Context, state: JSONObject, onlyAlertOnce: Boolean = false) {
        if (!state.optBoolean("active") || !state.optBoolean("enabled")) return
        val (counts, titles) = summary(state, Calendar.getInstance())
        if (titles.isEmpty()) { manager(context).cancel(ID); return }
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        if (Build.VERSION.SDK_INT >= 24 && !manager(context).areNotificationsEnabled()) return
        createChannel(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        launch.putExtra("dailyReminder", true)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val tap = PendingIntent.getActivity(context, ID, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_reminder)
            .setContentTitle(counts)
            .setContentText(titles.joinToString(", ").take(4000))
            .setStyle(Notification.BigTextStyle().bigText(titles.joinToString("\n").take(20000)))
            .setContentIntent(tap).setAutoCancel(true).setOnlyAlertOnce(onlyAlertOnce)
            .setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < 26) builder.setDefaults(Notification.DEFAULT_ALL).setPriority(Notification.PRIORITY_HIGH)
        manager(context).notify(ID, builder.build())
    }

    @Synchronized fun receive(context: Context, action: String?) {
        try {
            if (action == ACTION) post(context, state(context))
        } finally {
            reconcile(context, tomorrow = action == ACTION)
        }
    }
}

class DailyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DailyReminders.receive(context, intent.action)
    }
}
