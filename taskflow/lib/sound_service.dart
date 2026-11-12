import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_info.dart';

/// Un sonido elegible para la alarma.
class AlarmSound {
  /// Identificador que entiende Kotlin (`SoundHelper.resolveUri`):
  /// `default`, `raw:tf_xxx` o `content://…`.
  final String id;
  final String name;
  final String? description;

  const AlarmSound(this.id, this.name, [this.description]);

  bool get isBuiltIn => id.startsWith('raw:');
  bool get isDefault => id == SoundService.defaultId;
}

/// Sonidos, volumen y opciones de la alarma. En Android habla con
/// `SoundHelper.kt`; en otras plataformas solo guarda las preferencias.
class SoundService extends ChangeNotifier {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const MethodChannel _channel = MethodChannel('taskflow/sound');

  static const String defaultId = 'default';

  // Claves compartidas con Kotlin (allí con prefijo `flutter.`).
  static const String keyDefault = 'alarm_sound_default';
  static const String keyCrescendo = 'alarm_crescendo';
  static const String keyVibrate = 'alarm_vibrate';
  static const String keyAutoSilence = 'alarm_auto_silence_min';
  static String keyTask(int taskId) => 'alarm_sound_task_$taskId';
  // Solo Dart.
  static const String _keyCustom = 'alarm_custom_sounds';
  static const String _keyLabels = 'alarm_sound_labels';

  /// Sonidos propios de TaskFlow (android/app/src/main/res/raw/tf_*.wav,
  /// generados con tool/generate_sounds.py).
  static const List<AlarmSound> builtIn = [
    AlarmSound('raw:tf_amanecer', 'Amanecer', 'Arpegio suave que sube'),
    AlarmSound('raw:tf_manana', 'Mañana tranquila', 'Acordes cálidos'),
    AlarmSound('raw:tf_campanas', 'Campanas', 'Campanario clásico'),
    AlarmSound('raw:tf_marimba', 'Marimba', 'Melodía alegre'),
    AlarmSound('raw:tf_cristal', 'Cristal', 'Campanillas brillantes'),
    AlarmSound('raw:tf_pajaros', 'Pájaros', 'Trinos de la mañana'),
    AlarmSound('raw:tf_zen', 'Zen', 'Cuenco tibetano'),
    AlarmSound('raw:tf_retro', 'Retro', 'Melodía de 8 bits'),
    AlarmSound('raw:tf_digital', 'Digital', 'Bip-bip de despertador'),
    AlarmSound('raw:tf_pulso', 'Pulso', 'Latido grave e insistente'),
    AlarmSound('raw:tf_sirena', 'Sirena suave', 'Tono que sube y baja'),
  ];

  static const AlarmSound systemDefault =
      AlarmSound(defaultId, 'Alarma del teléfono', 'La predeterminada del sistema');

  bool get supported => isAndroid;

  // ---------- Preferencias ----------

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String> defaultSound() async =>
      (await _prefs()).getString(keyDefault) ?? defaultId;

  Future<void> setDefaultSound(AlarmSound sound) async {
    final prefs = await _prefs();
    await prefs.setString(keyDefault, sound.id);
    await _rememberLabel(sound);
    notifyListeners();
  }

  Future<bool> crescendo() async => (await _prefs()).getBool(keyCrescendo) ?? false;

  Future<void> setCrescendo(bool value) async {
    await (await _prefs()).setBool(keyCrescendo, value);
    notifyListeners();
  }

  Future<bool> vibrate() async => (await _prefs()).getBool(keyVibrate) ?? true;

  Future<void> setVibrate(bool value) async {
    await (await _prefs()).setBool(keyVibrate, value);
    notifyListeners();
  }

  static const List<int> autoSilenceOptions = [5, 10, 15, 30];

  Future<int> autoSilenceMinutes() async =>
      (await _prefs()).getInt(keyAutoSilence) ?? 10;

  Future<void> setAutoSilenceMinutes(int minutes) async {
    await (await _prefs()).setInt(keyAutoSilence, minutes.clamp(1, 60));
    notifyListeners();
  }

  /// Copia el sonido de la tarea donde lo lee la alarma nativa.
  Future<void> syncTaskSound(int taskId, String? sound) async {
    final prefs = await _prefs();
    if (sound == null || sound.isEmpty) {
      await prefs.remove(keyTask(taskId));
    } else {
      await prefs.setString(keyTask(taskId), sound);
    }
  }

  Future<void> removeTaskSound(int taskId) => syncTaskSound(taskId, null);

  // ---------- Nombres ----------

