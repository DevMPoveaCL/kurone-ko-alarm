package com.kuroneko.kurone_ko_alarm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmSchedulerAdapter.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
