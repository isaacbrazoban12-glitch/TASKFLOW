# BUG_REPORT — TASKFLOW

## Resumen

1. Arreglado: acción `alarm_action` perdida en arranque en frío, doble aplicación por canal+payload, doble pantalla de alarma (notificación silenciosa ahora), re-arme semanal nativo, completitud por ocurrencia con BD v2, marca de snooze viva, clave de contador unificada Dart/Kotlin, compilación web, aviso en escritorio, código muerto y README/tests.
2. Pendiente: 6 hallazgos de riesgo medio-bajo (canal perdido si Dart no está listo, canal de notificación inmutable en equipos ya instalados, `setIntent` ausente, ruido en logs de tests, intents pre-fix transitorios, hora congelada en alarma).
3. Nivel de riesgo general: **medio** — lo funcional está cubierto y verificado; el riesgo restante es no haber probado en dispositivo real (alarmas exactas, boot, ahorro de batería agresivo) y la revisión de permisos en Google Play.
4. Verificación final: `flutter analyze` sin issues y `flutter test` 32/32 (salida pegada al final).
5. Regla de sesión aplicada: solo se arregló lo de la lista del usuario; el resto está aquí con sugerencia.

## Hallazgos

### BUG-01 — `setSnoozeDeadline` nunca se llamaba
- ID | Severidad | Estado: **BUG-01 | media | arreglado**
- Archivo y línea: `taskflow/lib/notification_service.dart:406` (`scheduleSnooze` → `setSnoozeDeadline`)
- Cómo reproducirlo: posponer una alarma, matar la app y reabrirla antes de los 5 min; antes del fix la posposición desaparecía (test: `test/snooze_test.dart`).
- Esperado vs. real: esperado = la marca existe y el snooze sobrevive al re-agendado; real = `snoozeDeadline()` siempre null y `cancelTask` borraba los ids `+100000`.
- Cómo se arregló: setter llamado en `scheduleSnooze`; `cancelTask(keepSnooze)` + `scheduleTask` que conserva snooze activo; `_rescheduleAllTasks` omite con snooze activo; autolimpieza al vencer (D5).

### BUG-02 — Evento de canal perdido si Dart no está listo
- ID | Severidad | Estado: **BUG-02 | media | pendiente**
- Archivo y línea: `taskflow/android/app/src/main/kotlin/com/example/taskflow/MainActivity.kt:68` (`onNewIntent`)
- Cómo reproducirlo: con la app en memoria pero `HomePage` aún sin `_setupAlarmListener`, pulsar Completar/Posponer en `AlarmActivity`; el `invokeMethod("onAlarmAction")` llega a `onAlarmAction == null` y se pierde (solo inspección de código, sin dispositivo).
- Esperado vs. real: esperado = la acción nunca se pierde; real = sin fallback (ya no se guarda `launchPayload` en ese camino, D1).
- Qué se sugiere: cola de un elemento en nativo con reintento, o apretón Dart→nativo de "listo" antes de emitir; fuera de la lista, no tocado.

### BUG-03 — `onNewIntent` no llama a `setIntent(intent)`
- ID | Severidad | Estado: **BUG-03 | baja | pendiente**
- Archivo y línea: `taskflow/android/app/src/main/kotlin/com/example/taskflow/MainActivity.kt:68`
- Cómo reproducirlo: inspección (`launchMode="singleTop"` en `AndroidManifest.xml`); `getIntent()` devuelve el intent viejo.
- Esperado vs. real: esperado = intent actualizado según práctica estándar; real = no rompe hoy (se usa el parámetro y `launchPayload` estático), riesgo de confusión futura.
- Qué se sugiere: añadir `setIntent(intent)`; cambio de 1 línea, fuera de la lista.

### BUG-04 — Tests con logs de error aunque pasan
- ID | Severidad | Estado: **BUG-04 | baja | pendiente**
- Archivo y línea: `taskflow/test/widget_test.dart` (pump directo de `TaskFlowApp` sin `main()`)
- Cómo reproducirlo: `flutter test` → `LateInitializationError` en `getNotificationAppLaunchDetails` (el plugin no se inicializa en tests).
- Esperado vs. real: esperado = logs limpios; real = ruido capturado por try/catch, tests en verde. La parte de BD ya se mitigó con `FakeDatabaseHelper` (D10).
- Qué se sugiere: inicializar o mockear el plugin en `setUpAll`; fuera de la lista.

