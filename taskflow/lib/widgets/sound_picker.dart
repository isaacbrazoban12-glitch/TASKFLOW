import 'package:flutter/material.dart';

import '../app_themes.dart';
import '../sound_service.dart';

/// Resultado del selector: [id] null = "usar el predeterminado de la app".
class SoundSelection {
  final String? id;
  const SoundSelection(this.id);
}

/// Hoja para elegir sonido. Devuelve null si se cierra sin elegir.
Future<SoundSelection?> showSoundPicker(
  BuildContext context, {
  required AppTheme theme,
  String? current,
  bool allowAppDefault = false,
}) async {
  final result = await showModalBottomSheet<SoundSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AppThemeScope(
      theme: theme,
      child: _SoundPickerSheet(current: current, allowAppDefault: allowAppDefault),
    ),
  );
  await SoundService.instance.stopPreview();
  return result;
}

class _SoundPickerSheet extends StatefulWidget {
  final String? current;
  final bool allowAppDefault;

  const _SoundPickerSheet({required this.current, required this.allowAppDefault});

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  final _service = SoundService.instance;
  List<AlarmSound> _custom = [];
  List<AlarmSound> _system = [];
  bool _loadingSystem = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final custom = await _service.customSounds();
    if (mounted) setState(() => _custom = custom);
    final system = await _service.systemSounds();
    if (mounted) {
      setState(() {
        _system = system;
        _loadingSystem = false;
      });
    }
  }

  Future<void> _addFromPhone() async {
    final sound = await _service.pickFromPhone();
    if (sound == null || !mounted) return;
    Navigator.pop(context, SoundSelection(sound.id));
  }

  void _choose(AlarmSound? sound) {
    if (sound != null) _service.rememberLabel(sound);
    Navigator.pop(context, SoundSelection(sound?.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: theme.border)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
            const SizedBox(height: 16),
            Text(
              'Elige un sonido',
              style: TextStyle(
                fontFamily: theme.fontDisplay,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _service.supported
                  ? 'Toca ▶ para escucharlo y el nombre para elegirlo.'
                  : 'La vista previa solo funciona en Android.',
              style: TextStyle(color: theme.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (widget.allowAppDefault)
              SoundTile(
                sound: const AlarmSound('', 'Predeterminado de la app',
                    'El que elijas en la sección Sonidos'),
                selected: widget.current == null,
                theme: theme,
                icon: Icons.auto_awesome_rounded,
                onTap: () => _choose(null),
                showPreview: false,
              ),
            SoundTile(
              sound: SoundService.systemDefault,
              selected: widget.current == SoundService.defaultId,
              theme: theme,
              icon: Icons.phone_android_rounded,
              onTap: () => _choose(SoundService.systemDefault),
            ),
            SectionTitle('Sonidos de TaskFlow', theme: theme),
            for (final s in SoundService.builtIn)
              SoundTile(
                sound: s,
                selected: widget.current == s.id,
                theme: theme,
                onTap: () => _choose(s),
              ),
            SectionTitle('Mi música', theme: theme),
            for (final s in _custom)
              SoundTile(
                sound: s,
                selected: widget.current == s.id,
                theme: theme,
                icon: Icons.library_music_rounded,
                onTap: () => _choose(s),
              ),
            AddMusicButton(theme: theme, onTap: _service.supported ? _addFromPhone : null),
            if (_service.supported) ...[
              SectionTitle('Tonos del teléfono', theme: theme),
              if (_loadingSystem)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_system.isEmpty)
                Text('No se encontraron tonos.', style: TextStyle(color: theme.muted))
              else
                for (final s in _system)
                  SoundTile(
                    sound: s,
                    selected: widget.current == s.id,
                    theme: theme,
                    icon: Icons.notifications_active_outlined,
                    onTap: () => _choose(s),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Título de sección en mayúsculas pequeñas.
class SectionTitle extends StatelessWidget {
  final String text;
  final AppTheme theme;

  const SectionTitle(this.text, {super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10, left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: theme.fontBody,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
          color: theme.muted,
        ),
      ),
    );
  }
}

/// Fila de sonido con vista previa (▶/■), nombre y marca de elegido.
class SoundTile extends StatelessWidget {
  final AlarmSound sound;
  final bool selected;
  final AppTheme theme;
  final VoidCallback? onTap;
  final IconData icon;
  final bool showPreview;
  final Widget? trailing;

  const SoundTile({
    super.key,
    required this.sound,
    required this.selected,
    required this.theme,
    this.onTap,
    this.icon = Icons.music_note_rounded,
    this.showPreview = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final service = SoundService.instance;
    final playing = service.previewing == sound.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? theme.accent.withValues(alpha: 0.14) : theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? theme.accent : theme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (showPreview && service.supported)
                  IconButton(
                    tooltip: playing ? 'Detener' : 'Escuchar',
                    onPressed: () => service.preview(sound),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        playing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                        key: ValueKey(playing),
                        size: 32,
                        color: theme.accent,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: theme.accent),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: theme.fontBody,
                          fontWeight: FontWeight.w700,
                          color: theme.text,
                        ),
                      ),
                      if (sound.description != null)
                        Text(
                          sound.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: theme.muted),
                        ),
                    ],
                  ),
                ),
                ?trailing,
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.check_circle_rounded, color: theme.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón grande "Agregar canción del teléfono".
class AddMusicButton extends StatelessWidget {
  final AppTheme theme;
  final VoidCallback? onTap;

  const AddMusicButton({super.key, required this.theme, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enabled ? theme.accent : theme.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: enabled ? theme.accent : theme.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enabled
                      ? 'Agregar canción del teléfono'
                      : 'Agregar música (solo en Android)',
                  style: TextStyle(
                    fontFamily: theme.fontBody,
                    fontWeight: FontWeight.w700,
                    color: enabled ? theme.accent : theme.muted,
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
