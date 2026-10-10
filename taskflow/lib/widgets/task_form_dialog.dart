import 'package:flutter/material.dart';
import '../constants.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import '../notification_service.dart';

class TaskFormDialog extends StatefulWidget {
  final Task? task;

  const TaskFormDialog({super.key, this.task});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late List<int> _selectedDays;
  late TimeOfDay _selectedTime;
  late bool _repeats;
  late bool _stopOnComplete;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _selectedDays = [...?task?.weekdays];
    _selectedTime = TimeOfDay(
      hour: task?.hour ?? TimeOfDay.now().hour,
      minute: task?.minute ?? TimeOfDay.now().minute,
    );
    _repeats = task?.repeats ?? true;
    _stopOnComplete = task?.stopOnComplete ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate() || _selectedDays.isEmpty) {
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un día.')),
        );
      }
      return;
    }

    final baseTask = (widget.task ??
            Task(
              title: '',
              weekdays: const [],
              hour: 0,
              minute: 0,
            ))
        .copyWith(
      id: widget.task?.id,
      title: _titleController.text.trim(),
      weekdays: _selectedDays,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      repeats: _repeats,
      stopOnComplete: _stopOnComplete,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, savedTask);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Nueva tarea' : 'Editar tarea'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El título es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Días de la semana'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final dayNumber = index + 1;
                  final isSelected = _selectedDays.contains(dayNumber);
                  return FilterChip(
                    label: Text(kDayNames[index]),
                    selected: isSelected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          if (!_selectedDays.contains(dayNumber)) {
                            _selectedDays.add(dayNumber);
                          }
                        } else {
                          _selectedDays.remove(dayNumber);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hora'),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                    child: Text(_selectedTime.format(context)),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Se repite cada semana'),
                value: _repeats,
                onChanged: (value) => setState(() => _repeats = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Al completar, se detiene'),
                value: _stopOnComplete,
                onChanged: (value) => setState(() => _stopOnComplete = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saveTask,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
