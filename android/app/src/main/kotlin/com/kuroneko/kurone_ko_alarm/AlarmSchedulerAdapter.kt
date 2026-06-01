package com.kuroneko.kurone_ko_alarm

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

private const val CHANNEL_NAME = "com.kuroneko.alarm/scheduler"
private const val PREFS_NAME = "kuroneko_alarm_scheduler"
private const val PREFS_ALARMS = "alarms"
private const val PREFS_OUTCOMES = "alarm_outcomes"
private const val SCHEDULE_MODE_ALARM_CLOCK = "alarmClock"
private const val SCHEDULE_MODE_EXACT_NOTIFICATION = "exactNotification"

data class ScheduledAlarm(
    val id: Int,
    val millis: Long,
    val channelId: String,
    val eventType: String,
    val scheduleMode: String,
    val title: String,
    val body: String,
    val purpose: String,
    val breakOrdinal: Int?,
    val ringUntilDismissed: Boolean,
    val autoStopMillis: Long,
    val showFullScreenAlarm: Boolean,
    val dismissAction: String,
    val prewarningId: Int?,
)

class AlarmSchedulerAdapter(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun schedule(alarm: ScheduledAlarm) {
        if (alarm.millis <= System.currentTimeMillis()) {
            cancel(alarm.id)
            stopRinging(alarm.id)
            return
        }
        ensureNotificationChannels()
        val pendingIntent = pendingIntentFor(alarm)
        if (alarm.scheduleMode == SCHEDULE_MODE_ALARM_CLOCK) {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(alarm.millis, showIntentFor(alarm.id)),
                pendingIntent,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                alarm.millis,
                pendingIntent,
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, alarm.millis, pendingIntent)
        }
        persist(alarm)
    }

    fun cancel(id: Int) {
        alarmManager.cancel(pendingIntentFor(id))
        remove(id)
    }

    fun rescheduleAllOnBoot() {
        val nowMillis = System.currentTimeMillis()
        pruneStaleAlarms(nowMillis)
        loadPersisted().filter { it.millis > nowMillis }.forEach(::schedule)
    }

    fun pruneStaleAlarms(nowMillis: Long) {
        val (stale, future) = loadPersisted().partition { it.millis <= nowMillis }
        stale.forEach { alarm ->
            alarmManager.cancel(pendingIntentFor(alarm.id))
            notificationManager.cancel(alarm.id)
            stopRinging(alarm.id)
        }
        prefs.edit().putString(PREFS_ALARMS, JSONArray(future.map(::toJson)).toString()).apply()
    }

    fun canScheduleExactAlarms(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
    }

    fun requestExactAlarmPermission(): Boolean {
        if (canScheduleExactAlarms()) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
        return canScheduleExactAlarms()
    }

    fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    fun requestNotificationPermission(): Boolean {
        if (hasNotificationPermission()) return true
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return hasNotificationPermission()
    }

    fun requestBatteryOptimizationExemption(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(context.packageName)) return true
        context.startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun recordOutcome(id: Int, status: String) {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = sp.getString(PREFS_OUTCOMES, "[]") ?: "[]"
        val json = JSONArray(raw)
        json.put(
            JSONObject()
                .put("id", id)
                .put("status", status)
                .put("atMillis", System.currentTimeMillis()),
        )
        sp.edit().putString(PREFS_OUTCOMES, json.toString()).apply()
    }

    fun syncAlarmOutcomes(): String {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = sp.getString(PREFS_OUTCOMES, "[]") ?: "[]"
        sp.edit().remove(PREFS_OUTCOMES).apply()
        return raw
    }

    fun hasFullScreenIntentPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            context.checkSelfPermission(Manifest.permission.USE_FULL_SCREEN_INTENT) == PackageManager.PERMISSION_GRANTED
    }

    fun requestFullScreenIntentPermission(): Boolean {
        if (hasFullScreenIntentPermission()) return true
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return hasFullScreenIntentPermission()
    }

    private fun pendingIntentFor(alarm: ScheduledAlarm): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", alarm.id)
            putExtra("channelId", alarm.channelId)
            putExtra("eventType", alarm.eventType)
            putExtra("title", alarm.title)
            putExtra("body", alarm.body)
            putExtra("purpose", alarm.purpose)
            alarm.breakOrdinal?.let { putExtra("breakOrdinal", it) }
            putExtra("ringUntilDismissed", alarm.ringUntilDismissed)
            putExtra("autoStopMillis", alarm.autoStopMillis)
            putExtra("showFullScreenAlarm", alarm.showFullScreenAlarm)
            putExtra("dismissAction", alarm.dismissAction)
            alarm.prewarningId?.let { putExtra("prewarningId", it) }
        }
        return PendingIntent.getBroadcast(
            context,
            alarm.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun showIntentFor(id: Int): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context,
            id,
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pendingIntentFor(id: Int): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopRinging(id: Int) {
        context.stopService(
            Intent(context, AlarmRingingService::class.java).apply {
                action = AlarmContract.ACTION_STOP_RINGING
                putExtra("id", id)
            },
        )
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager.createNotificationChannel(
            NotificationChannel(
                "break_alarms",
                "Break alarms",
                NotificationManager.IMPORTANCE_MAX,
            ).apply {
                description = "Main break alarm notifications"
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    alarmAudioAttributes(),
                )
            },
        )
        notificationManager.createNotificationChannel(
            NotificationChannel(
                "pre_break_warnings",
                "Pre-break warnings",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "One-minute pre-warning notifications"
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    notificationAudioAttributes(),
                )
            },
        )
    }

    private fun alarmAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
    }

    private fun notificationAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
    }

    private fun persist(alarm: ScheduledAlarm) {
        val alarms = loadPersisted().filterNot { it.id == alarm.id } + alarm
        prefs.edit().putString(PREFS_ALARMS, JSONArray(alarms.map(::toJson)).toString()).apply()
    }

    private fun remove(id: Int) {
        val alarms = loadPersisted().filterNot { it.id == id }
        prefs.edit().putString(PREFS_ALARMS, JSONArray(alarms.map(::toJson)).toString()).apply()
    }

    private fun loadPersisted(): List<ScheduledAlarm> {
        val raw = prefs.getString(PREFS_ALARMS, "[]") ?: "[]"
        val json = JSONArray(raw)
        return (0 until json.length()).map { index -> fromJson(json.getJSONObject(index)) }
    }

    private fun toJson(alarm: ScheduledAlarm): JSONObject {
        return JSONObject()
            .put("id", alarm.id)
            .put("millis", alarm.millis)
            .put("channelId", alarm.channelId)
            .put("eventType", alarm.eventType)
            .put("scheduleMode", alarm.scheduleMode)
            .put("title", alarm.title)
            .put("body", alarm.body)
            .put("purpose", alarm.purpose)
            .put("breakOrdinal", alarm.breakOrdinal)
            .put("ringUntilDismissed", alarm.ringUntilDismissed)
            .put("autoStopMillis", alarm.autoStopMillis)
            .put("showFullScreenAlarm", alarm.showFullScreenAlarm)
            .put("dismissAction", alarm.dismissAction)
            .put("prewarningId", alarm.prewarningId)
    }

    private fun fromJson(json: JSONObject): ScheduledAlarm {
        return ScheduledAlarm(
            id = json.getInt("id"),
            millis = json.getLong("millis"),
            channelId = json.getString("channelId"),
            eventType = json.optString("eventType", AlarmContract.EVENT_TYPE_MAIN),
            scheduleMode = json.optString(
                "scheduleMode",
                if (json.optString("eventType", AlarmContract.EVENT_TYPE_MAIN) == AlarmContract.EVENT_TYPE_MAIN) {
                    SCHEDULE_MODE_ALARM_CLOCK
                } else {
                    SCHEDULE_MODE_EXACT_NOTIFICATION
                },
            ),
            title = json.getString("title"),
            body = json.getString("body"),
            purpose = json.optString("purpose", "breakStart"),
            breakOrdinal = json.optInt("breakOrdinal").let { if (json.has("breakOrdinal")) it else null },
            ringUntilDismissed = json.optBoolean("ringUntilDismissed", false),
            autoStopMillis = json.optLong("autoStopMillis", AlarmContract.DEFAULT_AUTO_STOP_MILLIS),
            showFullScreenAlarm = json.optBoolean(
                "showFullScreenAlarm",
                json.optString("eventType", AlarmContract.EVENT_TYPE_MAIN) == AlarmContract.EVENT_TYPE_MAIN,
            ),
            dismissAction = json.optString("dismissAction", AlarmContract.ACTION_DISMISS_ALARM),
            prewarningId = json.optInt("prewarningId").let { if (json.has("prewarningId")) it else null },
        )
    }

    companion object {
        fun register(context: Context, messenger: BinaryMessenger) {
            val adapter = AlarmSchedulerAdapter(context.applicationContext)
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val alarm = ScheduledAlarm(
                            id = call.argument<Int>("id") ?: error("id is required"),
                            millis = call.argument<Long>("millis") ?: error("millis is required"),
                            channelId = call.argument<String>("channelId") ?: error("channelId is required"),
                            eventType = call.argument<String>("eventType") ?: error("eventType is required"),
                            scheduleMode = call.argument<String>("scheduleMode")
                                ?: error("scheduleMode is required"),
                            title = call.argument<String>("title") ?: error("title is required"),
                            body = call.argument<String>("body") ?: error("body is required"),
                            purpose = call.argument<String>("purpose") ?: error("purpose is required"),
                            breakOrdinal = call.argument<Int>("breakOrdinal"),
                            ringUntilDismissed = call.argument<Boolean>("ringUntilDismissed")
                                ?: error("ringUntilDismissed is required"),
                            autoStopMillis = call.argument<Number>("autoStopMillis")?.toLong()
                                ?: error("autoStopMillis is required"),
                            showFullScreenAlarm = call.argument<Boolean>("showFullScreenAlarm")
                                ?: error("showFullScreenAlarm is required"),
                            dismissAction = call.argument<String>("dismissAction")
                                ?: error("dismissAction is required"),
                            prewarningId = call.argument<Int>("prewarningId"),
                        )
                        adapter.schedule(alarm)
                        result.success(alarm.id)
                    }
                    "cancelAlarm" -> {
                        adapter.cancel(call.argument<Int>("id") ?: error("id is required"))
                        result.success(null)
                    }
                    "rescheduleAllOnBoot" -> {
                        adapter.rescheduleAllOnBoot()
                        result.success(null)
                    }
                    "pruneStaleAlarms" -> {
                        adapter.pruneStaleAlarms(
                            call.argument<Number>("nowMillis")?.toLong()
                                ?: error("nowMillis is required"),
                        )
                        result.success(null)
                    }
                    "hasExactAlarmPermission" -> result.success(adapter.canScheduleExactAlarms())
                    "requestExactAlarmPermission" -> result.success(adapter.requestExactAlarmPermission())
                    "hasNotificationPermission" -> result.success(adapter.hasNotificationPermission())
                    "requestNotificationPermission" -> result.success(adapter.requestNotificationPermission())
                    "requestBatteryOptimizationExemption" ->
                        result.success(adapter.requestBatteryOptimizationExemption())
                    "hasFullScreenIntentPermission" -> result.success(adapter.hasFullScreenIntentPermission())
                    "requestFullScreenIntentPermission" -> result.success(adapter.requestFullScreenIntentPermission())
                    "syncAlarmOutcomes" -> result.success(adapter.syncAlarmOutcomes())
                    else -> result.notImplemented()
                }
            }
        }
    }
}
