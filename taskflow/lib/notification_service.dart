import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models/task.dart';
import 'platform_info.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const MethodChannel _alarmChannel = MethodChannel('taskflow/alarm');

  static const String alarmChannelId = 'taskflow_backup';
  static const String alarmChannelName = 'Respaldo de alarmas';
  static const String alarmChannelDesc = 'Respaldo silencioso de alarmas de tareas';
  static const String legacyAlarmChannelId = 'taskflow_alarms';

  bool get _supported => isAndroid || isIOS;

  bool _permissionsGranted = false;
  bool get permissionsGranted => _permissionsGranted;

  void Function(String payload)? onAlarmTriggered;
  void Function(String payload)? onAlarmAction;

  Future<void> init() async {
    debugPrint('[NotificationService] Inicializando...');
    if (!_supported) {
      debugPrint('[NotificationService] Plataforma no soportada: $operatingSystem');
      return;
    }

    _alarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmAction') {
        final payload = call.arguments as String?;
        if (payload != null) {
          onAlarmAction?.call(payload);
        }
      }
    });

    tzdata.initializeTimeZones();

    String timezoneName = 'UTC';
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      timezoneName = timezoneInfo.identifier;
      debugPrint('[NotificationService] Zona horaria detectada: $timezoneName');
    } catch (e) {
      debugPrint('[NotificationService] ERROR detectando zona horaria: $e, usando UTC');
    }

    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
      debugPrint('[NotificationService] Timezone configurada: ${tz.local.name}');
    } catch (e) {
      debugPrint('[NotificationService] ERROR configurando timezone: $e, usando UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      debugPrint('[NotificationService] Plugin inicializado');
    } catch (e) {
      debugPrint('[NotificationService] ERROR inicializando plugin: $e');
      return;
    }

    if (isAndroid) {
      await _deleteLegacyAlarmChannel();
      await _requestAndroidPermissions();
    } else if (isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImpl =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final result = await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
      _permissionsGranted = result ?? false;
      debugPrint('[NotificationService] iOS permisos: $_permissionsGranted');
    }
  }

  /// Borra el canal viejo con sonido para que el respaldo use el nuevo silencioso.
  Future<void> _deleteLegacyAlarmChannel() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.deleteNotificationChannel(legacyAlarmChannelId);
      debugPrint('[NotificationService] Canal legacy eliminado');
    } catch (e) {
      debugPrint('[NotificationService] ERROR eliminando canal legacy: $e');
    }
  }

  Future<void> _requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) {
      debugPrint('[NotificationService] Android implementation es null');
      return;
    }

    try {
      final notifPermission = await androidImpl.requestNotificationsPermission();
      debugPrint('[NotificationService] Permiso notificaciones: $notifPermission');
      _permissionsGranted = notifPermission ?? false;
    } catch (e) {
      debugPrint('[NotificationService] ERROR pidiendo permiso de notificaciones: $e');
    }

    try {
      final exactAlarmPermission = await androidImpl.requestExactAlarmsPermission();
      debugPrint('[NotificationService] Permiso alarmas exactas: $exactAlarmPermission');
    } catch (e) {
      debugPrint('[NotificationService] ERROR pidiendo permiso de alarmas exactas: $e');
    }

    try {
      final fullScreenPermission = await androidImpl.requestFullScreenIntentPermission();
      debugPrint('[NotificationService] Permiso full-screen: $fullScreenPermission');
    } catch (e) {
      debugPrint('[NotificationService] ERROR pidiendo permiso full-screen: $e');
    }

    debugPrint('[NotificationService] Permisos totales concedidos: $_permissionsGranted');
  }

  Future<bool> checkPermissions() async {
    if (!_supported) return false;

    try {
      if (isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImpl =
            _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl == null) return false;

        final enabled = await androidImpl.areNotificationsEnabled();
        _permissionsGranted = enabled ?? false;
        debugPrint('[NotificationService] Verificación de permisos (sin diálogo): $_permissionsGranted');
        return _permissionsGranted;
      }
    } catch (e) {
      debugPrint('[NotificationService] ERROR verificando permisos: $e');
      return false;
    }

    return true;
  }

  Future<bool> requestPermissions() async {
    if (!_supported) return false;
    if (isAndroid) {
      await _requestAndroidPermissions();
    }
    return _permissionsGranted;
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Notificación recibida, payload: ${response.payload}');
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!);
      if (data['type'] == 'alarm') {
        onAlarmTriggered?.call(response.payload!);
      }
    } catch (e) {
      debugPrint('[NotificationService] Error decodificando payload: $e');
    }
  }

  String _buildPayload(Task task, int weekday) {
    return jsonEncode({
      'type': 'alarm',
      'taskId': task.id,
      'title': task.title,
      'weekday': weekday,
    });
  }

  Future<void> scheduleTask(Task task) async {
    debugPrint('[NotificationService] Programando tarea: ${task.title} (id=${task.id})');
    if (!_supported || task.id == null) {
      debugPrint('[NotificationService] No soportado o sin ID, cancelando');
      return;
    }

    // No borrar una posposición activa: ni su notificación ni su overlay.
    final keepSnooze = await snoozeDeadline(task.id!) != null;
    await cancelTask(task.id!, keepSnooze: keepSnooze);

    if (!task.hasValidDays) {
      debugPrint('[NotificationService] Sin días válidos, cancelando');
      return;
    }

    for (final weekday in task.weekdays) {
      final notificationId = task.id! * 10 + weekday;
      final scheduledDate = _nextInstanceOfWeekdayTime(weekday, task.hour, task.minute);

      debugPrint('[NotificationService] Notificación $notificationId programada para $scheduledDate (weekday=$weekday)');

      final androidDetails = AndroidNotificationDetails(
        alarmChannelId,
        alarmChannelName,
        channelDescription: alarmChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.alarm,
        playSound: false,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = _buildPayload(task, weekday);

      try {
        await _plugin.zonedSchedule(
          notificationId,
          task.title,
          'Es hora de: ${task.title}',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: task.repeats ? DateTimeComponents.dayOfWeekAndTime : null,
          payload: payload,
        );
        debugPrint('[NotificationService] Notificación $notificationId programada OK');

        await _scheduleOverlayAlarm(
          alarmId: notificationId,
          taskId: task.id!,
          title: task.title,
          weekday: weekday,
          repeats: task.repeats,
          triggerAt: scheduledDate,
        );
      } catch (e) {
        debugPrint('[NotificationService] ERROR programando notificación $notificationId: $e');
      }
    }
  }

  Future<void> _scheduleOverlayAlarm({
    required int alarmId,
    required int taskId,
    required String title,
    required int weekday,
    required bool repeats,
    required tz.TZDateTime triggerAt,
  }) async {
    if (!isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('scheduleOverlayAlarm', {
        'alarmId': alarmId,
        'taskId': taskId,
        'title': title,
        'weekday': weekday,
        'repeats': repeats,
        'triggerAt': triggerAt.millisecondsSinceEpoch,
      });
      debugPrint('[NotificationService] Overlay de alarma $alarmId programado');
    } catch (e) {
      debugPrint('[NotificationService] ERROR agendando overlay $alarmId: $e');
    }
  }

  Future<void> scheduleImmediate(String title, {int seconds = 10}) async {
    if (!_supported) return;

    debugPrint('[NotificationService] Programando prueba inmediata en $seconds segundos');

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    final androidDetails = AndroidNotificationDetails(
      alarmChannelId,
      alarmChannelName,
      channelDescription: alarmChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.alarm,
      playSound: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'alarm',
      'taskId': -1,
      'title': title,
      'weekday': DateTime.now().weekday,
    });

    try {
      await _plugin.zonedSchedule(
        99999,
        title,
        'Prueba de alarma: $title',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[NotificationService] Prueba programada OK');

      await _scheduleOverlayAlarm(
        alarmId: 99999,
        taskId: -1,
        title: title,
        weekday: DateTime.now().weekday,
        repeats: false,
        triggerAt: scheduledDate,
      );
    } catch (e) {
      debugPrint('[NotificationService] ERROR programando prueba: $e');
    }
  }

  Future<void> scheduleSnooze(Task task, int weekday) async {
    if (!_supported || task.id == null) return;

    final snoozeId = task.id! * 10 + weekday + 100000;
    final snoozeDate = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));

    debugPrint('[NotificationService] Posponiendo tarea ${task.title} a $snoozeDate');

    final androidDetails = AndroidNotificationDetails(
      alarmChannelId,
      alarmChannelName,
      channelDescription: alarmChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.alarm,
      playSound: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = _buildPayload(task, weekday);

    try {
      await _plugin.zonedSchedule(
        snoozeId,
        task.title,
        'Es hora de: ${task.title}',
        snoozeDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('[NotificationService] Posposición programada OK');

      await _scheduleOverlayAlarm(
        alarmId: snoozeId,
        taskId: task.id!,
        title: task.title,
        weekday: weekday,
        repeats: false,
        triggerAt: snoozeDate,
      );
      await setSnoozeDeadline(task.id!);
    } catch (e) {
      debugPrint('[NotificationService] ERROR programando posposición: $e');
    }
  }

  /// IDs de notificación/overlay de la tarea. Con [includeSnooze] false se
  /// excluyen los de posposición (`+100000`) para no borrar un snooze activo.
  static List<int> alarmIdsForTask(int taskId, {bool includeSnooze = true}) {
    final ids = <int>[];
    for (int weekday = 1; weekday <= 7; weekday++) {
      ids.add(taskId * 10 + weekday);
      if (includeSnooze) ids.add(taskId * 10 + weekday + 100000);
    }
    return ids;
  }

  Future<void> cancelTask(int taskId, {bool keepSnooze = false}) async {
    if (!_supported) return;
    for (final id in alarmIdsForTask(taskId, includeSnooze: !keepSnooze)) {
      await _plugin.cancel(id);
      if (isAndroid) {
        try {
          await _alarmChannel.invokeMethod('cancelOverlayAlarm', {
            'alarmId': id,
          });
        } catch (e) {
          debugPrint('[NotificationService] ERROR cancelando overlay: $e');
        }
      }
    }
  }

  /// Descarta la notificación de respaldo ya mostrada (solo Android).
  /// No toca las alarmas nativas (AlarmManager) ni otras programaciones.
  Future<void> dismissBackupNotification(int taskId, int weekday) async {
    if (!isAndroid) return;
    try {
      await _plugin.cancel(taskId * 10 + weekday);
    } catch (e) {
      debugPrint('[NotificationService] ERROR descartando respaldo: $e');
    }
  }

  static String _snoozeKey(int taskId) => 'snooze_deadline_$taskId';

  Future<DateTime?> snoozeDeadline(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_snoozeKey(taskId));
    if (ms == null) return null;
    final deadline = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    if (deadline.isBefore(DateTime.now().toUtc())) {
      // La posposición ya sonó: limpiar la marca al leerla.
      await prefs.remove(_snoozeKey(taskId));
      return null;
    }
    return deadline;
  }

  Future<void> setSnoozeDeadline(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeKey(taskId),
      DateTime.now().toUtc().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );
  }

  Future<void> clearSnoozeDeadline(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snoozeKey(taskId));
  }

  Future<String?> consumeLaunchPayload() async {
    if (!isAndroid) return null;
    try {
      return await _alarmChannel.invokeMethod<String>('consumeLaunchPayload');
    } catch (e) {
      debugPrint('[NotificationService] ERROR leyendo payload de lanzamiento: $e');
      return null;
    }
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('[NotificationService] ERROR en getNotificationAppLaunchDetails: $e');
      return null;
    }
  }

  Future<bool> canDrawOverlays() async {
    if (!isAndroid) return true;
    try {
      return await _alarmChannel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (e) {
      debugPrint('[NotificationService] ERROR comprobando overlays: $e');
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    if (!isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('openOverlaySettings');
    } catch (e) {
      debugPrint('[NotificationService] ERROR abriendo ajustes de overlay: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isAndroid) return true;
    try {
      return await _alarmChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (e) {
      debugPrint('[NotificationService] ERROR comprobando batería: $e');
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('[NotificationService] ERROR abriendo ajustes de batería: $e');
    }
  }

  Future<void> returnToPreviousApp() async {
    if (!isAndroid) return;
    try {
      await _alarmChannel.invokeMethod('returnToPreviousApp');
    } catch (e) {
      debugPrint('[NotificationService] ERROR volviendo a la app anterior: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError('weekday debe estar entre 1 y 7, se recibió: $weekday');
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
