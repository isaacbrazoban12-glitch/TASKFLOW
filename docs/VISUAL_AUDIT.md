# Auditoría visual — TaskFlow (2026-10-10)

Solo observación y documentación. **No se cambió código de interfaz.**

## Método y limitaciones honestas

- Sin emulador Android ni adb en este entorno (solo Windows/Chrome).
- Capturas generadas headless con `flutter test --update-goldens` (widgets reales,
  superficie 800×600, BD mockeada, fuente Arial del sistema en lugar de Roboto).
- Los iconos Material salen como cajas vacías en las capturas (la fuente de iconos
  no carga en tests); en dispositivo son normales. La cinta DEBUG es artefacto del
  build de pruebas (`debugShowCheckedModeBanner: false` ya está en la app).
- **No capturado, analizado desde código:** `AlarmActivity` nativa
  (`activity_alarm.xml`) y los cuadros de permisos (ramas solo-Android de `main.dart`).
- Ficheros: `docs/screens/01-empty-light.png` … `08-list-scale150-light.png`.

| # | Captura | Estado |
|---|---|---|
| 1 | `01-empty-light.png` | Lista vacía, claro |
| 2 | `02-list-light.png` | 6 tareas (2 completadas), claro |
| 3 | `03-new-form-light.png` | Formulario nueva tarea |
| 4 | `04-edit-form-light.png` | Formulario edición (Gimnasio, Mar+Jue) |
| 5 | `05-alarm-dialog-light.png` | AlarmDialog |
| 6 | `06-list-dark.png` | Lista, oscuro |
| 7 | `07-alarm-dialog-dark.png` | AlarmDialog, oscuro (idéntico: siempre oscuro) |
| 8 | `08-list-scale150-light.png` | Lista, fuente al 150 % |

## 1. Jerarquía, espaciado, tipografía

- Lista: AppBar (`Mis Tareas`, 3 iconos) → aviso de plataforma → cards con título
  (16sp aprox.) + subtítulo día·hora + checkbox/borrar a la derecha. Jerarquía clara.
- Espaciado consistente: padding 12 en lista, separadores de 8, cards de 72dp de alto.
- Tipografía del sistema M3 (Roboto en dispositivo); sizes razonables. El subtítulo
  `Lun, Mié, Vie · 10:00 PM` es denso pero legible.
- Formulario: título + campo + chips de días (wrap, spacing 8) + hora + 2 switches +
  Cancelar/Guardar. Orden lógico; los chips medidos son amplios al tacto.

## 2. Dart vs nativa: consistencia (de código, sin captura nativa)

| Elemento | AlarmDialog (Dart) | activity_alarm.xml | Veredicto |
|---|---|---|---|
| Fondo | Gradiente `#1A1A2E→#16213E→#0F3460` | Mismo gradiente (`alarm_gradient_bg`) | Idéntico |
| Hora | 64sp bold blanca | 64sp bold `#FFFFFF`, `marginTop 32dp` | Idéntico |
| Título | 24sp `white70` | 24sp `#B3FFFFFF` (=70 %) | Idéntico |
| Contador | 16sp blanco 60 % | 16sp `#99FFFFFF` (=60 %) | Idéntico |
| Botón completar | Verde `#2E7D32`, 56dp, 18sp | Verde `backgroundTint`, 56dp, 18sp | Idéntico |
| Botón posponer | Outline blanco, 56dp | `#80FFFFFF`, 56dp | Casi idéntico |
| Icono | `Icons.alarm` `#E94560` 80dp | `ic_lock_idle_alarm` tint `#E94560` 80dp | Equivalente |
| Márgenes | 32/24/16/48/16 | 32/24/16/48/16 | Idénticos |

La consistencia es muy buena; mantenerla es el principal riesgo de cualquier rediseño.

## 3. Contraste WCAG AA (calculado sobre colores fijos)

Umbrales: texto normal ≥ 4.5:1, texto grande ≥ 3.0:1.

| Par | Ratio | Veredicto |
|---|---|---|
| Blanco sobre `#2E7D32` (Completar, 18sp) | **5.13:1** | **AA** (antes `#4CAF50`: 2.78, suspenso; corregido) |
| Blanco sobre `#80FFFFFF`+marino (Posponer nativo, 18sp) | 3.19:1 | Justo (pasa como grande, sin margen) |
| Blanco sobre gradiente (`#0F3460`–`#1A1A2E`) | 12.5–17:1 | AAA |
| Título 70 % sobre `#16213E` | 8.4:1 | AAA |
| Contador 60 % sobre `#16213E` | 6.5:1 | AA |
| Icono `#E94560` sobre fondo | 4.46:1 | OK (no es texto, pide 3.0) |
| Texto M3 (generado por `colorSchemeSeed` índigo) | — | AA por diseño en claro y oscuro (ver 02/06) |