  Future<void> _rememberLabel(AlarmSound sound) async {
    if (sound.isBuiltIn || sound.isDefault) return;
    final prefs = await _prefs();
    final labels = _decodeMap(prefs.getString(_keyLabels));
    labels[sound.id] = sound.name;
    await prefs.setString(_keyLabels, jsonEncode(labels));
  }

  Future<void> rememberLabel(AlarmSound sound) => _rememberLabel(sound);

  /// Nombre legible de un identificador guardado.
  Future<String> labelFor(String? id) async {
    if (id == null || id.isEmpty) return 'Predeterminado de la app';
    if (id == defaultId) return systemDefault.name;
    for (final s in builtIn) {
      if (s.id == id) return s.name;
    }
    final prefs = await _prefs();
    final labels = _decodeMap(prefs.getString(_keyLabels));
    return labels[id] ?? 'Sonido personalizado';
  }

  static Map<String, String> _decodeMap(String? raw) {
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  // ---------- Mi música ----------

  Future<List<AlarmSound>> customSounds() async {
    final raw = (await _prefs()).getString(_keyCustom);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => AlarmSound(m['id'].toString(), m['name'].toString(), 'Mi música'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCustom(List<AlarmSound> list) async {
    await (await _prefs()).setString(
      _keyCustom,
      jsonEncode([
        for (final s in list) {'id': s.id, 'name': s.name}
      ]),
    );
    notifyListeners();
  }

  /// Abre el selector de archivos del teléfono para elegir una canción.
  Future<AlarmSound?> pickFromPhone() async {
    if (!supported) return null;
    try {
      final result = await _channel.invokeMapMethod<String, String>('pickAudio');
      if (result == null || result['id'] == null) return null;
      final sound = AlarmSound(result['id']!, result['name'] ?? 'Mi canción', 'Mi música');
      final list = await customSounds();
      if (!list.any((s) => s.id == sound.id)) {
        await _saveCustom([...list, sound]);
      }
      await _rememberLabel(sound);
      return sound;
    } catch (e) {
      debugPrint('[SoundService] Error eligiendo canción: $e');
      return null;
    }
  }

  /// Quita una canción. Si era la predeterminada vuelve a la del sistema.
  Future<void> removeCustom(AlarmSound sound) async {
    final list = await customSounds();
    await _saveCustom(list.where((s) => s.id != sound.id).toList());
    final prefs = await _prefs();
    if (prefs.getString(keyDefault) == sound.id) {
      await prefs.setString(keyDefault, defaultId);
    }
    if (supported) {
      try {
        await _channel.invokeMethod('releaseAudio', {'id': sound.id});
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---------- Sonidos del teléfono ----------

  List<AlarmSound>? _systemCache;

  Future<List<AlarmSound>> systemSounds() async {
    if (!supported) return const [];
    if (_systemCache != null) return _systemCache!;
    try {
      final list = await _channel.invokeListMethod<Map>('listSystemSounds') ?? [];
      _systemCache = [
        for (final m in list) AlarmSound(m['id'].toString(), m['name'].toString()),
      ];
    } catch (e) {
      debugPrint('[SoundService] Error listando tonos: $e');
      _systemCache = const [];
    }
    return _systemCache!;
  }

  // ---------- Vista previa y volumen ----------

  String? _previewing;
  String? get previewing => _previewing;

  Future<void> preview(AlarmSound sound) async {
    if (!supported) return;
    if (_previewing == sound.id) return stopPreview();
    _previewing = sound.id;
    notifyListeners();
    try {
      await _channel.invokeMethod('preview', {'id': sound.id});
    } catch (_) {}
    // El nativo corta la vista previa a los 15 s.
    Future.delayed(const Duration(seconds: 15), () {
      if (_previewing == sound.id) {
        _previewing = null;
        notifyListeners();
      }
    });
  }

  Future<void> stopPreview() async {
    if (_previewing == null) return;
    _previewing = null;
    notifyListeners();
    if (!supported) return;
    try {
      await _channel.invokeMethod('stopPreview');
    } catch (_) {}
  }

  /// (actual, máximo) del volumen de alarmas del sistema.
  Future<(int, int)?> alarmVolume() async {
    if (!supported) return null;
    try {
      final r = await _channel.invokeMapMethod<String, int>('getAlarmVolume');
      if (r == null) return null;
      return (r['current'] ?? 0, r['max'] ?? 7);
    } catch (_) {
      return null;
    }
  }

  Future<void> setAlarmVolume(int value) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('setAlarmVolume', {'value': value});
    } catch (_) {}
  }
}
