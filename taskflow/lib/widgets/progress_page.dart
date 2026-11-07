import 'package:flutter/material.dart';

import '../app_themes.dart';
import '../constants.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import 'sound_picker.dart' show SectionTitle;
import 'sounds_page.dart' show PageHeader;

/// Sección "Progreso": resumen de la semana, racha, gráfica de 7 días,
/// agenda semanal y últimos completados.
class ProgressPage extends StatefulWidget {
  /// Cambia cada vez que se entra a la sección para recargar los datos.
  final int refreshToken;

  const ProgressPage({super.key, this.refreshToken = 0});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  List<Task> _tasks = [];
  List<Completion> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    var tasks = <Task>[];
    var history = <Completion>[];
    try {
      tasks = await db.getTasks();
    } catch (_) {}
    try {
      final since = DateTime.now().subtract(const Duration(days: 60));
      history = await db.getCompletionsSince(since.millisecondsSinceEpoch);
    } catch (_) {
      // En web no hay base de datos: se muestra vacío.
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final now = DateTime.now();
    final stats = ProgressStats.from(_history, now);
    final active = _tasks.where((t) => !t.isStopped).length;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.accent,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              PageHeader(title: 'Progreso', subtitle: 'Tu semana de un vistazo', theme: theme),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        theme: theme,
                        icon: Icons.check_circle_rounded,
                        value: '${stats.thisWeek}',
                        label: 'Hechas esta semana',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        theme: theme,
                        icon: Icons.local_fire_department_rounded,
                        value: '${stats.streakDays}',
                        label: stats.streakDays == 1 ? 'Día de racha' : 'Días de racha',
                        highlight: stats.streakDays >= 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        theme: theme,
                        icon: Icons.alarm_on_rounded,
                        value: '$active',
                        label: active == 1 ? 'Alarma activa' : 'Alarmas activas',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _WeekChart(theme: theme, values: stats.lastSevenDays, now: now),
                const SizedBox(height: 8),
                Text(
                  _motivation(stats),
                  style: TextStyle(color: theme.muted, fontSize: 13),
                ),
                SectionTitle('Agenda de la semana', theme: theme),
                _Agenda(theme: theme, tasks: _tasks, now: now),
                SectionTitle('Últimos completados', theme: theme),
                if (_history.isEmpty)
                  Text(
                    'Aún no hay nada aquí. Completa una tarea y aparecerá en tu historial.',
                    style: TextStyle(color: theme.muted, fontSize: 13),
                  )
                else
                  for (final c in _history.take(8))
                    _HistoryRow(theme: theme, completion: c, now: now),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _motivation(ProgressStats s) {
    if (s.thisWeek == 0) return 'Cada tarea completada suma a tu racha.';
    if (s.streakDays >= 7) return '¡Una semana entera sin fallar! Sigue así.';
    if (s.streakDays >= 3) return '¡Vas en racha! No la rompas mañana.';
    return 'Buen ritmo: ya llevas ${s.thisWeek} esta semana.';
  }
}

String formatTime12(int hour, int minute) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final p = hour < 12 ? 'AM' : 'PM';
  return '$h:${minute.toString().padLeft(2, '0')} $p';
}

class _StatCard extends StatelessWidget {
  final AppTheme theme;
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _StatCard({
    required this.theme,
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? theme.accent : theme.card;
    final fg = highlight ? theme.onAccent : theme.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(theme.cardRadius.clamp(12, 22)),
        border: Border.all(color: highlight ? theme.accent : theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? theme.onAccent : theme.accent, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: theme.fontDisplay,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(
              fontFamily: theme.fontBody,
              fontSize: 11.5,
              color: highlight ? theme.onAccent : theme.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras de los últimos 7 días, con la de hoy resaltada.
class _WeekChart extends StatelessWidget {
  final AppTheme theme;
  final List<int> values;
  final DateTime now;

  const _WeekChart({required this.theme, required this.values, required this.now});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(1, (a, b) => a > b ? a : b);
    const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.cardRadius.clamp(12, 22)),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimos 7 días',
            style: TextStyle(
              fontFamily: theme.fontBody,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Semantics(
                      label: '${values[i]} completadas',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (values[i] > 0)
                            Text(
                              '${values[i]}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: i == 6 ? theme.accent : theme.muted,
                              ),
                            ),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: values[i] / maxV),
                            duration: Duration(milliseconds: 500 + i * 60),
                            curve: Curves.easeOutCubic,
                            builder: (context, f, _) => Container(
                              height: 6 + 74 * f,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: i == 6
                                    ? theme.accent
                                    : theme.accent.withValues(alpha: values[i] == 0 ? 0.15 : 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            letters[DateTime(now.year, now.month, now.day - (6 - i)).weekday - 1],
                            style: TextStyle(
                              fontFamily: theme.fontBody,
                              fontSize: 12,
                              fontWeight: i == 6 ? FontWeight.w800 : FontWeight.w600,
                              color: i == 6 ? theme.accent : theme.muted,
                            ),
                          ),
                        ],
                      ),
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

/// Lista de lunes a domingo con las alarmas de cada día.
class _Agenda extends StatelessWidget {
  final AppTheme theme;
  final List<Task> tasks;
  final DateTime now;

  const _Agenda({required this.theme, required this.tasks, required this.now});

  @override
  Widget build(BuildContext context) {
    final active = tasks.where((t) => !t.isStopped).toList();
    if (active.isEmpty) {
      return Text(
        'Sin alarmas activas. Crea una tarea en la sección Tareas.',
        style: TextStyle(color: theme.muted, fontSize: 13),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.cardRadius.clamp(12, 22)),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          for (int day = 1; day <= 7; day++) ...[
            if (day > 1) Divider(height: 1, color: theme.border),
            _AgendaDay(
              theme: theme,
              day: day,
              isToday: now.weekday == day,
              tasks: (active.where((t) => t.weekdays.contains(day)).toList()
                ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute))),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgendaDay extends StatelessWidget {
  final AppTheme theme;
  final int day;
  final bool isToday;
  final List<Task> tasks;

  const _AgendaDay({
    required this.theme,
    required this.day,
    required this.isToday,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? theme.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              kDayNames[day - 1],
              style: TextStyle(
                fontFamily: theme.fontBody,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isToday ? theme.onAccent : theme.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Libre', style: TextStyle(color: theme.muted, fontSize: 13)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final t in tasks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text(
                                  formatTime12(t.hour, t.minute),
                                  style: TextStyle(
                                    fontFamily: theme.fontMono ?? theme.fontBody,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.accent,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: theme.text, fontSize: 13.5),
                                ),
                              ),
                            ],
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

class _HistoryRow extends StatelessWidget {
  final AppTheme theme;
  final Completion completion;
  final DateTime now;

  const _HistoryRow({required this.theme, required this.completion, required this.now});

  String _when() {
    final at = completion.at;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    final time = formatTime12(at.hour, at.minute);
    if (diff == 0) return 'Hoy, $time';
    if (diff == 1) return 'Ayer, $time';
    return '${kDayFullNames[at.weekday - 1]} ${at.day}, $time';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: theme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                  ),
                ),
                Text(_when(), style: TextStyle(color: theme.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
