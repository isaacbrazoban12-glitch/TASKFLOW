package com.example.taskflow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val isValid = action == Intent.ACTION_BOOT_COMPLETED ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && action == Intent.ACTION_MY_PACKAGE_REPLACED) ||
                action == "android.intent.action.QUICKBOOT_POWERON"
        if (!isValid) return

        Log.d("AlarmBootReceiver", "Arranque detectado, restaurando alarmas overlay")
        NativeAlarmHelper.restoreAlarmsAfterBoot(context)
    }
}