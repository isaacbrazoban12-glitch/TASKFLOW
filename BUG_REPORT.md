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
