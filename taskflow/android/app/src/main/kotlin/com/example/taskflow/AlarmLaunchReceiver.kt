package com.example.taskflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

class AlarmLaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getIntExtra(MainActivity.EXTRA_TASK_ID, -1)
        val weekday = intent.getIntExtra(MainActivity.EXTRA_WEEKDAY, 1)
        val title = intent.getStringExtra(MainActivity.EXTRA_TITLE) ?: "Tarea"
        val alarmId = intent.getIntExtra(MainActivity.EXTRA_ALARM_ID, 0)

        Log.d("AlarmLaunchReceiver", "Disparado alarmId=$alarmId tarea=$title")

        val wakeLock = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP, "taskflow::alarm")
        wakeLock.acquire(30000)

        val launch = Intent(context, AlarmActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_ALARM_ID, alarmId)
            putExtra(MainActivity.EXTRA_TITLE, title)
            putExtra(MainActivity.EXTRA_TASK_ID, taskId)
            putExtra(MainActivity.EXTRA_WEEKDAY, weekday)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
        }
        Log.d("AlarmLaunchReceiver", "Lanzando AlarmActivity")
        context.startActivity(launch)

        if (wakeLock.isHeld) wakeLock.release()
    }
}
