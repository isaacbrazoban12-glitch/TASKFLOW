import 'package:flutter/material.dart';

import '../app_themes.dart';
import '../sound_service.dart';
import 'sound_picker.dart';

/// Sección "Sonidos": volumen de alarma, opciones, sonido predeterminado,
/// música propia y sonidos incluidos.
class SoundsPage extends StatefulWidget {
  const SoundsPage({super.key});

  @override
  State<SoundsPage> createState() => _SoundsPageState();
}

class _SoundsPageState extends State<SoundsPage> with WidgetsBindingObserver {
  final _service = SoundService.instance;

  String _defaultId = SoundService.defaultId;
  String _defaultName = SoundService.systemDefault.name;
  bool _crescendo = false;
  bool _vibrate = true;
  int _autoSilence = 10;
  List<AlarmSound> _custom = [];
  int? _volume;
  int _volumeMax = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_onServiceChange);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_onServiceChange);
    _service.stopPreview();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El volumen pudo cambiar con los botones físicos.
    if (state == AppLifecycleState.resumed) _loadVolume();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = await _service.defaultSound();
    final name = await _service.labelFor(id);
    final crescendo = await _service.crescendo();
    final vibrate = await _service.vibrate();
    final auto = await _service.autoSilenceMinutes();
    final custom = await _service.customSounds();
    if (!mounted) return;
    setState(() {
      _defaultId = id;
      _defaultName = name;
      _crescendo = crescendo;
      _vibrate = vibrate;
      _autoSilence = auto;
      _custom = custom;
    });
    await _loadVolume();
  }

  Future<void> _loadVolume() async {
    final v = await _service.alarmVolume();
    if (!mounted || v == null) return;
    setState(() {
      _volume = v.$1;
      _volumeMax = v.$2 <= 0 ? 7 : v.$2;
    });
  }

  Future<void> _setDefault(AlarmSound sound) async {
    await _service.setDefaultSound(sound);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('«${sound.name}» es ahora tu sonido de alarma'),
    ));
  }

  Future<void> _changeDefault() async {
    final theme = AppThemeScope.of(context);
    final picked = await showSoundPicker(context, theme: theme, current: _defaultId);
    if (picked?.id == null) return;
    final id = picked!.id!;
    await _setDefault(AlarmSound(id, await _service.labelFor(id)));
  }

  Future<void> _addMusic() async {
    final sound = await _service.pickFromPhone();
    if (sound == null) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('«${sound.name}» agregada a Mi música'),
      action: SnackBarAction(
        label: 'Usar',
        onPressed: () => _setDefault(sound),
      ),
    ));
  }

  Future<void> _removeMusic(AlarmSound sound) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar canción'),
        content: Text('¿Quitar «${sound.name}» de Mi música? '
            'El archivo sigue en tu teléfono.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.removeCustom(sound);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            PageHeader(
              title: 'Sonidos',
              subtitle: 'Cómo suena tu alarma',
              theme: theme,
            ),
            if (!_service.supported) ...[
              const SizedBox(height: 12),
              _Notice(
                theme: theme,
                text: 'Los sonidos y el volumen se aplican en el teléfono Android. '
                    'Aquí puedes ver y guardar tus preferencias.',
              ),
            ],
            const SizedBox(height: 20),
            _Card(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volume_up_rounded, color: theme.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Volumen de alarma',
                            style: _titleStyle(theme)),
                      ),
                      if (_volume != null)
                        Text(
                          '${(_volume! * 100 / _volumeMax).round()} %',
                          style: TextStyle(
                            fontFamily: theme.fontBody,
                            fontWeight: FontWeight.w800,
                            color: theme.accent,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.volume_mute_rounded, color: theme.muted, size: 20),
                      Expanded(
                        child: Slider(
                          value: (_volume ?? (_volumeMax * 0.7).round())
                              .clamp(0, _volumeMax)
                              .toDouble(),
                          min: 0,
                          max: _volumeMax.toDouble(),
                          divisions: _volumeMax,
                          activeColor: theme.accent,
                          onChanged: _service.supported
                              ? (v) {
                                  setState(() => _volume = v.round());
                                  _service.setAlarmVolume(v.round());
                                }
                              : null,
                        ),
                      ),
                      Icon(Icons.volume_up_rounded, color: theme.muted, size: 20),
                    ],
                  ),
                  Text(
                    'Mientras suena la alarma también puedes subir o bajar el '
                    'volumen con los botones del teléfono.',
                    style: TextStyle(color: theme.muted, fontSize: 12.5),
                  ),
                  if (_volume == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Con el volumen en 0, TaskFlow lo subirá al 40 % cuando suene.',
                        style: TextStyle(color: theme.danger, fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              theme: theme,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.alarm_rounded, color: theme.accent),
                    title: Text('Sonido de alarma', style: _titleStyle(theme)),
                    subtitle: Text(_defaultName, style: TextStyle(color: theme.muted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_service.supported)
                          IconButton(
                            tooltip: 'Escuchar',
                            icon: Icon(
                              _service.previewing == _defaultId
                                  ? Icons.stop_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: theme.accent,
                              size: 30,
                            ),
                            onPressed: () => _service
                                .preview(AlarmSound(_defaultId, _defaultName)),
                          ),
                        Icon(Icons.chevron_right_rounded, color: theme.muted),
                      ],
                    ),
                    onTap: _changeDefault,
                  ),
                  Divider(height: 1, color: theme.border),
                  SwitchListTile.adaptive(
                    secondary: Icon(Icons.trending_up_rounded, color: theme.accent),
                    activeTrackColor: theme.accent,
                    title: Text('Subida gradual', style: _titleStyle(theme)),
                    subtitle: Text('Empieza bajito y sube en 30 segundos',
                        style: TextStyle(color: theme.muted)),
                    value: _crescendo,
                    onChanged: (v) {
                      setState(() => _crescendo = v);
                      _service.setCrescendo(v);
                    },
                  ),
                  Divider(height: 1, color: theme.border),
                  SwitchListTile.adaptive(
                    secondary: Icon(Icons.vibration_rounded, color: theme.accent),
                    activeTrackColor: theme.accent,
                    title: Text('Vibrar', style: _titleStyle(theme)),
                    subtitle: Text('Además del sonido',
                        style: TextStyle(color: theme.muted)),
                    value: _vibrate,
                    onChanged: (v) {
                      setState(() => _vibrate = v);
                      _service.setVibrate(v);
                    },
                  ),
                  Divider(height: 1, color: theme.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer_off_outlined, color: theme.accent),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text('Silenciar si no respondes',
                                  style: _titleStyle(theme)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final m in SoundService.autoSilenceOptions)
                              ChoiceChip(
                                label: Text('$m min'),
                                selected: _autoSilence == m,
                                selectedColor: theme.accent.withValues(alpha: 0.2),
                                onSelected: (_) {
                                  setState(() => _autoSilence = m);
                                  _service.setAutoSilenceMinutes(m);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle('Mi música', theme: theme),
            if (_custom.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 4),
                child: Text(
                  'Usa tus canciones favoritas como alarma. Se guardan solo en '
                  'este teléfono y la app solo puede leer las que elijas.',
                  style: TextStyle(color: theme.muted, fontSize: 13),
                ),
              ),
            for (final s in _custom)
              SoundTile(
                sound: s,
                selected: _defaultId == s.id,
                theme: theme,
                onTap: () => _setDefault(s),
                trailing: IconButton(
                  tooltip: 'Quitar',
                  icon: Icon(Icons.delete_outline_rounded, color: theme.muted),
                  onPressed: () => _removeMusic(s),
                ),
              ),
            AddMusicButton(theme: theme, onTap: _service.supported ? _addMusic : null),
            SectionTitle('Sonidos de TaskFlow', theme: theme),
            for (final s in SoundService.builtIn)
              SoundTile(
                sound: s,
                selected: _defaultId == s.id,
                theme: theme,
                onTap: () => _setDefault(s),
              ),
            const SizedBox(height: 4),
            Text(
              'Toca un sonido para usarlo en todas tus alarmas. Cada tarea '
              'también puede tener el suyo desde su formulario.',
              style: TextStyle(color: theme.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _titleStyle(AppTheme theme) => TextStyle(
      fontFamily: theme.fontBody,
      fontWeight: FontWeight.w700,
      fontSize: 15.5,
      color: theme.text,
    );

/// Cabecera grande de cada sección.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppTheme theme;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final display = theme.titleUppercase ? title.toUpperCase() : title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: TextStyle(fontFamily: theme.fontBody, color: theme.muted, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          display,
          style: TextStyle(
            fontFamily: theme.fontDisplay,
            fontSize: theme.titleSize,
            fontWeight: FontWeight.w800,
            color: theme.text,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final AppTheme theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cardRadius.clamp(12, 24)),
        side: BorderSide(color: theme.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Notice extends StatelessWidget {
  final AppTheme theme;
  final String text;

  const _Notice({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: theme.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
