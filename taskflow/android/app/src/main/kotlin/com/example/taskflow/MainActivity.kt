package com.example.taskflow

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchPayload = intent?.getStringExtra(EXTRA_PAYLOAD)
        updateLockScreenVisibility(intent)
    }

    /**
     * Privacidad: la app solo se muestra sobre la pantalla de bloqueo cuando
     * la abre una notificación de alarma (respaldo fullScreenIntent). Abrirla
     * de forma normal, o desde cualquier otra vía, exige desbloquear el móvil.
     */
    private fun updateLockScreenVisibility(intent: Intent?) {
        val fromAlarm = intent?.action == ACTION_PLUGIN_NOTIFICATION ||
            intent?.getStringExtra(EXTRA_PAYLOAD) != null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(fromAlarm)
            setTurnScreenOn(fromAlarm)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (fromAlarm) window.addFlags(flags) else window.clearFlags(flags)
        }
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
                            (call.argument<Int>("weekday") ?: 1).coerceIn(1, 7),
                            call.argument<Boolean>("repeats") ?: false,
                            // Dart manda int: llega como Integer o Long según su tamaño.
                            call.argument<Number>("triggerAt")?.toLong() ?: 0L,
                            call.argument<Boolean>("stopsOnComplete") ?: false
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
        // Práctica estándar con singleTop: getIntent() debe ser el más reciente.
        setIntent(intent)
        updateLockScreenVisibility(intent)
        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: return
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger == null) {
            // Sin motor Flutter todavía: Dart lo recoge con consumeLaunchPayload.
            launchPayload = payload
            return
        }
        // Entrega única por el canal. Si Dart aún no escucha (HomePage sin
        // montar), se guarda para que _checkLaunchPayload la aplique al
        // reanudar en vez de perderse.
        MethodChannel(messenger, CHANNEL).invokeMethod(
            "onAlarmAction",
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(code: String, msg: String?, details: Any?) {
                    launchPayload = payload
                }
                override fun notImplemented() {
                    launchPayload = payload
                }
            }
        )
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
        const val EXTRA_STOPS_ON_COMPLETE = "alarm_stops_on_complete"

        /** Acción con la que flutter_local_notifications abre la app. */
        private const val ACTION_PLUGIN_NOTIFICATION = "SELECT_NOTIFICATION"

        var launchPayload: String? = null
            private set
    }
}