### BUG-05 — Canal `taskflow_alarms` inmutable en equipos ya instalados
- ID | Severidad | Estado: **BUG-05 | media | pendiente**
- Archivo y línea: `taskflow/lib/notification_service.dart:20` (`alarmChannelId`)
- Cómo reproducirlo: instalar versión con sonido, actualizar a la versión silenciosa (D2) y disparar una alarma: en Android 8+ el sonido puede persistir porque es propiedad del canal ya creado.
- Esperado vs. real: esperado = respaldo siempre silencioso; real = `fullScreenIntent` aplica al momento, el sonido depende del canal existente.
- Qué se sugiere: migrar a un nuevo `channelId`; fuera de la lista.

### BUG-06 — Nativa repetitiva one-shot sin re-agendado
- ID | Severidad | Estado: **BUG-06 | alta | arreglado**
- Archivo y línea: `taskflow/android/app/src/main/kotlin/com/example/taskflow/AlarmLaunchReceiver.kt:15` + `NativeAlarmHelper.kt` (`rescheduleNextWeek`)
- Cómo reproducirlo: tarea repetitiva sin abrir la app entre semanas; antes del fix la segunda semana no sonaba (verificado por simulación de la aritmética +7 días y casos de entrega tardía).
- Esperado vs. real: esperado = suena cada semana; real = `setAlarmClock` one-shot consumido sin re-arme.
- Cómo se arregló: `rescheduleNextWeek` (+7 días, guarda anti-pasado, limpia no-repetitivas) llamado antes de lanzar `AlarmActivity`; extras `EXTRA_REPEATS`/`EXTRA_TRIGGER_AT`; `restoreAlarmsAfterBoot` y mapeo `(weekday % 7)+1` verificados 7/7 (D3).

### BUG-07 — Intents pre-fix sin extras (transitorio)
- ID | Severidad | Estado: **BUG-07 | baja | pendiente**
- Archivo y línea: `taskflow/android/app/src/main/kotlin/com/example/taskflow/AlarmLaunchReceiver.kt:15` (`getBooleanExtra(..., false)`)
- Cómo reproducirlo: alarma agendada antes de D3 que dispare antes de abrir la app o reiniciar: `repeats` lee `false` y se elimina su persistencia en vez de reprogramarse.
- Esperado vs. real: esperado = re-arme correcto; real = se autocorrige al abrir la app o reiniciar (transitorio).
- Qué se sugiere: lectura de respaldo en prefs si falta el extra; fuera de la lista.

### BUG-08 — Hora congelada en la pantalla de alarma
- ID | Severidad | Estado: **BUG-08 | baja | pendiente**
- Archivo y línea: `taskflow/lib/widgets/alarm_dialog.dart:89` (`_updateTime` solo en `initState`); `AlarmActivity.kt:43` (`tvTime` solo en `onCreate`)
- Cómo reproducirlo: dejar la pantalla de alarma abierta: la hora no avanza.
- Esperado vs. real: esperado = reloj en vivo; real = hora fija de apertura (detectado en auditoría visual).
- Qué se sugiere: ticker de 1 min en Dart y `Handler` en Kotlin; fuera de la lista.

## Google Play — permisos sensibles (revisión pedida, sin cambios)

Se revisa `taskflow/android/app/src/main/AndroidManifest.xml`. NO se quita ningún
permiso: son el núcleo de las alarmas.

1. `SYSTEM_ALERT_WINDOW` (especial, riesgo alto): overlay de `AlarmActivity`; Play exige justificarlo (alarma = función principal, revisión manual).
2. `USE_EXACT_ALARM` (sistema/elegibles, riesgo alto): reservada; para terceros Play espera `SCHEDULE_EXACT_ALARM` con declaración; tener ambas puede provocar rechazo.
3. `SCHEDULE_EXACT_ALARM` (especial, riesgo medio): alarmas exactas + snooze; requiere declaración ("alarma" es caso aceptado).
4. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (riesgo medio): restringida salvo función principal afectada (aquí sí), con declaración.
5. `USE_FULL_SCREEN_INTENT` (especial, riesgo medio-bajo): ya no se usa full-screen (D2) pero sigue declarado; somos alarma (aceptable), candidato a quitar en el futuro.

Sin riesgo especial: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `WAKE_LOCK`.
Recomendación: rellenar en Play Console la declaración de alarmas exactas y el
formulario de permisos especiales antes de subir el AAB.

## Decisiones tomadas

### D1. `alarm_action` con entrega única por canal (2026-10-10)
Frío: `onCreate` guarda `launchPayload` → `_checkLaunchPayload` lo consume y aplica.
Segundo plano/abierta: `onNewIntent` solo emite `onAlarmAction`. Una sola aplicación.
Consecuencia: BUG-02.

### D2. Alarma única nativa en Android (2026-10-10)
Notificación como respaldo silencioso (`fullScreenIntent: false, playSound: false` en
los 3 bloques Android); `_showAlarmDialog` retorna en Android (abrir app al tocar);
`dismissBackupNotification` al completar/posponer. `AlarmDialog` sigue vivo en
iOS/escritorio; `launchAlarmActivity` se eliminó después (D9). Consecuencias:
BUG-05 y BUG-06 (resuelto en D3).