## 4. Áreas táctiles (medido en tests, mín. 48dp)

- Checkbox: 48×48 ✓ · Botones alarma: 736×56 ✓ · Tile: 72 alto ✓ ·
  IconButtons AppBar: 48 (estándar M3) ✓ · FAB extended estándar ✓ ·
  FilterChips: ~32dp visuales con área efectiva 48dp (M3 padded) ✓.

## 5. Colores fijos vs tema; modo oscuro

- `AlarmDialog` y la nativa usan colores fijos oscuros: el modo oscuro del sistema
  no les afecta (correcto para una alarma nocturna, pero es una decisión implícita).
- El resto usa el esquema M3 con `colorSchemeSeed` índigo: el modo oscuro funciona
  de verdad (captura 06: superficies, cards, aviso y FAB correctos).
- El aviso de plataforma usa `secondaryContainer`: se adapta solo a ambos temas.

## 6. Barra superior: 3 iconos

`notifications_active` (**Probar notificación**), `open_in_full` (overlay) y
`refresh`. El de prueba es útil en desarrollo pero **no debería ir en producción**
(sus textos de SnackBar también son de depuración).

## 7. Lista plana y formulario en diálogo

- Lista plana ordenada por hora, sin agrupar por día/hora ni destacar "próxima".
  Con 5+ tareas ya cuesta ver qué suena hoy.
- El formulario en `AlertDialog` funciona, pero en móvil estrecho un `ModalBottomSheet`
  o pantalla completa daría más aire a los 7 chips + hora + switches.

## 8. Vacíos, errores, carga y accesibilidad

- Vacío: mensaje correcto con instrucción ("Toca + para agregar una").
- Carga: spinner centrado, correcto.
- Errores: solo SnackBars de texto; eliminar no tiene Deshacer.
- Accesibilidad: sin `Semantics` explícitos (checkbox/borrar dependen del default);
  iconos sin `tooltip` salvo los 3 del AppBar; sin tamaños mínimos garantizados en
  chips propios. Fuente 150 % (08): sin overflows en lista y aviso (el aviso pasa a
  2 líneas); el `AlarmDialog` a 150 % **no se verificó** (columna sin scroll: riesgo).

## Propuesta de rediseño (sin implementar)

### Dirección A — "Calma nocturna" (alarm-first)
Paleta: marino `#0F3460` como color de marca en todo (no solo alarma); acento coral
`#E94560`; verde solo para confirmar. Tipografía: una display condensada para la hora
+ Inter/Roboto para cuerpo. Estructura: hero "Próxima alarma: Lun 9:00" arriba, lista
agrupada por día con cabeceras, formulario en bottom-sheet, nativa y Dart idénticas.

```
┌───────────────────────────┐
│  Próxima ─ Lun 9:00       │  hero oscuro con cuenta atrás
│  Reunión semanal     9:00 │
├───────────────────────────┤
│  LUNES                    │  cabeceras por día
│  ┌─────────────────────┐  │
│  │ Reunión   9:00  [✓] │  │
│  └─────────────────────┘  │
│  MARTES                   │
│  ┌─────────────────────┐  │
│  │ Gimnasio  7:30  [ ] │  │
│  └─────────────────────┘  │
└───────────────────────────┘
```

### Dirección B — "M3 expresivo claro" (lista-first)
Paleta: esquemas M3 por día (tonos pastel generados del seed), FAB prominente.
Tipografía: M3 por defecto, títulos con `titleLarge`. Estructura: fila de filtro por
día (/graphql chips) + timeline vertical con horas, formulario en pantalla completa,
alarma nativa intacta (no tocar lo que funciona).

```
┌───────────────────────────┐
│ [Hoy][Lun][Mar][Mié]…     │  filtro por día
│  ●────── 9:00 Reunión     │  timeline
│  ●────── 7:30 Gimnasio    │
│                           │
│              [+ Nueva]    │
└───────────────────────────┘
```

### Backlog priorizado (esfuerzo S/M/L × impacto)

1. Quitar "Probar notificación" en release — **S, alto** (confianza).
2. ~~Subir contraste del botón Completar~~ — hecho (`#2E7D32`, 5.13:1).
3. Contraste del Posponer nativo (`#80FFFFFF` → sólido) — **S, alto**.
4. `Semantics`/labels en checkbox, borrar, chips — **S, medio-alto**.
5. Agrupar lista por día + marca "hoy" — **M, alto**.
6. Formulario a bottom-sheet/pantalla — **M, medio**.
7. Deshacer al eliminar — **S, medio**.
8. Vacío ilustrado + atajo a crear — **S, bajo-medio**.
9. Verificar `AlarmDialog` a 150 % / pantallas pequeñas (scroll si hace falta) — **S, medio**.
10. ~~Hora de la alarma en vivo~~ — hecho (ticker 1 s en Dart y nativa).
