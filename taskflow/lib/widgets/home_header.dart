import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/task.dart';

/// Franja de la semana: filtra la lista por día (tocar de nuevo quita el filtro).
class WeekStrip extends StatelessWidget {
  final int? selected;
  final Set<int> daysWithTasks;
  final ValueChanged<int?> onSelect;

  const WeekStrip({
    super.key,
    required this.selected,
    required this.daysWithTasks,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(7, (index) {
          final day = index + 1;
          final isSelected = selected == day;
          final isToday = today == day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kDayNames[index],
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                  if (daysWithTasks.contains(day)) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
              avatar: isToday
                  ? Icon(Icons.today, size: 16, color: colors.primary)
                  : null,
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelect(isSelected ? null : day),
            ),
          );
        }),
      ),
    );
  }
}

/// Tarjeta "Siguiente alarma": la próxima ocurrencia entre las tareas activas.
class NextAlarmCard extends StatelessWidget {
  final Task task;
  final DateTime when;

  const NextAlarmCard({super.key, required this.task, required this.when});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dayName = kDayNames[when.weekday - 1];
    final time = TimeOfDay(hour: when.hour, minute: when.minute).format(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, size: 40, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Siguiente alarma',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                ),
                Text(
                  '${task.title} · $dayName $time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
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
