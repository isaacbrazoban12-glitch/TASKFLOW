import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_themes.dart';
import '../sound_service.dart';
import 'progress_page.dart';
import 'sounds_page.dart';

/// Contenedor con barra inferior: Tareas · Sonidos · Progreso.
/// La pantalla de tareas siempre vive (escucha las alarmas); las otras se
/// crean la primera vez que se visitan.
class RootShell extends StatefulWidget {
  final Widget home;

  const RootShell({super.key, required this.home});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final Set<int> _visited = {0};
  int _progressToken = 0;

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    // Al salir de Sonidos se corta cualquier vista previa.
    if (_index == 1) SoundService.instance.stopPreview();
    setState(() {
      _index = i;
      _visited.add(i);
      if (i == 2) _progressToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: IndexedStack(
        index: _index,
        children: [
          widget.home,
          _visited.contains(1) ? const SoundsPage() : const SizedBox.shrink(),
          _visited.contains(2)
              ? ProgressPage(refreshToken: _progressToken)
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: theme.card,
          indicatorColor: theme.accent.withValues(alpha: theme.isDark ? 0.28 : 0.18),
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontFamily: theme.fontBody,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected) ? theme.accent : theme.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? theme.accent : theme.muted,
            ),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.border)),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: _index,
            onDestinationSelected: _select,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.checklist_rounded),
                selectedIcon: Icon(Icons.checklist_rtl_rounded),
                label: 'Tareas',
              ),
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note_rounded),
                label: 'Sonidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Progreso',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
