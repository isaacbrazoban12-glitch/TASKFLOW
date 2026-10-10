# BUG_REPORT — TASKFLOW

> Regla de sesión: solo se arregla lo que está en la lista del usuario.
> Todo bug/riesgo fuera de la lista se anota aquí y NO se arregla.
> (Formato final del prompt aún no recibido: uso formato provisional
> `Fecha | Archivo | Hallazgo | Evidencia | Severidad`.)

## Hallazgos (no arreglados)

### 1. `setSnoozeDeadline` nunca se llama — chequeo de snooze muerto
- Fecha: 2026-10-10
- Archivo: `taskflow/lib/notification_service.dart`, `taskflow/lib/main.dart:105`
- Hallazgo: `setSnoozeDeadline()` está definido pero no tiene ningún call-site
  (grep solo devuelve definición + `snoozeDeadline` + `clearSnoozeDeadline`).
  Por tanto `snoozeDeadline()` siempre devuelve `null` y el `continue` por
  "snooze activo" en `_rescheduleAllTasks()` es código muerto.
- Evidencia: `grep snoozeDeadline|setSnoozeDeadline|clearSnoozeDeadline` → 5 matches,
  ninguno es una llamada a `setSnoozeDeadline`; `flutter test` pasa igual.
- Severidad: media (posible re-agendado indebido tras posponer).

### 2. Riesgo residual del fix alarm_action: evento de canal perdido si Dart no está listo
- Fecha: 2026-10-10
- Archivo: `taskflow/android/app/src/main/kotlin/com/example/taskflow/MainActivity.kt` (`onNewIntent`),
  `taskflow/lib/notification_service.dart` (`setMethodCallHandler`), `taskflow/lib/main.dart` (`onAlarmAction`)
- Hallazgo: con el fix, `onNewIntent` ya no guarda `launchPayload` y solo emite
  `onAlarmAction` por el canal. Si el engine existe pero el handler Dart aún no
  está registrado (`onAlarmAction == null`, p. ej. HomePage aún no hizo
  `_setupAlarmListener`), la acción se pierde sin fallback.
- Evidencia: inspección de código; no observado en ejecución (sin dispositivo).
- Severidad: baja/media. No se arregla (fuera de la lista); queda como riesgo conocido.

### 3. `onNewIntent` no llama a `setIntent(intent)`
- Fecha: 2026-10-10
- Archivo: `taskflow/android/app/src/main/kotlin/com/example/taskflow/MainActivity.kt`
- Hallazgo: práctica estándar en `singleTop` no aplicada; `getIntent()` queda
  con el intent viejo. Hoy no rompe nada porque se usa el parámetro `intent`
  y el `launchPayload` estático, pero es riesgo de confusión futura.
- Evidencia: lectura de `MainActivity.kt`; `AndroidManifest.xml` confirma
  `launchMode="singleTop"`.
- Severidad: baja.

### 4. Tests hacen pump directo sin `main()` → logs de error aunque pasan
- Fecha: 2026-10-10
- Archivo: `taskflow/test/widget_test.dart`
- Hallazgo: `flutter test` pasa 2/2, pero cada test loguea
  `LateInitializationError` en `getNotificationAppLaunchDetails` y
  `Bad state: databaseFactory not initialized`. Ocurre porque el test construye
  `TaskFlowApp()` sin pasar por `main()` (sin `sqfliteFfiInit` ni `init()` del plugin).
- Evidencia: salida de `flutter test` del 2026-10-10.
- Severidad: baja (ruido en tests, no fallo).

### 5. Canal de notificación Android inmutable: el cambio a respaldo silencioso puede no aplicar a usuarios existentes
- Fecha: 2026-10-10
- Archivo: `taskflow/lib/notification_service.dart` (`alarmChannelId = 'taskflow_alarms'`)
- Hallazgo: en Android 8+, sonido/importancia/vibración son propiedades del canal,
  no de cada notificación. Al mantener el mismo `channelId` y solo cambiar
  `fullScreenIntent`/`playSound` por notificación, los dispositivos que ya crearon
  el canal `taskflow_alarms` con sonido podrían seguir sonando hasta que el usuario
  borre datos o reinstale. Requeriría migrar a un nuevo `channelId` (fuera de la lista).
- Evidencia: inspección de código; `fullScreenIntent` sí es por-notificación y aplica
  de inmediato; el sonido depende del canal ya creado en el dispositivo.
- Severidad: media/baja. No se arregla; queda como riesgo conocido.

