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
- Nota 2026-10-10: pasó a la lista del usuario y se arregla en D3; se deja constancia.

### 7. PendingIntents creados antes del fix no llevan `repeats`/`triggerAt` (transitorio)
- Fecha: 2026-10-10
- Archivo: `taskflow/android/app/src/main/kotlin/com/example/taskflow/AlarmLaunchReceiver.kt`
- Hallazgo: los extras `EXTRA_REPEATS`/`EXTRA_TRIGGER_AT` solo existen en intents
  creados tras D3. Si una alarma repetitiva agendada ANTES del update dispara ANTES de
  que la app se abra (y re-arme vía `_rescheduleAllTasks` o boot), el receiver lee
  `repeats=false` por defecto y eliminaría su persistencia en vez de reprogramarla.
  Se autocorrige en cuanto la app se abre o el dispositivo reinicia.
- Evidencia: inspección de código (defaults `getBooleanExtra(..., false)`).
- Severidad: baja/transitoria. No se arregla (requeriría lectura de respaldo en prefs;
  fuera de la lista).

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

### D3. Re-arme semanal nativo (2026-10-10) — resuelve hallazgo 6
- Contexto: `setAlarmClock` es one-shot y el receiver no re-agendaba: las repetitivas
  morían hasta abrir la app.
- Cambios (solo Kotlin, Dart intacto):
  - `MainActivity`: nuevos extras `EXTRA_REPEATS` / `EXTRA_TRIGGER_AT`.
  - `NativeAlarmHelper.scheduleAlarm`: los propaga al `PendingIntent` (el lookup de
    `cancelAlarm` no se ve afectado: `filterEquals` ignora extras).
  - Nuevo `rescheduleNextWeek(...)`: si `repeats==false` elimina el persistido
    (`removeAlarm`, ahora pública) y devuelve null; si true agenda `triggerAt + 7d`
    vía `scheduleAlarm` (que re-persiste el nuevo `triggerAt`) con guarda `while (next <= now)`
    para entregas tardías, y devuelve el próximo trigger.
  - `AlarmLaunchReceiver.onReceive`: re-arme ANTES de lanzar `AlarmActivity` (aunque el
    lanzamiento falle, la próxima semana queda armada), con logs en ambos casos.
- Verificación pedida en el enunciado:
  - `restoreAlarmsAfterBoot` NO se tocó (ver diff): sigue leyendo `repeats`/`triggerAt`
    del persistido; con el re-arme semanal el `triggerAt` persistido siempre es fresco.
  - Mapeo `nextWeekdayTime`: `(weekday % 7) + 1` verificado para los 7 días
    (Dart 1=Lun→Cal 2 … 6=Sáb→7, 7=Dom→1). Correcto.
  - Snooze (`repeats=false`, id `+100000`) y prueba (`99999`) se limpian al disparar. Correcto.
- Simulación del paso de una semana (sin JVM/adb en este entorno; réplica exacta de la
  aritmética en PowerShell): disparo normal Lun 12/10 08:30 → Lun 19/10 08:30 (mismo día
  y hora); entrega tardía con `now = trigger+16d` → 2 saltos → Lun 02/11 08:30 futuro;
  réplica de `nextWeekdayTime` (mié→lun 19, lun 7h→hoy, lun 9h→+7) OK. `flutter analyze`
  limpio; `flutter test` 2/2 OK.
- Consecuencia conocida: ver hallazgo 7 (intents pre-fix sin extras, transitorio).

### D4. Completitud por ocurrencia (2026-10-10) — `completedAt` + BD v2
- Contexto: `completed=true` era permanente y `_rescheduleAllTasks` cancelaba todo lo
  completado al abrir la app: una semanal completada una vez dejaba de sonar.
