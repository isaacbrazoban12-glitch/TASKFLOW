/// Un completado registrado (historial para la sección Progreso).
class Completion {
  final int taskId;
  final String title;
  final DateTime at;

  const Completion({required this.taskId, required this.title, required this.at});

  factory Completion.fromMap(Map<String, dynamic> map) => Completion(
        taskId: (map['taskId'] as num?)?.toInt() ?? -1,
        title: (map['title'] ?? '').toString(),
        at: DateTime.fromMillisecondsSinceEpoch((map['at'] as num?)?.toInt() ?? 0),
      );
}

/// Resumen calculado a partir del historial.
class ProgressStats {
  /// Completados por día de los últimos 7 días (índice 0 = hace 6 días, 6 = hoy).
  final List<int> lastSevenDays;
  final int thisWeek;
  final int streakDays;
  final int bestDay;

  const ProgressStats({
    required this.lastSevenDays,
    required this.thisWeek,
    required this.streakDays,
    required this.bestDay,
  });

  /// Calcula el resumen; [now] se inyecta para poder probarlo.
  factory ProgressStats.from(List<Completion> items, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

    final perDay = <DateTime, int>{};
    for (final c in items) {
      final d = dayOf(c.at);
      perDay[d] = (perDay[d] ?? 0) + 1;
    }

    final last7 = List<int>.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day - (6 - i));
      return perDay[d] ?? 0;
    });

    // Semana de lunes a domingo.
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final thisWeek = items.where((c) => !dayOf(c.at).isBefore(monday)).length;

    // Racha: días seguidos con al menos un completado, terminando hoy (o
    // ayer, para no romperla antes de que llegue la tarea de hoy).
    var streak = 0;
    var cursor = perDay.containsKey(today)
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    while (perDay.containsKey(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    final best = perDay.values.fold<int>(0, (a, b) => a > b ? a : b);
    return ProgressStats(
      lastSevenDays: last7,
      thisWeek: thisWeek,
      streakDays: streak,
      bestDay: best,
    );
  }
}
