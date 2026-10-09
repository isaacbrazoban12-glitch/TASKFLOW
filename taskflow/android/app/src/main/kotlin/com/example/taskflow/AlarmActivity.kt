package com.example.taskflow

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : AppCompatActivity() {

    private var taskId: Int = -1
    private var weekday: Int = 1
    private var taskTitle: String = "Tarea"
    private var alarmId: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setupWindowFlags()

        setContentView(R.layout.activity_alarm)

        taskId = intent.getIntExtra(MainActivity.EXTRA_TASK_ID, -1)
        weekday = intent.getIntExtra(MainActivity.EXTRA_WEEKDAY, 1)
        taskTitle = intent.getStringExtra(MainActivity.EXTRA_TITLE) ?: "Tarea"
        alarmId = intent.getIntExtra(MainActivity.EXTRA_ALARM_ID, 0)

        val tvTime = findViewById<TextView>(R.id.tvTime)
        val tvTaskTitle = findViewById<TextView>(R.id.tvTaskTitle)
        val tvSnoozeCount = findViewById<TextView>(R.id.tvSnoozeCount)
        val btnComplete = findViewById<Button>(R.id.btnComplete)
        val btnSnooze = findViewById<Button>(R.id.btnSnooze)

        val timeFormat = SimpleDateFormat("h:mm a", Locale.getDefault())
        tvTime.text = timeFormat.format(Date())

        tvTaskTitle.text = taskTitle

        val snoozeCount = getSnoozeCount(taskId, weekday)
        tvSnoozeCount.text = "Posposiciones: $snoozeCount de 3"

        if (snoozeCount >= 3) {
            btnSnooze.isEnabled = false
            btnSnooze.alpha = 0.5f
        }

        btnComplete.setOnClickListener {
            finishWithAction("completed")
        }

        btnSnooze.setOnClickListener {
            incrementSnoozeCount(taskId, weekday)
            finishWithAction("snoozed")
        }
    }

    private fun setupWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    private fun finishWithAction(action: String) {
        val payload = JSONObject().apply {
            put("type", "alarm_action")
            put("action", action)
            put("taskId", taskId)
            put("title", taskTitle)
            put("weekday", weekday)
            put("alarmId", alarmId)
        }.toString()

        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_PAYLOAD, payload)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
        finish()
    }

    private fun getSnoozeCount(taskId: Int, weekday: Int): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.alarm_dismiss_${taskId}_${weekday}_${getCurrentYearMonthDay()}"
        return prefs.getInt(key, 0)
    }

    private fun incrementSnoozeCount(taskId: Int, weekday: Int) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.alarm_dismiss_${taskId}_${weekday}_${getCurrentYearMonthDay()}"
        val current = prefs.getInt(key, 0)
        prefs.edit().putInt(key, current + 1).apply()
    }

    private fun getCurrentYearMonthDay(): String {
        val now = Date()
        val year = SimpleDateFormat("yyyy", Locale.getDefault()).format(now)
        val month = SimpleDateFormat("MM", Locale.getDefault()).format(now)
        val day = SimpleDateFormat("dd", Locale.getDefault()).format(now)
        return "${year}_${month}_${day}"
    }

    override fun onBackPressed() {
    // No permitir cerrar con botón atrás
    }
}
