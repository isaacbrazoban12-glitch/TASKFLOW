import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onCheckboxChanged,
    required this.onDelete,
  });

  String _formatDays(List<int> weekdays) {
    if (weekdays.isEmpty) return 'Sin días';
    return weekdays.map((d) => kDayNames[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: task.hour,
      minute: task.minute,
    ).format(context);

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${_formatDays(task.weekdays)} · $time'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: task.completed,
              onChanged: onCheckboxChanged,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
