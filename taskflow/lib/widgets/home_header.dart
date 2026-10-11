import 'package:flutter/material.dart';
import '../app_themes.dart';
import '../constants.dart';
import '../models/task.dart';
import 'entrance.dart';

/// Cabecera sin AppBar: fecha + título a la izquierda, botón de ajustes redondo.
class HomeHeader extends StatelessWidget {
  final DateTime now;
  final VoidCallback onSettings;

  const HomeHeader({super.key, required this.now, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final title = theme.titleUppercase ? 'HOY' : 'Hoy';
    final dateStyle = TextStyle(
      fontFamily: theme.dateMonoUppercase ? theme.fontMono : theme.fontBody,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: theme.muted,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headerDateString(now, theme), style: dateStyle),
              Text(
                title,
                style: TextStyle(
                  fontFamily: theme.fontDisplay,
                  fontSize: theme.titleSize,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: theme.text,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.card,
              border: Border.all(color: theme.border, width: 1),
            ),
            child: Icon(Icons.tune, size: 24, color: theme.text),
          ),
        ),
      ],
    );
  }
}

/// Franja de 7 chips iguales siempre visibles; filtra por día.
/// Los chips entran de izquierda a derecha con 40 ms de diferencia.
class WeekStripCustom extends StatelessWidget {
  final DateTime now;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final TickerProvider vsync;
  final bool paused;

  const WeekStripCustom({
    super.key,
    required this.now,
    required this.selected,
    required this.onSelect,
    required this.vsync,
    this.paused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return Row(
      children: [
        for (int i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: StaggeredEntrance(
              index: i,
              stepMs: 40,
              slideHorizontal: theme.id == AppThemeId.grafito,
              durationMs: theme.id == AppThemeId.grafito ? 250 : 450,
              vsync: vsync,
              child: _DayChip(
                index: i,
                now: now,
                day: monday.add(Duration(days: i)),
                selected: selected,
                onSelect: onSelect,
                vsync: vsync,
                paused: paused,
              ),
            ),
          ),
        ],
      ],
    );
  }

}

/// Chip de día con pulso de entrada si es hoy (punto 2).
class _DayChip extends StatefulWidget {
  final int index;
  final DateTime now;
  final DateTime day;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final TickerProvider vsync;
  final bool paused;

  const _DayChip({
    required this.index,
    required this.now,
    required this.day,
    required this.selected,
    required this.onSelect,
    required this.vsync,
    required this.paused,
  });

  @override
  State<_DayChip> createState() => _DayChipState();
}

class _DayChipState extends State<_DayChip> {
  late final AnimationController _pulse;