### 6. Alarma nativa repetitiva es one-shot sin re-agendado al disparar
- Fecha: 2026-10-10
- Archivo: `taskflow/android/app/src/main/kotlin/com/example/taskflow/AlarmLaunchReceiver.kt`,
  `taskflow/android/app/src/main/kotlin/com/example/taskflow/NativeAlarmHelper.kt`
- Hallazgo: `setAlarmClock` es one-shot y `AlarmLaunchReceiver.onReceive` solo lanza
  `AlarmActivity` sin re-agendar la siguiente ocurrencia. La nativa solo se re-arme al
  abrir la app (`_rescheduleAllTasks`) o al reiniciar (boot receiver). Si el usuario no
  abre la app entre semanas, la alarma nativa de una tarea repetitiva podría no sonar
  la semana siguiente (antes la notificación con `matchDateTimeComponents` repetía sola).
  Relevante ahora que la nativa es la única pantalla de alarma en Android.
- Evidencia: lectura de `AlarmLaunchReceiver.kt` (sin re-agendado) y grep de
  `_rescheduleAllTasks` (solo se llama al iniciar la app).
- Severidad: media/alta. No se arregla (fuera de la lista).

## Decisiones tomadas

### D1. Fix alarm_action (2026-10-10) — entrega única por canal, sin idempotencia Dart
- Contexto: `_checkLaunchPayload` ignoraba `type == 'alarm_action'` (acción perdida
  en arranque en frío); `onNewIntent` guardaba `launchPayload` Y emitía por el canal
  (riesgo de doble aplicación al combinar con el fix anterior).
- Opciones: (a) no guardar `launchPayload` en `onNewIntent`, solo canal;
  (b) guardar + deduplicar en Dart (set de payloads procesados).
- Decisión: opción (a), la más simple y la sugerida en el enunciado.
  - Frío (app cerrada): `onCreate` guarda `launchPayload` → `_checkLaunchPayload`
    lo consume y aplica. Sin evento de canal. Una sola aplicación.
  - Segundo plano / abierta: `onNewIntent` solo emite `onAlarmAction` →
    handler aplica; `_checkLaunchPayload` en `resumed` consume `null`. Una sola aplicación.
- Consecuencia conocida: ver hallazgo 2 (pérdida si Dart no está listo).

### D2. Alarma única nativa en Android (2026-10-10) — notificación como respaldo silencioso
- Contexto: cada tarea programaba notificación con `fullScreenIntent` + sonido Y alarma
  nativa (`AlarmManager` → `AlarmActivity`): doble pantalla (`AlarmDialog` + `AlarmActivity`).
- Cambios:
  - `notification_service.dart`: los 3 bloques `AndroidNotificationDetails`
    (`scheduleTask`, `scheduleImmediate`, `scheduleSnooze`) pasan a
    `fullScreenIntent: false, playSound: false`. Solo tocan Android por construcción
    (`DarwinNotificationDetails` intacto; escritorio sale por `_supported == false`).
    Se mantiene `importance/priority`/vibración para que siga visible.
  - `main.dart` (`_showAlarmDialog`): retorno temprano si `Platform.isAndroid`, en un
    solo punto en vez de tocar los 3 orígenes (`_checkLaunchPayload`, `_checkInitialAlarm`,
    `onAlarmTriggered`). Al tocar la notificación solo se abre la app.
  - Nuevo `dismissBackupNotification(taskId, weekday)` (solo Android; cancela solo el id
    `taskId*10+weekday`, sin tocar overlays ni otras programaciones) llamado al inicio de
    `_completeTaskFromAlarm` (nuevo parámetro `weekday`, 3 call-sites actualizados) y
    `_snoozeTaskFromAlarm` (el snooze usa id distinto `+100000`, sin conflicto).
- Qué se dejó de usar y código muerto:
  - `AlarmDialog` (`lib/widgets/alarm_dialog.dart` + `_showAlarmDialog`): sin uso en Android;
    SIGUE VIVO en iOS/escritorio (no es código muerto, no se borra).
  - `launchAlarmActivity` (canal `MainActivity` + `NotificationService.launchAlarmActivity`):
    YA estaba muerto antes del cambio (ningún caller Dart; la vía real es `AlarmManager`).
    Sigue muerto; NO se borra (limpieza fuera de la lista).
  - Rama `type == 'alarm'` en `_checkLaunchPayload`: sin productor en Android
    (`EXTRA_PAYLOAD` solo lleva `alarm_action`); queda como fallback defensivo.
- Consecuencias conocidas: ver hallazgos 5 (canal existente con sonido) y 6 (repetitiva
  nativa sin re-agendado al disparar).
