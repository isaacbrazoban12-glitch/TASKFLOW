import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_themes.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import '../notification_service.dart';

/// Longitud máxima del título: se muestra en notificaciones y en la alarma
/// nativa, así que se limita para que no rompa el diseño ni los extras.
const int kMaxTaskTitle = 80;

/// Abre el formulario como hoja inferior moderna con el tema vigente.
/// Devuelve la tarea guardada, o null si se cancela.
Future<Task?> showTaskForm(
  BuildContext context, {
  required AppTheme theme,
  Task? task,
}) {
  return showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => AppThemeScope(
      theme: theme,
      child: TaskFormDialog(task: task),
    ),
  );
}

class TaskFormDialog extends StatefulWidget {
  final Task? task;

  const TaskFormDialog({super.key, this.task});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  static const List<String> _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late List<int> _selectedDays;
  late TimeOfDay _selectedTime;
  late bool _repeats;
  late bool _stopOnComplete;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _selectedDays = [...?task?.weekdays];
    final now = TimeOfDay.now();
    _selectedTime = TimeOfDay(
      hour: task?.hour ?? now.hour,
      minute: task?.minute ?? now.minute,
    );
    _repeats = task?.repeats ?? true;
    _stopOnComplete = task?.stopOnComplete ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveTask() async {
    // Evita doble toque en Guardar (antes creaba la tarea dos veces).
    if (_saving) return;
    final validForm = _formKey.currentState!.validate();
    if (_selectedDays.isEmpty) {
      HapticFeedback.heavyImpact();
      _toast('Selecciona al menos un día.');
      return;
    }
    if (!validForm) return;

    setState(() => _saving = true);
    final days = [..._selectedDays]..sort();
    final baseTask = (widget.task ??
            const Task(title: '', weekdays: [], hour: 0, minute: 0))
        .copyWith(
      id: widget.task?.id,
      title: _titleController.text.trim(),
      weekdays: days,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      repeats: _repeats,
      // "Se detiene" no tiene sentido si la tarea no se repite.
      stopOnComplete: _repeats && _stopOnComplete,
      completed: widget.task?.completed ?? false,
    );

    final db = DatabaseHelper.instance;
    Task savedTask;

    try {
      if (widget.task == null) {
        final newId = await db.insertTask(baseTask);
        savedTask = baseTask.copyWith(id: newId);
      } else {
        await db.updateTask(baseTask);
        savedTask = baseTask;
      }

      // Editar una tarea detenida (completada sin repetición o con stop)
      // no debe reactivar sus alarmas.
      if (savedTask.isStopped && savedTask.id != null) {
        await NotificationService.instance.cancelTask(savedTask.id!);
      } else {
        await NotificationService.instance.scheduleTask(savedTask);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Error al guardar: $e');
      return;
    }

    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context, savedTask);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Hora de la alarma',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _toggleDay(int day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _setDays(List<int> days) {
    HapticFeedback.selectionClick();
    setState(() => _selectedDays = [...days]);
  }

