package com.kuroneko.kurone_ko_alarm

import android.content.Context
import android.content.Intent

object AlarmRingingIntentFactory {
    fun create(
        context: Context,
        id: Int,
        title: String,
        body: String,
        purpose: String? = null,
    ): Intent {
        return Intent(context, AlarmRingingActivity::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
            purpose?.let { putExtra("purpose", it) }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
    }

    fun createFrom(context: Context, source: Intent): Intent {
        return create(
            context = context,
            id = source.getIntExtra("id", 0),
            title = source.getStringExtra("title") ?: "Alarma",
            body = source.getStringExtra("body") ?: "La alarma está sonando.",
            purpose = source.getStringExtra("purpose"),
        )
    }
}
