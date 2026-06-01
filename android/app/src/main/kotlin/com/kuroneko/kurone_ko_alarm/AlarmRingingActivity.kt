package com.kuroneko.kurone_ko_alarm

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmRingingActivity : Activity() {
    private var alarmId: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureAlarmWindow()
        alarmId = intent.getIntExtra("id", 0)
        setContentView(alarmView())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        alarmId = intent.getIntExtra("id", 0)
    }

    private fun configureAlarmWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
        )
    }

    private fun alarmView(): LinearLayout {
        val title = intent.getStringExtra("title") ?: "Alarma"
        val body = intent.getStringExtra("body") ?: "La alarma está sonando."
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(0xFF111827.toInt())
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            addView(
                TextView(context).apply {
                    text = title
                    setTextColor(0xFFFFFFFF.toInt())
                    textSize = 34f
                    gravity = Gravity.CENTER
                },
            )
            addView(
                TextView(context).apply {
                    text = body
                    setTextColor(0xFFE5E7EB.toInt())
                    textSize = 20f
                    gravity = Gravity.CENTER
                    setPadding(0, 24, 0, 48)
                },
            )
            addView(
                Button(context).apply {
                    text = "Detener alarma"
                    textSize = 22f
                    minHeight = 120
                    setOnClickListener { stopAlarmAndClose() }
                },
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }
    }

    private fun stopAlarmAndClose() {
        AlarmSchedulerAdapter(this).recordOutcome(alarmId, "dismissed")
        startService(
            Intent(this, AlarmRingingService::class.java).apply {
                action = AlarmContract.ACTION_STOP_RINGING
                putExtra("id", alarmId)
            },
        )
        finishAndRemoveTask()
    }
}
