package com.kuroneko.kurone_ko_alarm

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class AlarmRingingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == AlarmContract.ACTION_STOP_RINGING) {
            stopRinging()
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent?.getIntExtra("id", 0) ?: 0
        val channelId = intent?.getStringExtra("channelId") ?: "break_alarms"
        val title = intent?.getStringExtra("title") ?: "Alarma"
        val body = intent?.getStringExtra("body") ?: "La alarma está sonando."
        val purpose = intent?.getStringExtra("purpose")
        val showFullScreenAlarm = intent?.getBooleanExtra("showFullScreenAlarm", false) ?: false
        val autoStopMillis = intent?.getLongExtra(
            "autoStopMillis",
            AlarmContract.DEFAULT_AUTO_STOP_MILLIS,
        ) ?: AlarmContract.DEFAULT_AUTO_STOP_MILLIS
        val prewarningId = intent?.getIntExtra("prewarningId", -1) ?: -1
        if (prewarningId != -1) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(prewarningId)
        }

        acquireWakeLock()
        startForeground(id, ringingNotification(id, channelId, title, body, showFullScreenAlarm, purpose))
        startAlarmSound()
        startVibration()

        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({
            stopRinging()
            stopSelf()
        }, autoStopMillis)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ringingNotification(
        id: Int,
        channelId: String,
        title: String,
        body: String,
        showFullScreenAlarm: Boolean,
        purpose: String?,
    ): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            id,
            AlarmRingingIntentFactory.create(this, id, title, body, purpose),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val dismissIntent = PendingIntent.getBroadcast(
            this,
            id,
            Intent(this, AlarmReceiver::class.java).apply {
                action = AlarmContract.ACTION_DISMISS_ALARM
                putExtra("id", id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val fullScreenIntent = PendingIntent.getActivity(
            this,
            id,
            AlarmRingingIntentFactory.create(this, id, title, body, purpose),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
        if (showFullScreenAlarm) {
            builder.setFullScreenIntent(fullScreenIntent, true)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Detener", dismissIntent)
            .build()
    }

    private fun startAlarmSound() {
        // Always restart sound for a new alarm, even if a previous alarm is still ringing.
        // This ensures every main alarm produces audible feedback reliably.
        mediaPlayer?.run {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        mediaPlayer = MediaPlayer().apply {
            setDataSource(this@AlarmRingingService, alarmUri)
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            isLooping = true
            prepare()
            start()
        }
    }

    private fun startVibration() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 700, 400, 700, 800)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, 0)
        }
    }

    private fun stopRinging() {
        handler.removeCallbacksAndMessages(null)
        mediaPlayer?.run {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null
        stopVibration()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun stopVibration() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator.cancel()
        } else {
            @Suppress("DEPRECATION")
            (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "kurone_ko_alarm:alarm_ringing",
        ).apply { acquire(AlarmContract.DEFAULT_AUTO_STOP_MILLIS + 30_000L) }
    }

    private fun releaseWakeLock() {
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }
}
