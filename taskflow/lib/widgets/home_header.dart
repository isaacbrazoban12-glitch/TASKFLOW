import 'package:flutter/material.dart';
import '../app_themes.dart';
import '../constants.dart';
import '../models/task.dart';

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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headerDateString(now, theme), style: dateStyle),
              const SizedBox(height: 2),
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
            child: Center(
              child: CustomPaint(
                size: const Size(22, 22),
                painter: _SlidersPainter(color: theme.text),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Icono de ajustes del HTML (dos líneas con círculos), 22x22, trazo 2.
class _SlidersPainter extends CustomPainter {
  final Color color;

  _SlidersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 24x24 escalado a 22.
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(4, 7), const Offset(14, 7), p);
    canvas.drawLine(const Offset(18, 7), const Offset(20, 7), p);
    canvas.drawLine(const Offset(4, 17), const Offset(6, 17), p);
    canvas.drawLine(const Offset(10, 17), const Offset(20, 17), p);
    canvas.drawCircle(const Offset(16, 7), 2, p);
    canvas.drawCircle(const Offset(8, 17), 2, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlidersPainter old) => old.color != color;
}

/// Franja de 7 chips iguales siempre visibles; filtra por día.
class WeekStripCustom extends StatelessWidget {
  final DateTime now;
  final int? selected;
  final ValueChanged<int?> onSelect;

  const WeekStripCustom({
    super.key,
    required this.now,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return Row(
      children: [
        for (int i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _dayChip(context, theme, monday.add(Duration(days: i)))),
        ],
      ],
    );
  }

  Widget _dayChip(BuildContext context, AppTheme theme, DateTime day) {
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final isSelected = selected == day.weekday;
    final filled = isToday;
    final textColor = filled ? theme.onAccent : theme.text;
    return GestureDetector(
      onTap: () => onSelect(isSelected ? null : day.weekday),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: filled ? theme.accent : theme.chipBg,
          borderRadius: BorderRadius.circular(theme.chipRadius),
          border: Border.all(
            color: filled
                ? theme.accent
                : (isSelected ? theme.accent : (theme.chipBorder ?? Colors.transparent)),
            width: isSelected && !filled ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kDayNames[day.weekday - 1][0],
              style: TextStyle(
                fontFamily: theme.fontBody,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? theme.onAccent : theme.chipLetter,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
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

/// Tarjeta de tarea (el desliz para borrar lo pone el padre con Dismissible).
class TaskCardCustom extends StatelessWidget {
  final Task task;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const TaskCardCustom({
    super.key,
    required this.task,
    required this.done,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final time =
        TimeOfDay(hour: task.hour, minute: task.minute).format(context);
    final titleStyle = TextStyle(
      fontFamily: theme.fontDisplay,
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: done ? theme.muted : theme.text,
      decoration: done ? TextDecoration.lineThrough : null,
    );
    return GestureDetector(
      onTap: onTap,
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
              key: ValueKey('check-${task.id}'),
              onTap: onToggle,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: theme.checkRadius == null ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: theme.checkRadius == null
                      ? null
                      : BorderRadius.circular(theme.checkRadius!),
                  color: done ? theme.checkDone : Colors.transparent,
                  border: done
                      ? null
                      : Border.all(color: theme.checkEmpty, width: 2),
                ),
                child: done
                    ? Icon(Icons.check, size: 24, color: theme.checkIcon)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: titleStyle),
                  Text(
                    _formatDays(task.weekdays),
                    style: TextStyle(
                      fontFamily: theme.fontBody,
                      fontSize: 13,
                      color: theme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontFamily: theme.fontMono ?? theme.fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: done ? theme.muted : theme.text,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
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

/// Botón "Añadir tarea" de ancho completo.
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
              color: theme.accent.withValues(alpha: 0.28),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 20, color: theme.onAccent),
            const SizedBox(width: 8),
            Text(
              'Añadir tarea',
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

/// Tarjeta vacía "Sin tareas / Crea tu primera tarea", copia del HTML.
class EmptyNextAlarmCard extends StatelessWidget {
  const EmptyNextAlarmCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
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
                    fontFamily: theme.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.96,
                    color: theme.nextLabel,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sin tareas',
                  style: TextStyle(
                    fontFamily: theme.fontDisplay,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: theme.nextText,
                  ),
                ),
                Text(
                  'Crea tu primera tarea',
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.nextText,
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
            child: Center(
              child: CustomPaint(
                size: const Size(30, 30),
                painter: _BellPainter(color: theme.nextCircleIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campana del HTML (30x30, trazo 2).
class _BellPainter extends CustomPainter {
  final Color color;

  _BellPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 24x24 escalado a 30.
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final bell = Path()
      ..moveTo(6, 17)
      ..lineTo(6, 11)
      ..cubicTo(6, 7.13, 8.69, 5, 12, 5)
      ..cubicTo(15.31, 5, 18, 7.13, 18, 11)
      ..lineTo(18, 17)
      ..lineTo(19.5, 19)
      ..lineTo(4.5, 19)
      ..close();
    canvas.drawPath(bell, p);
    canvas.drawLine(const Offset(10, 21), const Offset(14, 21), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.color != color;
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