### D3. Re-arme semanal nativo (2026-10-10)
`rescheduleNextWeek` (+7 días, guarda anti-pasado, limpia no-repetitivas) antes de
lanzar `AlarmActivity`; extras en el `PendingIntent`; `restoreAlarmsAfterBoot` intacto
y mapeo verificado 7/7. Resuelve BUG-06. Consecuencia: BUG-07.

### D4. Completitud por ocurrencia + BD v2 (2026-10-10)
`completed` = detenida; `completedAt` = ocurrencia (`stopsOnComplete`, `isStopped`,
`lastOccurrenceBeforeOrAt`, `isEffectivelyCompleted`); `onUpgrade` conserva datos y
convierte legacy; `_rescheduleAllTasks`/`_applyCompletion`/tile/form coherentes.
17 tests en `test/task_test.dart`.

### D5. Marca de snooze viva (2026-10-10)
Setter en `scheduleSnooze`; `cancelTask(keepSnooze)`; skip en `_rescheduleAllTasks`;
autolimpieza al vencer. Resuelve BUG-01. 6 tests en `test/snooze_test.dart`.

### D6. Clave de contador unificada (2026-10-10)
`dateSuffix`/`snoozeKey` con dos dígitos + `Locale.US` en Kotlin; `reload()` antes de
leer; limpieza de claves viejas al iniciar. 5 tests en `test/snooze_key_test.dart`.

### D7. Web no se rompe (2026-10-10)
Shims con import condicional (`platform_info`, `db_ffi`); `StateError` claro en BD web
y aviso fijo en `HomePage`. Verificado con `flutter build web`. Opción "aviso claro".

### D8. Escritorio sin alarmas (2026-10-10)
No se implementan notificaciones de escritorio (demasiado grande, sin exactas
fiables); aviso en app + limitación en README.

### D9. Limpieza de código muerto (2026-10-10)
Eliminado `launchAlarmActivity` (0 referencias) e import sin usar en Kotlin.

### D10. Widget tests con BD mockeada (2026-10-10)
`FakeDatabaseHelper` + seam `@visibleForTesting` (FFI cuelga `testWidgets` en este
entorno); 4 casos en `widget_test.dart`.

## Cosas que no pude probar

- Dispositivo Android real: disparo exacto, `AlarmActivity` sobre bloqueo, toque de
  la notificación de respaldo, arranque en frío real y los 3 casos de `alarm_action`.
- `BOOT_COMPLETED` y restauración tras reinicio en equipo real.
- Fabricantes con ahorro agresivo (Xiaomi/Huawei/Oppo): exención de batería y
  `setAlarmClock` bajo Doze.
- Ventana real posponer→2 min→suena a los 5 (solo cubierta con tests deterministas).
- Comportamiento en iOS (sin dispositivo Apple) y resultado de la revisión de Play.
- Reloj en vivo de alarma y `AlarmDialog` a 150 % en pantalla pequeña.

## Siguiente paso recomendado

1. Probar en un Android físico el checklist (frío/fondo/abierta, snooze 2→5 min,
   reinicio, semana siguiente sin abrir la app) con `logcat -s AlarmLaunchReceiver`.
2. Rellenar declaraciones de Play (exactas + especiales) antes del AAB.
3. Aplicar el backlog visual (`docs/VISUAL_AUDIT.md`): contraste del botón Completar
   (2.78:1), quitar "Probar notificación" en release, agrupar por día, Semantics.
4. Migrar `channelId` si hay base instalada con sonido (BUG-05) y quitar
   `USE_EXACT_ALARM`/`USE_FULL_SCREEN_INTENT` si Play los cuestiona.

## Verificación final (2026-10-10, `taskflow/`)

`flutter analyze`:
```
Analyzing taskflow...
No issues found! (ran in 1.8s)
```

`flutter test` (32/32):
- `test/snooze_key_test.dart`: 5/5 (clave multiplataforma, reload, limpieza)
- `test/snooze_test.dart`: 6/6 (ids con/sin snooze, marca ±5 min, vencida→null+limpia, clear)
- `test/task_test.dart`: 17/17 (serialización/legacy, stops, ocurrencia, efectivo+reinicio)
- `test/widget_test.dart`: 4/4 (render, vacío, lista desde BD, checkbox→tachado)
- Resultado: `All tests passed!`
- Nota: los widget tests loguean `LateInitializationError` en
  `getNotificationAppLaunchDetails` (plugin sin inicializar en tests, capturado) y
  `Permisos concedidos: false`; es ruido (BUG-04), no fallo.