  bool _sameDays(List<int> days) =>
      _selectedDays.length == days.length && days.every(_selectedDays.contains);

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isNew = widget.task == null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: theme.border)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.muted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isNew ? 'Nueva tarea' : 'Editar tarea',
                          style: TextStyle(
                            fontFamily: theme.fontDisplay,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: theme.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TimeHero(
                    time: _selectedTime,
                    theme: theme,
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    autofocus: isNew,
                    maxLength: kMaxTaskTitle,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      // Sin saltos de línea ni caracteres de control.
                      FilteringTextInputFormatter.deny(RegExp(r'[\u0000-\u001F\u007F]')),
                    ],
                    style: TextStyle(color: theme.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '¿Qué tienes que hacer?',
                      hintStyle: TextStyle(color: theme.muted),
                      prefixIcon: Icon(Icons.edit_note_rounded, color: theme.accent),
                      filled: true,
                      fillColor: theme.card,
                      counterStyle: TextStyle(color: theme.muted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: theme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: theme.accent, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Escribe un título para la tarea';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 12),
                  _SectionLabel('Días', theme: theme),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      return _DayToggle(
                        letter: _dayLetters[index],
                        fullName: kDayFullNames[index],
                        selected: _selectedDays.contains(day),
                        theme: theme,
                        onTap: () => _toggleDay(day),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresetChip(
                        label: 'Todos los días',
                        selected: _sameDays(const [1, 2, 3, 4, 5, 6, 7]),
                        theme: theme,
                        onTap: () => _setDays(const [1, 2, 3, 4, 5, 6, 7]),
                      ),
                      _PresetChip(
                        label: 'Lun a Vie',
                        selected: _sameDays(const [1, 2, 3, 4, 5]),
                        theme: theme,
                        onTap: () => _setDays(const [1, 2, 3, 4, 5]),
                      ),
                      _PresetChip(
                        label: 'Fin de semana',
                        selected: _sameDays(const [6, 7]),
                        theme: theme,
                        onTap: () => _setDays(const [6, 7]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: theme.card,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: theme.border),
                    ),
                    child: Column(
                      children: [
                        _OptionSwitch(
                          icon: Icons.repeat_rounded,
                          title: 'Se repite cada semana',
                          subtitle: 'Vuelve a sonar los días elegidos',
                          value: _repeats,
                          theme: theme,
                          onChanged: (v) => setState(() => _repeats = v),
                        ),
                        Divider(height: 1, color: theme.border),
                        _OptionSwitch(
                          icon: Icons.flag_rounded,
                          title: 'Al completar, se detiene',
                          subtitle: _repeats
                              ? 'Completarla una vez apaga sus alarmas'
                              : 'Solo para tareas que se repiten',
                          value: _repeats && _stopOnComplete,
                          theme: theme,
                          onChanged: _repeats
                              ? (v) => setState(() => _stopOnComplete = v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: theme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(theme.buttonRadius.clamp(0, 28)),
                        ),
                        textStyle: TextStyle(
                          fontFamily: theme.fontBody,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _saving ? null : _saveTask,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _saving
                            ? SizedBox(
                                key: const ValueKey('saving'),
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.onAccent,
                                ),
                              )
                            : Row(
                                key: const ValueKey('label'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alarm_add_rounded),
                                  const SizedBox(width: 8),
                                  Text(isNew ? 'Crear alarma' : 'Guardar cambios'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hora grande y tocable, el elemento principal del formulario.
class _TimeHero extends StatelessWidget {
  final TimeOfDay time;
  final AppTheme theme;
  final VoidCallback onTap;

  const _TimeHero({required this.time, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return Semantics(
      button: true,
      label: 'Hora de la alarma $hour12:$minute $period. Toca para cambiar',
      child: Material(
        color: theme.accent.withValues(alpha: theme.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(Icons.alarm_rounded, color: theme.accent, size: 28),
                const SizedBox(width: 14),
                Text(
                  '$hour12:$minute',
                  style: TextStyle(
                    fontFamily: theme.fontMono ?? theme.fontDisplay,
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  period,
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.accent,
                  ),
                ),
                const Spacer(),
                Icon(Icons.edit_rounded, color: theme.muted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppTheme theme;

  const _SectionLabel(this.text, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: theme.fontBody,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: theme.muted,
      ),
    );
  }
}

/// Círculo de día con relleno animado.
class _DayToggle extends StatelessWidget {
  final String letter;
  final String fullName;
  final bool selected;
  final AppTheme theme;
  final VoidCallback onTap;

  const _DayToggle({
    required this.letter,
    required this.fullName,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: fullName,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? theme.accent : theme.card,
            border: Border.all(
              color: selected ? theme.accent : theme.border,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: theme.fontBody,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: selected ? theme.onAccent : theme.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppTheme theme;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? theme.accent.withValues(alpha: 0.14) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? theme.accent : theme.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: theme.fontBody,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? theme.accent : theme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final AppTheme theme;
  final ValueChanged<bool>? onChanged;

  const _OptionSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(icon, color: enabled ? theme.accent : theme.muted),
      activeTrackColor: theme.accent,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: theme.fontBody,
          fontWeight: FontWeight.w600,
          color: enabled ? theme.text : theme.muted,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: theme.muted, fontSize: 13)),
      value: value,
      onChanged: onChanged,
    );
  }
}
