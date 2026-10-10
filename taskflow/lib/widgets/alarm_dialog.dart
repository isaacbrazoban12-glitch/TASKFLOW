import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmDialog extends StatefulWidget {
  final int taskId;
  final String taskTitle;
  final int weekday;
  final VoidCallback onCompleted;
  final VoidCallback onSnoozed;

  const AlarmDialog({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.weekday,
    required this.onCompleted,
    required this.onSnoozed,
  });

  static const int maxSnoozeCount = 3;

  /// Sufijo de fecha con dos dígitos, igual que Kotlin
  /// (`SimpleDateFormat yyyy/MM/dd` con `Locale.US`).
  static String dateSuffix(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}_${month}_$day';
  }

  /// Clave del contador, idéntica en Dart y Kotlin (el plugin antepone
  /// `flutter.` en Android; es la misma entrada).
  static String snoozeKey(int taskId, int weekday, DateTime date) {
    return 'alarm_dismiss_${taskId}_${weekday}_${dateSuffix(date)}';
  }

  static String _prefsKey(int taskId, int weekday) {
    return snoozeKey(taskId, weekday, DateTime.now());
  }

  static Future<int> getSnoozeCount(int taskId, int weekday) async {
    final prefs = await SharedPreferences.getInstance();
    // La caché Dart puede estar desactualizada frente a escrituras de Kotlin.
    await prefs.reload();
    return prefs.getInt(_prefsKey(taskId, weekday)) ?? 0;
  }

  /// Borra contadores de días anteriores para que no se acumulen.
  static Future<void> clearStaleSnoozeCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final todaySuffix = dateSuffix(DateTime.now());
    final stale = prefs.getKeys().where(
          (key) => key.startsWith('alarm_dismiss_') && !key.endsWith('_$todaySuffix'),
        );
    for (final key in stale) {
      await prefs.remove(key);
    }
  }

  static Future<void> incrementSnoozeCount(int taskId, int weekday) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(taskId, weekday);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  int _snoozeCount = 0;
  late String _currentTime;

  @override
  void initState() {
    super.initState();
    _loadSnoozeCount();
    _updateTime();
  }

  Future<void> _loadSnoozeCount() async {
    final count = await AlarmDialog.getSnoozeCount(widget.taskId, widget.weekday);
    if (mounted) {
      setState(() => _snoozeCount = count);
    }
  }

  void _updateTime() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    _currentTime = '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.alarm,
                size: 80,
                color: Color(0xFFE94560),
              ),
              const SizedBox(height: 32),
              Text(
                _currentTime,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.taskTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Posposiciones: $_snoozeCount de ${AlarmDialog.maxSnoozeCount}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      widget.onCompleted();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 28),
                    label: const Text(
                      'Voy a realizar la tarea',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_snoozeCount < AlarmDialog.maxSnoozeCount)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AlarmDialog.incrementSnoozeCount(
                          widget.taskId,
                          widget.weekday,
                        );
                        if (!mounted) return;
                        widget.onSnoozed();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.snooze, size: 28),
                      label: const Text(
                        'Posponer 5 min',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
