class Task {
  final int? id;
  final String title;
  final List<int> weekdays;
  final int hour;
  final int minute;
  final bool repeats;
  final bool stopOnComplete;
  final bool completed;
  final int? completedAt;

  const Task({
    this.id,
    required this.title,
    required this.weekdays,
    required this.hour,
    required this.minute,
    this.repeats = true,
    this.stopOnComplete = false,
    this.completed = false,
    this.completedAt,
  });

  bool get hasValidDays => weekdays.isNotEmpty;

  /// true si al completar la tarea debe detenerse para siempre
  /// (no se repite, o tiene stopOnComplete).
  bool get stopsOnComplete => stopOnComplete || !repeats;

  /// true si la tarea está detenida de forma permanente.
  bool get isStopped => completed;

  /// Última ocurrencia programada en o antes de [now] (null sin días válidos).
  /// Usa convención Dart (weekday 1=Lun … 7=Dom), igual que lo guardado.
  DateTime? lastOccurrenceBeforeOrAt(DateTime now) {
    if (weekdays.isEmpty) return null;
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    for (int back = 0; back < 8; back++) {
      final day = today.subtract(Duration(days: back));
      if (weekdays.contains(day.weekday) && !day.isAfter(now)) return day;
    }
    return null;
  }

  /// Estado "completada" efectivo a fecha [now].
  /// - Detenida → siempre true.
  /// - Repetitiva sin stopOnComplete → true solo si [completedAt] cubre la
  ///   última ocurrencia; al llegar la siguiente se reinicia a false.
  bool isEffectivelyCompleted(DateTime now) {
    if (completed) return true;
    if (completedAt == null) return false;
    if (stopOnComplete || !repeats) return false;
    final last = lastOccurrenceBeforeOrAt(now);
    if (last == null) return false;
    return !DateTime.fromMillisecondsSinceEpoch(completedAt!).isBefore(last);
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'weekdays': weekdays.isEmpty ? '' : weekdays.join(','),
      'hour': hour,
      'minute': minute,
      'repeats': repeats ? 1 : 0,
      'stopOnComplete': stopOnComplete ? 1 : 0,
      'completed': completed ? 1 : 0,
      'completedAt': completedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final raw = map['weekdays'];

    final weekdays = switch (raw) {
      null => <int>[],
      String s when s.trim().isEmpty => <int>[],
      String s => s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toList(),
      List list => list
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList(),
      _ => <int>[],
    };

    return Task(
      id: map['id'] as int?,
      title: (map['title'] ?? '').toString(),
      weekdays: weekdays,
      hour: int.tryParse(map['hour']?.toString() ?? '') ?? 0,
      minute: int.tryParse(map['minute']?.toString() ?? '') ?? 0,
      repeats: map['repeats'] == 1 || map['repeats'] == true,
      stopOnComplete: map['stopOnComplete'] == 1 || map['stopOnComplete'] == true,
      completed: map['completed'] == 1 || map['completed'] == true,
      completedAt: (map['completedAt'] as num?)?.toInt(),
    );
  }

  Task copyWith({
    int? id,
    String? title,
    List<int>? weekdays,
    int? hour,
    int? minute,
    bool? repeats,
    bool? stopOnComplete,
    bool? completed,
    int? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      weekdays: weekdays ?? this.weekdays,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeats: repeats ?? this.repeats,
      stopOnComplete: stopOnComplete ?? this.stopOnComplete,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}