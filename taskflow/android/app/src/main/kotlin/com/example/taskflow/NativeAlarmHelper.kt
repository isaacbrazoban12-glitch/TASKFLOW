package com.example.taskflow

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject
import java.util.Calendar

object NativeAlarmHelper {

    private const val PREFS_NAME = "taskflow_overlay_alarms"
    private const val KEY_PREFIX = "alarm_"

    fun scheduleAlarm(
        context: Context,
        alarmId: Int,
        title: String,
        taskId: Int,
        weekday: Int,
        repeats: Boolean,
        triggerAtMillis: Long
    ) {
        val intent = Intent(context, AlarmLaunchReceiver::class.java).apply {
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
            putExtra(MainActivity.EXTRA_TITLE, title)
            putExtra(MainActivity.EXTRA_TASK_ID, taskId)
            putExtra(MainActivity.EXTRA_WEEKDAY, weekday)
            putExtra(MainActivity.EXTRA_REPEATS, repeats)
            putExtra(MainActivity.EXTRA_TRIGGER_AT, triggerAtMillis)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, null),
                pending
            )
        } catch (e: SecurityException) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            } catch (e2: SecurityException) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }
        }
        persistAlarm(context, alarmId, title, taskId, weekday, repeats, triggerAtMillis)
    }

    fun cancelAlarm(context: Context, alarmId: Int) {
        val intent = Intent(context, AlarmLaunchReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pending != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pending)
            pending.cancel()
        }
        removeAlarm(context, alarmId)
    }

    fun openOverlaySettings(context: Context) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun openBatteryOptimizationSettings(context: Context) {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e("NativeAlarmHelper", "No se pudo abrir ajustes de batería: $e")
        }
    }

    fun restoreAlarmsAfterBoot(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        for (key in prefs.all.keys) {
            if (!key.startsWith(KEY_PREFIX)) continue
            val value = prefs.getString(key, null) ?: continue
            try {
                val json = JSONObject(value)
                val alarmId = json.getInt("alarmId")
                val title = json.getString("title")
                val taskId = json.getInt("taskId")
                val weekday = json.getInt("weekday")
                val repeats = json.getBoolean("repeats")
                val triggerAt = json.getLong("triggerAt")

                val nextTrigger = if (repeats) {
                    nextWeekdayTime(weekday, triggerAt, now)
                } else {
                    if (triggerAt > now) triggerAt else -1L
                }
                if (nextTrigger > 0) {
                    scheduleAlarm(context, alarmId, title, taskId, weekday, repeats, nextTrigger)
                    Log.d("NativeAlarmHelper", "Restaurada alarma $alarmId en $nextTrigger")
                } else {
                    removeAlarm(context, alarmId)
                    Log.d("NativeAlarmHelper", "Alarma $alarmId expirada, eliminada")
                }
            } catch (e: Exception) {
                Log.e("NativeAlarmHelper", "Error restaurando alarma: $e")
                removeAlarm(context, key.substring(KEY_PREFIX.length).toIntOrNull() ?: -1)
            }
        }
    }

    private fun nextWeekdayTime(weekday: Int, triggerAt: Long, now: Long): Long {
        val calTrigger = Calendar.getInstance().apply { timeInMillis = triggerAt }
        val hour = calTrigger.get(Calendar.HOUR_OF_DAY)
        val minute = calTrigger.get(Calendar.MINUTE)
        val targetCalDay = (weekday % 7) + 1

        repeat(8) { daysFromNow ->
            val tryCal = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DAY_OF_YEAR, daysFromNow)
            }
            if (tryCal.get(Calendar.DAY_OF_WEEK) == targetCalDay) {
                tryCal.set(Calendar.HOUR_OF_DAY, hour)
                tryCal.set(Calendar.MINUTE, minute)
                tryCal.set(Calendar.SECOND, 0)
                tryCal.set(Calendar.MILLISECOND, 0)
                if (tryCal.timeInMillis > now) return tryCal.timeInMillis
            }
        }
        return now + 7L * 24 * 3600 * 1000
    }

    private fun persistAlarm(
        context: Context,
        alarmId: Int,
        title: String,
        taskId: Int,
        weekday: Int,
        repeats: Boolean,
        triggerAtMillis: Long
    ) {
        val json = JSONObject().apply {
            put("alarmId", alarmId)
            put("title", title)
            put("taskId", taskId)
            put("weekday", weekday)
            put("repeats", repeats)
            put("triggerAt", triggerAtMillis)
        }.toString()
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PREFIX + alarmId, json)
            .apply()
    }

    /**
     * Re-arme tras el disparo: setAlarmClock es one-shot.
     * Si [repeats] es true, agenda la siguiente ocurrencia (+7 días a la misma
     * hora) vía [scheduleAlarm] —que actualiza el valor persistido— y devuelve
     * el próximo trigger. Si es false, elimina la alarma persistida y devuelve null.
     */
    fun rescheduleNextWeek(
        context: Context,
        alarmId: Int,
        title: String,
        taskId: Int,
        weekday: Int,
        repeats: Boolean,
        lastTriggerAtMillis: Long
    ): Long? {
        if (!repeats) {
            removeAlarm(context, alarmId)
            return null
        }
        var next = lastTriggerAtMillis + 7L * 24 * 3600 * 1000
        val now = System.currentTimeMillis()
        while (next <= now) {
            next += 7L * 24 * 3600 * 1000
        }
        scheduleAlarm(context, alarmId, title, taskId, weekday, repeats, next)
        return next
    }

    fun removeAlarm(context: Context, alarmId: Int) {
        if (alarmId < 0) return
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PREFIX + alarmId)
            .apply()
    }
}