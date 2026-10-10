package com.example.taskflow

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchPayload = intent?.getStringExtra(EXTRA_PAYLOAD)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleOverlayAlarm" -> {
                        NativeAlarmHelper.scheduleAlarm(
                            this,
                            call.argument<Int>("alarmId") ?: 0,
                            call.argument<String>("title") ?: "Tarea",
                            call.argument<Int>("taskId") ?: -1,
                            call.argument<Int>("weekday") ?: 1,
                            call.argument<Boolean>("repeats") ?: false,
                            call.argument<Long>("triggerAt") ?: 0L
                        )
                        result.success(true)
                    }
                    "cancelOverlayAlarm" -> {
                        NativeAlarmHelper.cancelAlarm(
                            this,
                            call.argument<Int>("alarmId") ?: 0
                        )
                        result.success(true)
                    }
                    "canDrawOverlays" -> {
                        result.success(Settings.canDrawOverlays(this))
                    }
                    "openOverlaySettings" -> {
                        NativeAlarmHelper.openOverlaySettings(this)
                        result.success(true)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(NativeAlarmHelper.isIgnoringBatteryOptimizations(this))
                    }
                    "openBatteryOptimizationSettings" -> {
                        NativeAlarmHelper.openBatteryOptimizationSettings(this)
                        result.success(true)
                    }
                    "consumeLaunchPayload" -> {
                        result.success(launchPayload)
                        launchPayload = null
                    }
                    "returnToPreviousApp" -> {
                        finishAndRemoveTask()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val payload = intent.getStringExtra(EXTRA_PAYLOAD)
        if (payload != null) {
            // Entrega única por el canal: no guardar en launchPayload para evitar
            // que _checkLaunchPayload lo aplique una segunda vez al reanudar.
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onAlarmAction", payload)
            }
        }
    }

    companion object {
        const val CHANNEL = "taskflow/alarm"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_TITLE = "alarm_title"
        const val EXTRA_TASK_ID = "alarm_task_id"
        const val EXTRA_WEEKDAY = "alarm_weekday"
        const val EXTRA_PAYLOAD = "alarm_payload"
        const val EXTRA_REPEATS = "alarm_repeats"
        const val EXTRA_TRIGGER_AT = "alarm_trigger_at"

        var launchPayload: String? = null
            private set
    }
}