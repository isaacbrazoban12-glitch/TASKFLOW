package com.example.taskflow

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import org.json.JSONArray
import java.util.Calendar

/**
 * Espejo en Kotlin de `lib/app_themes.dart` + `lib/theme_controller.dart`.
 * Lee las mismas claves de FlutterSharedPreferences (con prefijo `flutter.`)
 * para elegir el tema vigente aunque la app esté cerrada.
 * El orden de rotación es el del enum Dart: rosa, medianoche, grafito, bosque.
 */
data class AlarmTheme(
    val id: String,
    val background: Int,
    val accent: Int,
    val onAccent: Int,
    val onBackground: Int,
    val isDark: Boolean
)

object ThemeHelper {

    private val themes = mapOf(
        "rosa" to AlarmTheme(
            "rosa",
            Color.parseColor("#FFF6F9"),
            Color.parseColor("#C93C74"),
            Color.WHITE,
            Color.parseColor("#1C1B1F"),
            false
        ),
        "medianoche" to AlarmTheme(
            "medianoche",
            Color.parseColor("#0B1220"),
            Color.parseColor("#22D3EE"),
            Color.parseColor("#101418"),
            Color.parseColor("#E6E1E5"),
            true
        ),
        "grafito" to AlarmTheme(
            "grafito",
            Color.parseColor("#ECEEF1"),
            Color.parseColor("#C2410C"),
            Color.WHITE,
            Color.parseColor("#1C1B1F"),
            false
        ),
        "bosque" to AlarmTheme(
            "bosque",
            Color.parseColor("#0F1F18"),
            Color.parseColor("#BEF264"),
            Color.parseColor("#101418"),
            Color.parseColor("#E6E1E5"),
            true
        )
    )

    private val rotationOrder = listOf("rosa", "medianoche", "grafito", "bosque")

    private val defaultRules = listOf(
        360 to "rosa",
        720 to "grafito",
        1080 to "medianoche"
    )

    fun currentTheme(context: Context, nowMillis: Long = System.currentTimeMillis()): AlarmTheme {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            when (prefs.getString("flutter.taskflow_theme_mode", "schedule")) {
                "manual" -> byName(prefs.getString("flutter.taskflow_theme_manual", "rosa"))
                "rotation" -> {
                    val hours = prefs.getLong("flutter.taskflow_theme_rotation_hours", 6).toInt().coerceIn(1, 24)
                    val epochHours = nowMillis / 3600000L
                    byName(rotationOrder[((epochHours / hours) % rotationOrder.size).toInt()])
                }
                else -> scheduleTheme(prefs, nowMillis)
            }
        } catch (_: Exception) {
            byName("rosa")
        }
    }

    private fun scheduleTheme(prefs: SharedPreferences, nowMillis: Long): AlarmTheme {
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        if (prefs.getBoolean("flutter.taskflow_theme_weekend_enabled", true) &&
            (dayOfWeek == Calendar.SATURDAY || dayOfWeek == Calendar.SUNDAY)
        ) {
            return byName(prefs.getString("flutter.taskflow_theme_weekend", "bosque"))
        }
        val rules = parseRules(prefs.getString("flutter.taskflow_theme_rules", null))
        val minutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        var pick = rules.last().second
        for ((start, theme) in rules) {
            if (start <= minutes) pick = theme
        }
        return byName(pick)
    }

    private fun parseRules(raw: String?): List<Pair<Int, String>> {
        if (raw == null) return defaultRules
        try {
            val arr = JSONArray(raw)
            val out = mutableListOf<Pair<Int, String>>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val start = obj.getInt("start")
                val theme = obj.getString("theme")
                if (start in 0..1439 && themes.containsKey(theme)) {
                    out.add(start to theme)
                }
            }
            if (out.isNotEmpty()) return out.sortedBy { it.first }
        } catch (_: Exception) {
        }
        return defaultRules
    }

    private fun byName(name: String?): AlarmTheme =
        themes[name] ?: themes.getValue("rosa")
}