- Cambios (mínimos, sin refactor visual):
  - `Task`: nuevo `completedAt` (ms época, null). `completed` conserva su significado de
    "detenida para siempre". Nuevos puros y testeados: `stopsOnComplete`, `isStopped`,
    `lastOccurrenceBeforeOrAt(now)` (convención Dart 1=Lun…7=Dom) e
    `isEffectivelyCompleted(now)` (detenida→true; repetitiva sin stop→true solo si la
    marca cubre la última ocurrencia, reinicio natural al llegar la siguiente).
    `copyWith` gana `clearCompletedAt`; `toMap`/`fromMap` incluyen la columna
    (`fromMap` tolera filas sin la clave).
  - BD v2 con `onUpgrade` que conserva datos: `ADD COLUMN completedAt` + convierte filas
    legacy (`repeats=1, stop=0, completed=1`) a `completed=0, completedAt=ahora`.
  - `_applyCompletion`: repetitiva sin stop al completar → marca fecha + re-agenda
    (futuras siguen activas); stop → `completed=true` + cancela; al desmarcar → limpia
    marca y agenda siempre (antes solo si `stopsWhenComplete`; agendar de más es
    idempotente porque `scheduleTask` cancela primero).
  - `_rescheduleAllTasks`: `isStopped → cancel`, si no → `schedule`. Se elimina la rama
    de `snoozeDeadline` (muerta según hallazgo 1: `setSnoozeDeadline` sin callers; los
    métodos se conservan).
  - `TaskTile`: muestra/tacha con el estado efectivo (sin cambiar su API).
    `_toggleTask` invierte el estado efectivo.
  - `TaskFormDialog`: si lo guardado está detenido → `cancelTask`, si no → `scheduleTask`
    (antes siempre agendaba y reactivaba detenidas).
- Tests: nuevo `test/task_test.dart` (17 casos: serialización/legacy/copyWith,
  stops/isStopped, última ocurrencia, efectivo incl. reinicio y borde exacto).
  `flutter analyze` limpio; `flutter test` 19/19 OK.
- Sin hallazgos nuevos en este problema.

### D5. Marca de snooze viva (2026-10-10) — resuelve hallazgo 1
- Contexto: `setSnoozeDeadline` nunca se llamaba → `snoozeDeadline` siempre null →
  `scheduleTask` (vía `cancelTask`) borraba posposiciones pendientes (`+100000`,
  notificación y overlay) al abrir la app o editar.
- Cambios (mínimos):
  - `scheduleSnooze`: llama a `setSnoozeDeadline` tras programar (notificación + overlay).
  - `cancelTask(taskId, {keepSnooze=false})` + `alarmIdsForTask(includeSnooze)` pura y
    testeada: con `keepSnooze` se conservan los ids `+100000` (flutter y overlay).
    Ruta por defecto idéntica a antes (mismo orden e ids).
  - `scheduleTask`: `keepSnooze = (await snoozeDeadline(task.id!) != null)`. Protege
    también la vía edición (`TaskFormDialog`) y desmarcar. Vale en iOS igual (mismo bug
    latente en sus ids `+100000`; el overlay solo existe en Android).
  - `_rescheduleAllTasks`: con snooze activo omite el re-agendado de esa tarea
    (rama revivida de D4, ahora con setter real).
  - `snoozeDeadline`: autolimpia la marca vencida al leerla ("ya sonó"). Al completar
    ya se limpiaba en ambas ramas de `_applyCompletion` (verificado, sin cambios).
- Tests: nuevo `test/snooze_test.dart` (6 casos: ids con/sin snooze, marca ~+5min,
  vencida→null+clave eliminada, sin marca, clear). `flutter analyze` limpio;
  `flutter test` 25/25 OK.
- Nota: la marca es por tarea (no por weekday); el skip en `_rescheduleAllTasks` dura
  como máximo los 5 min del snooze. Sin hallazgos nuevos.

### D6. Clave de contador unificada (2026-10-10)
- Contexto: Dart generaba `…_2026_10_9` y Kotlin `…_2026_10_09`: en días/meses < 10
  eran claves distintas y el límite de 3 posposiciones se saltaba; además Dart leía
  caché vieja frente a escrituras Kotlin.
