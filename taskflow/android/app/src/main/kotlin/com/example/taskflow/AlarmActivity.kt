package com.example.taskflow

import android.app.KeyguardManager
import android.app.NotificationManager
import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
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
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
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
    private val animHandler = Handler(Looper.getMainLooper())
    private var bellRestart: Runnable? = null
    private var alarmAnimationsRunning = false
    private val alarmAnimators = mutableListOf<Animator>()

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
        startAlarmAnimation()
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
        for (waveId in intArrayOf(R.id.wave1, R.id.wave2, R.id.wave3)) {
            findViewById<View>(waveId).backgroundTintList =
                ColorStateList.valueOf(theme.accent)
        }
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
        btnComplete.backgroundTintList = null
        btnComplete.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(theme.accent)
        }
        btnComplete.setTextColor(theme.onAccent)
        btnComplete.compoundDrawableTintList = ColorStateList.valueOf(theme.onAccent)
        btnComplete.typeface = bodyFace
        val btnSnooze = findViewById<Button>(R.id.btnSnooze)
        btnSnooze.backgroundTintList = null
        btnSnooze.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setStroke((1.5f * density).toInt(), theme.secondaryBorder)
            setColor(android.graphics.Color.TRANSPARENT)
        }
        btnSnooze.setTextColor(theme.onBackground)
        btnSnooze.compoundDrawableTintList = ColorStateList.valueOf(theme.onBackground)
        btnSnooze.typeface = bodyFace
    }

    /**
     * Animación de alarma: campana con sacudida tipo timbre (rotación de
     * -22° a +22°, 90 ms por medio-ciclo, 12 medio-ciclos con escala 1.0-1.12
     * sincronizada y pivote arriba al centro; pausa de 350 ms y repite),
     * 3 ondas que se expanden (escala 1.0-1.8, alfa 0.35-0, 1,2 s,
     * escalonadas 400 ms), halo que late (1.0-1.15 y alfa 1.0-0.5, 500 ms) y
     * hora que pulsa (1.0-1.04, 500 ms) sincronizada con el halo.
     * Sin animaciones si ANIMATOR_DURATION_SCALE = 0.
     */
    private fun animationsDisabled(): Boolean {
        return try {
            Settings.Global.getFloat(
                contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f
            ) == 0f
        } catch (_: Exception) {
            false
        }
    }

    private fun track(animator: Animator): Animator {
        alarmAnimators.add(animator)
        return animator
    }

    private fun startAlarmAnimation() {
        if (animationsDisabled()) return
        alarmAnimationsRunning = true
        val bell = findViewById<ImageView>(R.id.alarmIcon)
        val halo = findViewById<View>(R.id.circleOuter)
        val tvTime = findViewById<TextView>(R.id.tvTime)
        val waves = listOf(
            findViewById<View>(R.id.wave1),
            findViewById<View>(R.id.wave2),
            findViewById<View>(R.id.wave3)
        )
        val hardwareViews = listOf<View>(bell, halo, tvTime) + waves
        for (v in hardwareViews) {
            try {
                v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            } catch (_: Exception) {
            }
        }
        bell.post {
            if (!alarmAnimationsRunning) return@post
            bell.pivotX = bell.width / 2f
            bell.pivotY = 0f
            runBellBurst(bell)
        }
        for ((index, wave) in waves.withIndex()) {
            wave.alpha = 0.35f
            wave.scaleX = 1f
            wave.scaleY = 1f
            val scaleX = ObjectAnimator.ofFloat(wave, View.SCALE_X, 1f, 1.8f).apply {
                duration = 1200
                interpolator = AccelerateDecelerateInterpolator()
                repeatMode = ObjectAnimator.RESTART
                repeatCount = ObjectAnimator.INFINITE
                startDelay = (index * 400).toLong()
            }
            val scaleY = ObjectAnimator.ofFloat(wave, View.SCALE_Y, 1f, 1.8f).apply {
                duration = 1200
                interpolator = AccelerateDecelerateInterpolator()
                repeatMode = ObjectAnimator.RESTART
                repeatCount = ObjectAnimator.INFINITE
                startDelay = (index * 400).toLong()
            }
            val fade = ObjectAnimator.ofFloat(wave, View.ALPHA, 0.35f, 0f).apply {
                duration = 1200
                interpolator = AccelerateDecelerateInterpolator()
                repeatMode = ObjectAnimator.RESTART
                repeatCount = ObjectAnimator.INFINITE
                startDelay = (index * 400).toLong()
            }
            (track(AnimatorSet().apply {
                playTogether(scaleX, scaleY, fade)
            }) as AnimatorSet).start()
        }
        val haloScaleX = ObjectAnimator.ofFloat(halo, View.SCALE_X, 1f, 1.15f).apply {
            duration = 500
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
        }
        val haloScaleY = ObjectAnimator.ofFloat(halo, View.SCALE_Y, 1f, 1.15f).apply {
            duration = 500
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
        }
        val haloFade = ObjectAnimator.ofFloat(halo, View.ALPHA, 1f, 0.5f).apply {
            duration = 500
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
        }
        val timeScaleX = ObjectAnimator.ofFloat(tvTime, View.SCALE_X, 1f, 1.04f).apply {
            duration = 500
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
        }
        val timeScaleY = ObjectAnimator.ofFloat(tvTime, View.SCALE_Y, 1f, 1.04f).apply {
            duration = 500
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
        }
        (track(AnimatorSet().apply {
            playTogether(haloScaleX, haloScaleY, haloFade, timeScaleX, timeScaleY)
        }) as AnimatorSet).start()
    }

    private fun runBellBurst(bell: ImageView) {
        if (!alarmAnimationsRunning || animationsDisabled()) return
        val shake = ObjectAnimator.ofFloat(bell, View.ROTATION, -22f, 22f).apply {
            duration = 90
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = 11
        }
        val growX = ObjectAnimator.ofFloat(bell, View.SCALE_X, 1f, 1.12f).apply {
            duration = 90
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = 11
        }
        val growY = ObjectAnimator.ofFloat(bell, View.SCALE_Y, 1f, 1.12f).apply {
            duration = 90
            interpolator = AccelerateDecelerateInterpolator()
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = 11
        }
        val burst = AnimatorSet().apply {
            playTogether(shake, growX, growY)
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    alarmAnimators.remove(animation)
                    if (!alarmAnimationsRunning) return
                    bellRestart?.let { animHandler.removeCallbacks(it) }
                    bellRestart = Runnable { runBellBurst(bell) }
                    animHandler.postDelayed(bellRestart!!, 350)
                }
            })
        }
        track(burst)
        burst.start()
    }

    private fun stopAlarmAnimation() {
        alarmAnimationsRunning = false
        bellRestart?.let { animHandler.removeCallbacks(it) }
        bellRestart = null
        for (animator in alarmAnimators.toList()) {
            try {
                animator.cancel()
            } catch (_: Exception) {
            }
        }
        alarmAnimators.clear()
        try {
            val bell = findViewById<ImageView>(R.id.alarmIcon)
            bell.rotation = 0f
            bell.scaleX = 1f
            bell.scaleY = 1f
            val halo = findViewById<View>(R.id.circleOuter)
            halo.scaleX = 1f
            halo.scaleY = 1f
            halo.alpha = 1f
            val tvTime = findViewById<TextView>(R.id.tvTime)
            tvTime.scaleX = 1f
            tvTime.scaleY = 1f
            for (waveId in intArrayOf(R.id.wave1, R.id.wave2, R.id.wave3)) {
                val wave = findViewById<View>(waveId)
                wave.scaleX = 1f
                wave.scaleY = 1f
                wave.alpha = 0f
            }
            val views = listOf<View>(
                bell,
                halo,
                tvTime,
                findViewById(R.id.wave1),
                findViewById(R.id.wave2),
                findViewById(R.id.wave3)
            )
            for (v in views) {
                try {
                    v.setLayerType(View.LAYER_TYPE_NONE, null)
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
        }
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

    override fun onStop() {
        stopAlarmAnimation()
        super.onStop()
    }

    override fun onDestroy() {
        stopAlarmAnimation()
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
        stopAlarmAnimation()
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