  bool get _isToday =>
      widget.day.year == widget.now.year &&
      widget.day.month == widget.now.month &&
      widget.day.day == widget.now.day;

  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations || !_isToday) {
      _pulse.value = 1;
      return;
    }
    if (!_scheduled) {
      _scheduled = true;
      // Tras su propia entrada (40 ms por chip + 450 ms de animación).
      Future.delayed(Duration(milliseconds: widget.index * 40 + 450), () {
        if (mounted) _pulse.forward();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final isSelected = widget.selected == widget.day.weekday;
    final filled = _isToday;
    final textColor = filled ? theme.onAccent : theme.text;
    final pulse = _isToday
        ? TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 50),
            TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 50),
          ]).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          )
        : const AlwaysStoppedAnimation(1.0);
    return GestureDetector(
      onTap: () => widget.onSelect(isSelected ? null : widget.day.weekday),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) => Transform.scale(
            scale: pulse.value,
            child: child,
          ),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: filled ? theme.accent : theme.chipBg,
              borderRadius: BorderRadius.circular(theme.chipRadius),
              border: Border.all(
                color: filled
                    ? theme.accent
                    : (isSelected
                        ? theme.accent
                        : (theme.chipBorder ?? Colors.transparent)),
                width: isSelected && !filled ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kDayNames[widget.day.weekday - 1][0],
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filled ? theme.onAccent : theme.chipLetter,
                  ),
                ),
                Text(
                  '${widget.day.day}',
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Siguiente alarma".
class NextAlarmCardCustom extends StatelessWidget {
  final Task task;
  final DateTime when;
  final DateTime now;

  const NextAlarmCardCustom({
    super.key,
    required this.task,
    required this.when,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final mono = theme.fontMono;
    final dayName = kDayNames[when.weekday - 1];
    final time = TimeOfDay(hour: when.hour, minute: when.minute).format(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.nextBg,
        borderRadius: BorderRadius.circular(theme.bigCardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIGUIENTE ALARMA',
                  style: TextStyle(
                    fontFamily: mono ?? theme.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: theme.nextLabel,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$dayName $time',
                  style: TextStyle(
                    fontFamily: theme.fontDisplay,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: theme.nextText,
                  ),
                ),
                Text(
                  task.title,
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.nextText,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.nextPill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    relativeAlarmString(when, now),
                    style: TextStyle(
                      fontFamily: mono ?? theme.fontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.nextText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.nextCircle,
            ),
            child: Icon(Icons.notifications, size: 30, color: theme.nextCircleIcon),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de tarea (el desliz para borrar lo pone el padre).
/// Al marcar: el círculo se llena (escala 0.8→1.0 en 200 ms), el check se
/// dibuja trazo a trazo (250 ms) y el título se tacha de izquierda a derecha.
class TaskCardCustom extends StatefulWidget {
  final Task task;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final TickerProvider vsync;
  final bool paused;

  const TaskCardCustom({
    super.key,
    required this.task,
    required this.done,
    required this.onTap,
    required this.onToggle,
    required this.vsync,
    this.paused = false,
  });

  @override
  State<TaskCardCustom> createState() => _TaskCardCustomState();
}

class _TaskCardCustomState extends State<TaskCardCustom> {
  late final AnimationController _controller;
  late bool _shownDone;

  @override
  void initState() {
    super.initState();
    _shownDone = widget.done;
    _controller = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 250),
      value: _shownDone ? 1 : 0,
    );
    _controller.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = _shownDone ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(TaskCardCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done != _shownDone) {
      _shownDone = widget.done;
      _applyTarget();
    } else if (oldWidget.paused != widget.paused) {
      _applyTarget();
    }
  }

  void _applyTarget() {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = _shownDone ? 1 : 0;
      return;
    }
    if (widget.paused) {
      _controller.stop();
      return;
    }
    if (_shownDone) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final time =
        TimeOfDay(hour: widget.task.hour, minute: widget.task.minute)
            .format(context);
    final baseColor = _shownDone ? theme.muted : theme.text;
    // Tachado real solo al final (el barrido lo dibuja el painter).
    final doneDecoration = (_shownDone && _controller.isCompleted)
        ? TextDecoration.lineThrough
        : null;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(color: theme.border, width: 1),
        ),
        child: Row(
          children: [
            GestureDetector(
              key: ValueKey('check-${widget.task.id}'),
              onTap: widget.onToggle,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final fillT =
                        Curves.easeOut.transform((t / 0.8).clamp(0.0, 1.0));
                    return Transform.scale(
                      scale: 0.8 + 0.2 * fillT,
                        child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: theme.checkRadius == null
                              ? BoxShape.circle
                              : BoxShape.rectangle,
                          borderRadius: theme.checkRadius == null
                              ? null
                              : BorderRadius.circular(theme.checkRadius!),
                          color: t > 0
                              ? theme.checkDone.withValues(alpha: t)
                              : Colors.transparent,
                          border: t > 0
                              ? null
                              : Border.all(color: theme.checkEmpty, width: 2),
                        ),
                        child: t > 0
                            ? CustomPaint(
                                painter: _CheckPainter(
                                    progress: t, color: theme.checkIcon),
                                size: const Size(24, 24),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                  Text(
                    widget.task.title,
                    style: TextStyle(
                      fontFamily: theme.fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: baseColor,
                      decoration: doneDecoration,
                    ),
                  ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _StrikePainter(
                            progress: _controller.value,
                            color: baseColor,
                            repaint: _controller,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDays(widget.task.weekdays),
                    style: TextStyle(
                      fontFamily: theme.fontBody,
                      fontSize: 13,
                      color: theme.muted,
                    ),
                  ),
                ],
              ),
            ),
              Stack(
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: theme.fontMono ?? theme.fontDisplay,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: baseColor,
                    decoration: doneDecoration,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StrikePainter(
                      progress: _controller.value,
                      color: baseColor,
                      repaint: _controller,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(List<int> weekdays) {
    if (weekdays.isEmpty) return 'Sin días';
    return weekdays.map((d) => kDayNames[d - 1]).join(', ');
  }
}

/// Check dibujado trazo a trazo según [progress] (0 a 1).
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.70)
      ..lineTo(size.width * 0.75, size.height * 0.32);
    final metrics = path.computeMetrics().first;
    final drawn =
        metrics.extractPath(0, metrics.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Línea de tachado que avanza de izquierda a derecha.
class _StrikePainter extends CustomPainter {
  final double progress;
  final Color color;

  _StrikePainter(
      {required this.progress, required this.color, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width * progress.clamp(0.0, 1.0), size.height / 2),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.color != color;
}

/// Botón "Nueva tarea" de ancho completo.
class NewTaskButton extends StatelessWidget {
  final VoidCallback onTap;

  const NewTaskButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(theme.buttonRadius),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withValues(alpha: 0.22),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20, color: theme.onAccent),
            const SizedBox(width: 8),
            Text(
              'Nueva tarea',
              style: TextStyle(
                fontFamily: theme.fontBody,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra propia de Deshacer (sin SnackBar).
class UndoBar extends StatelessWidget {
  final VoidCallback onUndo;

  const UndoBar({super.key, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tarea eliminada',
              style: TextStyle(
                fontFamily: theme.fontBody,
                fontSize: 14,
                color: theme.text,
              ),
            ),
          ),
          GestureDetector(
            onTap: onUndo,
            child: Text(
              'Deshacer',
              style: TextStyle(
                fontFamily: theme.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Calcula la próxima alarma entre tareas no detenidas (null si no hay).
({Task task, DateTime when})? findNextAlarm(List<Task> tasks, DateTime now) {
  Task? bestTask;
  DateTime? bestWhen;
  for (final task in tasks) {
    if (task.isStopped || !task.hasValidDays) continue;
    final when = task.nextOccurrenceAfter(now);
    if (when == null) continue;
    if (bestWhen == null || when.isBefore(bestWhen)) {
      bestWhen = when;
      bestTask = task;
    }
  }
  if (bestTask == null || bestWhen == null) return null;
  return (task: bestTask, when: bestWhen);
}
