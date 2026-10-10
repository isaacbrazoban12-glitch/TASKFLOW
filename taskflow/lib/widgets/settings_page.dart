import 'package:flutter/material.dart';
import '../app_themes.dart';
import '../theme_controller.dart';

String _formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Pantalla de Ajustes: modo de tema, reglas de horario y vista previa.
class SettingsPage extends StatelessWidget {
  final ThemeController themeController;

  const SettingsPage({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ModeSection(themeController: themeController),
            const SizedBox(height: 8),
            _ManualSection(themeController: themeController),
            _ScheduleSection(themeController: themeController),
            _RotationSection(themeController: themeController),
            const SizedBox(height: 8),
            Text('Vista previa (toca para usarlo)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PreviewSection(themeController: themeController),
          ],
        ),
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  final ThemeController themeController;

  const _ModeSection({required this.themeController});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeModeSetting>(
      segments: const [
        ButtonSegment(value: ThemeModeSetting.manual, label: Text('Manual')),
        ButtonSegment(value: ThemeModeSetting.schedule, label: Text('Horario')),
        ButtonSegment(value: ThemeModeSetting.rotation, label: Text('Rotación')),
      ],
      selected: {themeController.mode},
      onSelectionChanged: (selected) => themeController.setMode(selected.first),
    );
  }
}

class _ManualSection extends StatelessWidget {
  final ThemeController themeController;

  const _ManualSection({required this.themeController});

  @override
  Widget build(BuildContext context) {
    if (themeController.mode != ThemeModeSetting.manual) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        RadioGroup<AppThemeId>(
          groupValue: themeController.manualTheme,
          onChanged: (value) {
            if (value != null) themeController.setManualTheme(value);
          },
          child: Column(
            children: [
              for (final theme in AppThemeId.values)
                RadioListTile<AppThemeId>(
                  title: Text(appThemeOf(theme).name),
                  secondary:
                      CircleAvatar(backgroundColor: appThemeOf(theme).accent),
                  value: theme,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  final ThemeController themeController;

  const _ScheduleSection({required this.themeController});

  @override
  Widget build(BuildContext context) {
    if (themeController.mode != ThemeModeSetting.schedule) {
      return const SizedBox.shrink();
    }
    final rules = [...themeController.rules]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        for (int i = 0; i < rules.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: appThemeOf(rules[i].theme).accent,
              child: Text(
                '${i + 1}',
                style: TextStyle(color: appThemeOf(rules[i].theme).onAccent),
              ),
            ),
            title: Text('Desde las ${_formatMinutes(rules[i].startMinutes)}'),
            trailing: DropdownButton<AppThemeId>(
              value: rules[i].theme,
              items: [
                for (final id in AppThemeId.values)
                  DropdownMenuItem(value: id, child: Text(appThemeOf(id).name)),
              ],
              onChanged: (value) {
                if (value == null) return;
                final updated = [...rules];
                updated[i] = ThemeRule(startMinutes: rules[i].startMinutes, theme: value);
                themeController.setRules(updated);
              },
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: rules[i].startMinutes ~/ 60,
                  minute: rules[i].startMinutes % 60,
                ),
              );
              if (picked == null) return;
              final updated = [...rules];
              updated[i] = ThemeRule(
                startMinutes: picked.hour * 60 + picked.minute,
                theme: rules[i].theme,
              );
              themeController.setRules(updated);
            },
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bosque sábados y domingos'),
          value: themeController.weekendEnabled,
          onChanged: (value) =>
              themeController.setWeekend(enabled: value),
        ),
        if (themeController.weekendEnabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tema del fin de semana'),
            trailing: DropdownButton<AppThemeId>(
              value: themeController.weekendTheme,
              items: [
                for (final id in AppThemeId.values)
                  DropdownMenuItem(value: id, child: Text(appThemeOf(id).name)),
              ],
              onChanged: (value) {
                if (value == null) return;
                themeController.setWeekend(
                  enabled: true,
                  theme: value,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RotationSection extends StatelessWidget {
  final ThemeController themeController;

  const _RotationSection({required this.themeController});

  @override
  Widget build(BuildContext context) {
    if (themeController.mode != ThemeModeSetting.rotation) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Cambiar cada ${themeController.rotationHours} h'),
        Slider(
          min: 1,
          max: 24,
          divisions: 23,
          value: themeController.rotationHours.toDouble(),
          label: '${themeController.rotationHours} h',
          onChanged: (value) => themeController.setRotationHours(value.round()),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final ThemeController themeController;

  const _PreviewSection({required this.themeController});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final id in AppThemeId.values)
          Card(
            color: appThemeOf(id).background,
            child: ListTile(
              leading: CircleAvatar(backgroundColor: appThemeOf(id).accent),
              title: Text(
                appThemeOf(id).name,
                style: TextStyle(
                  color: appThemeOf(id).onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                id == themeController.current ? 'En uso' : 'Toca para usarlo',
                style: TextStyle(color: appThemeOf(id).onBackground.withValues(alpha: 0.7)),
              ),
              trailing: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: appThemeOf(id).accent,
                  foregroundColor: appThemeOf(id).onAccent,
                ),
                onPressed: () {
                  themeController.setManualTheme(id);
                  themeController.setMode(ThemeModeSetting.manual);
                },
                child: const Text('Usar'),
              ),
              onTap: () {
                themeController.setManualTheme(id);
                themeController.setMode(ThemeModeSetting.manual);
              },
            ),
          ),
      ],
    );
  }
}