- Cambios (mínimos):
  - `AlarmDialog`: `dateSuffix` (año_mes_día con dos dígitos) + `snoozeKey` público
    con el mismo formato que Kotlin; `_prefsKey` delega con `DateTime.now()`.
  - `AlarmActivity.getCurrentYearMonthDay`: `Locale.getDefault()` → `Locale.US` en los
    tres formatos (dígitos latinos siempre). El formato de hora en pantalla no se toca.
  - `getSnoozeCount`: `await prefs.reload()` antes de leer.
  - Nuevo `clearStaleSnoozeCounts` (borra `alarm_dismiss_*` de días anteriores,
    conserva hoy y el resto) llamado en `_checkPermissionsAndAlarm` al iniciar.
    Limpia también entradas escritas por Kotlin (mismo store; el plugin antepone
    `flutter.` en Android de forma transparente).
- Tests: nuevo `test/snooze_key_test.dart` (5 casos: padding del bug, contrato con
  literales de clave Kotlin, formato regex, lectura tras reload, limpieza conserva
  hoy/otros y borra ayer). Kotlin no ejecutable aquí: el contrato se verifica por
  inspección (mismo patrón `yyyy_MM_dd`, `Locale.US`) + literales en el test.
  `flutter analyze` limpio; `flutter test` 30/30 OK.
- Sin hallazgos nuevos.

### D9. Limpieza de código muerto (2026-10-10)
- Eliminado `launchAlarmActivity`: método Dart en `NotificationService`, rama del
  canal y `private fun` en `MainActivity` (sin callers; la vía real es `AlarmManager`).
  Verificado con grep: 0 referencias restantes. Actualiza D2 (ya no queda muerto).
- Eliminado `import android.provider.Settings` sin usar en `AlarmLaunchReceiver.kt`.
- `flutter analyze` sin issues (incl. el `unnecessary_brace_in_string_interps` que
  introdujo el cambio a `platform_info` en P1, ya corregido).
- Sin hallazgos nuevos.

### D10. Widget tests con BD mockeada (2026-10-10)
- Contexto: `sqflite_common_ffi` en `testWidgets` cuelga este entorno (las operaciones
  completan pero el test no termina ni con `runAsync`; en `test` plano sí funciona).
- Decisión: `FakeDatabaseHelper` en memoria + seam mínimo (`DatabaseHelper.test()` e
  `instance` reasignable, ambos `@visibleForTesting`); `widget_test.dart` con 4 casos
  (render, vacío, lista desde BD, checkbox→tachado). `flutter analyze` limpio;
  `flutter test` 32/32 OK.
- Sin hallazgos nuevos (el cuelgue FFI/widgets queda como limitación del entorno,
  no de la app).

### D7. Web no se rompe (2026-10-10)
- Contexto: `import 'dart:io'` en `main.dart` y `notification_service.dart` impedía
  compilar a web; además `sqflite_common_ffi` (dart:ffi) tampoco compila en navegador.
- Decisión (opción "aviso claro", no desactivar web): shims con import condicional
  (`platform_info*.dart`, `db_ffi*.dart`), `DatabaseHelper` lanza `StateError` claro
  en web (llega al SnackBar existente) y `HomePage` muestra aviso fijo arriba.
  Notificaciones en web ya eran no-op (`_supported` false). Verificado con
  `flutter build web` (compila OK). `flutter analyze` limpio; `flutter test` 30/30.

### D8. Escritorio sin alarmas: aviso en app (2026-10-10)
- Contexto: `NotificationService` es no-op fuera de Android/iOS.
- Decisión (opción más simple): NO implementar notificaciones de escritorio
  (alarmas exactas y full-screen no existen ahí de forma fiable; demasiado grande).
  Se reutiliza el aviso de D7: en escritorio la app muestra "no hay alarmas del
  sistema; funciona como lista de tareas" y la limitación queda en el README.
  `flutter analyze` limpio; `flutter test` 30/30.
