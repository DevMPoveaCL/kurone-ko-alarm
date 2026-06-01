package com.kuroneko.kurone_ko_alarm

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AlarmContract.ACTION_DISMISS_ALARM) {
            val id = intent.getIntExtra("id", 0)
            AlarmSchedulerAdapter(context).recordOutcome(id, "dismissed")
            val stopIntent = Intent(context, AlarmRingingService::class.java).apply {
                action = AlarmContract.ACTION_STOP_RINGING
                putExtra("id", id)
            }
            context.startService(stopIntent)
            return
        }

        val id = intent.getIntExtra("id", 0)
        val channelId = intent.getStringExtra("channelId") ?: "break_alarms"
        val title = intent.getStringExtra("title") ?: "Descanso"
        val body = intent.getStringExtra("body") ?: "El descanso empieza ahora."
        val eventType = intent.getStringExtra("eventType")
        val ringUntilDismissed = intent.getBooleanExtra("ringUntilDismissed", false)
        val prewarningId = intent.getIntExtra("prewarningId", -1)
        if (prewarningId != -1) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(prewarningId)
        }
        if (AlarmContract.shouldRing(eventType, ringUntilDismissed)) {
            val serviceIntent = Intent(context, AlarmRingingService::class.java).apply {
                putExtras(intent)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            return
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, channelId)
        } else {
            android.app.Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(android.app.Notification.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(id, notification)
    }
}
