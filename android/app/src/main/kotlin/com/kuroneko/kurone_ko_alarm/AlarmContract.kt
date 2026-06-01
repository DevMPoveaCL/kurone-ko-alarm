package com.kuroneko.kurone_ko_alarm

object AlarmContract {
    const val ACTION_DISMISS_ALARM = "com.kuroneko.kurone_ko_alarm.DISMISS_ALARM"
    const val ACTION_STOP_RINGING = "com.kuroneko.kurone_ko_alarm.STOP_RINGING"
    const val EVENT_TYPE_MAIN = "main"
    const val EVENT_TYPE_PRE_WARNING = "preWarning"
    const val DEFAULT_AUTO_STOP_MILLIS = 5 * 60 * 1000L

    fun shouldRing(eventType: String?, ringUntilDismissed: Boolean): Boolean {
        return eventType == EVENT_TYPE_MAIN || ringUntilDismissed
    }
}
