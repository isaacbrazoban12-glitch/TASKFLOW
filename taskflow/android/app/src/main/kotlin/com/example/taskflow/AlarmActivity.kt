package com.example.taskflow

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.res.ResourcesCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : AppCompatActivity() {

    private var taskId: Int = -1
    private var weekday: Int = 1
    private var taskTitle: String = "Tarea"
    private var alarmId: Int = 0
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val timeHandler = Handler(Looper.getMainLooper())
    private var timeTicker: Runnable? = null

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

        // Sin la notificación de respaldo encima si es posible: ya disparó.
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(taskId * 10 + weekday)
            nm.cancel(taskId * 10 + weekday + 100000)
        } catch (_: Exception) {
        }

        val timeFormat = SimpleDateFormat("h:mm a", Locale.US)
        tvTime.text = timeFormat.format(Date())
        timeTicker = object : Runnable {
            override fun run() {
                tvTime.text = timeFormat.format(Date())
                timeHandler.postDelayed(this, 1000)
            }
        }
        timeHandler.postDelayed(timeTicker!!, 1000)

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

        applyTheme(ThemeHelper.currentTheme(this))
        startAlarmSoundAndVibration()
    }

    /**
     * Aplica el tema vigente (ver `ThemeHelper`).
     * No toca sonido, vibración, acciones ni reprogramación.
     */
    private fun applyTheme(theme: AlarmTheme) {
        val density = resources.displayMetrics.density
        val hourFace = ResourcesCompat.getFont(this, theme.fontHour)
        val bodyFace = ResourcesCompat.getFont(this, theme.fontBody)

        findViewById<LinearLayout>(R.id.alarmRoot).setBackgroundColor(theme.background)

        findViewById<TextView>(R.id.tvAlarmLabel).setTextColor(theme.label)
        val dateFormat = SimpleDateFormat("EEEE, d 'de' MMMM", Locale("es"))
        val dateText = dateFormat.format(Date()).replaceFirstChar { it.uppercase() }
        findViewById<TextView>(R.id.tvDate).apply {
            text = dateText
            setTextColor(theme.onBackground)
            typeface = bodyFace
        }

        findViewById<View>(R.id.circleOuter).backgroundTintList =
            ColorStateList.valueOf((theme.accent and 0x00FFFFFF) or 0x2E000000)
        findViewById<View>(R.id.circleInner).backgroundTintList =
            ColorStateList.valueOf(theme.accent)
        findViewById<ImageView>(R.id.alarmIcon).setColorFilter(theme.onAccent)

        findViewById<TextView>(R.id.tvTime).apply {
            setTextColor(theme.hour)
            typeface = hourFace
        }
        findViewById<TextView>(R.id.tvTaskTitle).apply {
            setTextColor(theme.onBackground)
            typeface = bodyFace
        }
        findViewById<TextView>(R.id.tvSnoozeCount).apply {
            setTextColor(theme.onBackground)
            typeface = bodyFace
        }

        val radius = theme.buttonRadiusDp * density
        val btnComplete = findViewById<Button>(R.id.btnComplete)
        btnComplete.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(theme.accent)
        }
        btnComplete.setTextColor(theme.onAccent)
        btnComplete.typeface = bodyFace
        val btnSnooze = findViewById<Button>(R.id.btnSnooze)
        btnSnooze.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setStroke((1.5f * density).toInt(), theme.secondaryBorder)
            setColor(android.graphics.Color.TRANSPARENT)
        }
        btnSnooze.setTextColor(theme.onBackground)
        btnSnooze.typeface = bodyFace
    }

    private fun startAlarmSoundAndVibration() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (uri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(this@AlarmActivity, uri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (e: Exception) {
            Log.e("AlarmActivity", "No se pudo reproducir sonido: $e")
        }
        try {
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 1000, 500, 1000), 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 1000, 500, 1000), 0)
            }
        } catch (e: Exception) {
            Log.e("AlarmActivity", "No se pudo vibrar: $e")
        }
    }

    private fun stopAlarmSoundAndVibration() {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
    }

    override fun onDestroy() {
        timeTicker?.let { timeHandler.removeCallbacks(it) }
        timeTicker = null
        stopAlarmSoundAndVibration()
        super.onDestroy()
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

    /**
     * Aplica la acción en nativo y cierra SIN abrir MainActivity.
     * Dart aplica su parte después leyendo la acción pendiente guardada.
     */
    private fun finishWithAction(action: String) {
        stopAlarmSoundAndVibration()
        if (taskId <= 0) {
            finish()
            return
        }
        if (action == "snoozed") {
            incrementSnoozeCount(taskId, weekday)
            val triggerAt = System.currentTimeMillis() + 5L * 60 * 1000
            val snoozeId = taskId * 10 + weekday + 100000
            NativeAlarmHelper.scheduleAlarm(this, snoozeId, taskTitle, taskId, weekday, false, triggerAt)
            // Marca para que Dart no toque nada aunque tarde en arrancar.
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit().putLong("flutter.snooze_deadline_$taskId", triggerAt).apply()
            NativeAlarmHelper.storePendingAction(this, "snoozed", taskId, weekday, taskTitle, triggerAt)
        } else {
            NativeAlarmHelper.cancelAlarmsForTask(this, taskId)
            NativeAlarmHelper.storePendingAction(this, "completed", taskId, weekday, taskTitle, System.currentTimeMillis())
        }
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
        // Locale.US para que mes/día siempre sean dígitos latinos con dos
        // cifras, igual que Dart (AlarmDialog.dateSuffix).
        val now = Date()
        val year = SimpleDateFormat("yyyy", Locale.US).format(now)
        val month = SimpleDateFormat("MM", Locale.US).format(now)
        val day = SimpleDateFormat("dd", Locale.US).format(now)
        return "${year}_${month}_${day}"
    }

    override fun onBackPressed() {
    // No permitir cerrar con botón atrás
    }
}
