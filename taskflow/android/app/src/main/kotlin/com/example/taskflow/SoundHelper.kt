package com.example.taskflow

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log

/**
 * Sonidos de alarma: los propios de TaskFlow (res/raw/tf_*), los del teléfono
 * (RingtoneManager) y la música que elige el usuario (Storage Access
 * Framework, con permiso persistente de solo lectura).
 *
 * Identificadores de sonido (los mismos que guarda Dart):
 *  - null / "" / "default" → alarma predeterminada del sistema
 *  - "raw:tf_xxx"          → sonido propio
 *  - "content://…"         → sonido del teléfono o música elegida
 *
 * Ajustes en FlutterSharedPreferences (Dart los escribe sin el prefijo):
 *  - flutter.alarm_sound_default        String
 *  - flutter.alarm_sound_task_<taskId>  String
 *  - flutter.alarm_crescendo            Boolean (por defecto false)
 *  - flutter.alarm_vibrate              Boolean (por defecto true)
 *  - flutter.alarm_auto_silence_min     Int/Long (por defecto 10)
 */
object SoundHelper {

    private const val TAG = "SoundHelper"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREVIEW_MAX_MS = 15_000L

    private var previewPlayer: MediaPlayer? = null
    private val previewHandler = Handler(Looper.getMainLooper())
    private val stopPreviewRunnable = Runnable { stopPreview() }

    private fun prefs(context: Context) =
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    /** Lee un valor numérico sin romper si Dart lo guardó como Long o Int. */
    fun readInt(context: Context, key: String, default: Int): Int =
        (prefs(context).all[key] as? Number)?.toInt() ?: default

    fun readBool(context: Context, key: String, default: Boolean): Boolean =
        prefs(context).all[key] as? Boolean ?: default

    private fun readString(context: Context, key: String): String? =
        (prefs(context).all[key] as? String)?.takeIf { it.isNotBlank() }

    /** Sonido de la tarea; si no tiene, el predeterminado de la app. */
    fun soundForTask(context: Context, taskId: Int): String? =
        readString(context, "flutter.alarm_sound_task_$taskId")
            ?: readString(context, "flutter.alarm_sound_default")

    fun crescendoEnabled(context: Context) =
        readBool(context, "flutter.alarm_crescendo", false)

    fun vibrateEnabled(context: Context) =
        readBool(context, "flutter.alarm_vibrate", true)

    fun autoSilenceMinutes(context: Context) =
        readInt(context, "flutter.alarm_auto_silence_min", 10).coerceIn(1, 60)

    fun systemDefaultUri(): Uri? =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

    /** Convierte un identificador en Uri reproducible (null = sistema). */
    fun resolveUri(context: Context, sound: String?): Uri? {
        if (sound.isNullOrBlank() || sound == "default") return systemDefaultUri()
        if (sound.startsWith("raw:")) {
            val name = sound.removePrefix("raw:")
            // Solo nombres propios: evita cargar recursos arbitrarios.
            if (!name.matches(Regex("tf_[a-z0-9_]+"))) return systemDefaultUri()
            val id = context.resources.getIdentifier(name, "raw", context.packageName)
            if (id == 0) return systemDefaultUri()
            return Uri.parse(
                "${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/$id"
            )
        }
        val uri = Uri.parse(sound)
        // Solo content:// (sistema o archivos elegidos); nada de file:// ni http.
        return if (uri.scheme == ContentResolver.SCHEME_CONTENT) uri else systemDefaultUri()
    }

    private fun alarmAttributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /**
     * Crea un MediaPlayer en bucle para [sound]. Si el archivo ya no existe o
     * no se puede leer (música borrada, permiso perdido), usa la alarma del
     * sistema: la alarma nunca se queda muda por un sonido roto.
     */
    fun createPlayer(context: Context, sound: String?, looping: Boolean = true): MediaPlayer? {
        val candidates = listOfNotNull(resolveUri(context, sound), systemDefaultUri()).distinct()
        for (uri in candidates) {
            try {
                return MediaPlayer().apply {
                    setAudioAttributes(alarmAttributes())
                    setDataSource(context, uri)
                    isLooping = looping
                    prepare()
                }
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo preparar el sonido, probando el siguiente: $e")
            }
        }
        return null
    }

    // ---------- Sonidos del teléfono ----------

    /** Tonos de alarma y de llamada instalados en el teléfono. */
    fun listSystemSounds(context: Context): List<Map<String, String>> {
        val result = linkedMapOf<String, String>()
        for (type in intArrayOf(RingtoneManager.TYPE_ALARM, RingtoneManager.TYPE_RINGTONE)) {
            try {
                val manager = RingtoneManager(context).apply { setType(type) }
                val cursor = manager.cursor
                while (cursor.moveToNext()) {
                    val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX) ?: continue
                    val uri = manager.getRingtoneUri(cursor.position)?.toString() ?: continue
                    result.putIfAbsent(uri, title)
                }
            } catch (e: Exception) {
                Log.w(TAG, "No se pudieron listar tonos del tipo $type: $e")
            }
        }
        return result.map { (uri, title) -> mapOf("id" to uri, "name" to title) }
    }

    // ---------- Música elegida por el usuario ----------

    fun pickAudioIntent(): Intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "audio/*"
        addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
    }

    /** Guarda permiso de lectura permanente y devuelve {id, name}. */
    fun onAudioPicked(context: Context, uri: Uri): Map<String, String>? {
        return try {
            context.contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            var name = "Mi canción"
            context.contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
            )?.use { c ->
                if (c.moveToFirst()) {
                    c.getString(0)?.let { name = it.substringBeforeLast('.').take(80) }
                }
            }
            mapOf("id" to uri.toString(), "name" to name)
        } catch (e: Exception) {
            Log.e(TAG, "No se pudo conservar el acceso a la canción: $e")
            null
        }
    }

    /** Suelta el permiso cuando el usuario quita la canción de su lista. */
    fun releaseAudio(context: Context, sound: String) {
        try {
            val uri = Uri.parse(sound)
            if (uri.scheme != ContentResolver.SCHEME_CONTENT) return
            context.contentResolver.releasePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
        }
    }

    // ---------- Vista previa ----------

    fun preview(context: Context, sound: String?) {
        stopPreview()
        val player = createPlayer(context, sound, looping = false) ?: return
        previewPlayer = player
        player.setOnCompletionListener { stopPreview() }
        player.start()
        previewHandler.postDelayed(stopPreviewRunnable, PREVIEW_MAX_MS)
    }

    fun stopPreview() {
        previewHandler.removeCallbacks(stopPreviewRunnable)
        previewPlayer?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        previewPlayer = null
    }

    // ---------- Volumen de alarmas ----------

    fun alarmVolume(context: Context): Map<String, Int> {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return mapOf(
            "current" to am.getStreamVolume(AudioManager.STREAM_ALARM),
            "max" to am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        )
    }

    fun setAlarmVolume(context: Context, value: Int) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        try {
            am.setStreamVolume(AudioManager.STREAM_ALARM, value.coerceIn(0, max), 0)
        } catch (e: SecurityException) {
            // Modo No molestar puede impedir cambiarlo.
            Log.w(TAG, "No se pudo cambiar el volumen de alarma: $e")
        }
    }

    /** Si el volumen de alarma está en 0, lo sube a un nivel audible. */
    fun ensureAudible(context: Context) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (am.getStreamVolume(AudioManager.STREAM_ALARM) == 0) {
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            setAlarmVolume(context, (max * 0.4).toInt().coerceAtLeast(1))
        }
    }
}
