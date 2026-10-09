class Task {
  final int? id;
  final String title;
  final List<int> weekdays;
  final int hour;
  final int minute;
  final bool repeats;
  final bool stopOnComplete;
  final bool completed;

  const Task({
    this.id,
    required this.title,
    required this.weekdays,
    required this.hour,
    required this.minute,
    this.repeats = true,
    this.stopOnComplete = false,
    this.completed = false,
  });

  bool get hasValidDays => weekdays.isNotEmpty;

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
    );
  }
}