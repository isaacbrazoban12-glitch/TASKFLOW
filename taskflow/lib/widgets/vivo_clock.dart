import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_themes.dart';

/// Reloj vivo de la pantalla vacía: esfera con rebote de entrada, agujas que
/// giran una vuelta hasta la hora real, números con pop escalonado, flotación,
/// halo que respira, brillo cada 8 s, segundos digitales con giro y destellos.
/// Un solo ticker continuo + un controlador de entrada; todo en RepaintBoundary.
class VivoClock extends StatefulWidget {
  final double size;
  final TickerProvider vsync;
  final bool paused;

  const VivoClock({
    super.key,
    this.size = 220,
    required this.vsync,
    this.paused = false,
  });

  @override
  State<VivoClock> createState() => _VivoClockState();
}

class _VivoClockState extends State<VivoClock> {
  late final AnimationController _entry;
  late final AnimationController _flip;
  Ticker? _ticker;
  Timer? _minuteTimer;
  Duration _elapsed = Duration.zero;
  int _lastSecond = -1;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 1000),
    );
    _flip = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    _lastSecond = DateTime.now().second;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_reducedMotion) {
      _entry.value = 1;
    } else if (!_entry.isCompleted) {
      _entry.forward();
    }
    _applyTicking();
  }

  @override
  void didUpdateWidget(VivoClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _applyTicking();
  }

  void _applyTicking() {
    _ticker?.dispose();
    _ticker = null;
    _minuteTimer?.cancel();
    _minuteTimer = null;
    if (widget.paused) return;
    if (_reducedMotion) {
      // Solo se actualiza una vez por minuto, sin flotar ni brillos.
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    _ticker = widget.vsync.createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final second = DateTime.now().second;
    if (second != _lastSecond) {
      _lastSecond = second;
      _flip.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _minuteTimer?.cancel();
    _entry.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final elapsedSec = _elapsed.inMicroseconds / 1e6;
    final now = DateTime.now();
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entry, _flip]),
        builder: (context, _) {
          final entryT = Curves.easeOutCubic.transform(_entry.value);
          // Esfera: 0.85 a 1.0 con rebote en la primera mitad.
          final faceT = Curves.easeOutBack.transform(
            (_entry.value / 0.5).clamp(0.0, 1.0),
          );
          final faceScale = 0.85 + 0.15 * faceT;
          // Flote suave: +-4 px en ciclos de 4 s.
          final floatY = _reducedMotion || widget.paused
              ? 0.0
              : math.sin(elapsedSec * 2 * math.pi / 4) * 4;
          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: faceScale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _ClockPainter(
                    theme: theme,
                    now: now,
                    entryT: entryT,
                    elapsedSec: elapsedSec,
                    reducedMotion: _reducedMotion,
                    paused: widget.paused,
                  ),
                  child: Center(
                    child: _SecondsDigit(
                      now: now,
                      flip: _flip,
                      theme: theme,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dígito de segundos con giro vertical cada segundo.
class _SecondsDigit extends StatelessWidget {
  final DateTime now;
  final AnimationController flip;
  final AppTheme theme;

  const _SecondsDigit({
    required this.now,
    required this.flip,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOut.transform(flip.value);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - t)),
        child: Text(
          now.second.toString().padLeft(2, '0'),
          style: TextStyle(
            fontFamily: theme.fontMono ?? theme.fontBody,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.muted,
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final AppTheme theme;
  final DateTime now;
  final double entryT;
  final double elapsedSec;
  final bool reducedMotion;
  final bool paused;

  _ClockPainter({
    required this.theme,
    required this.now,
    required this.entryT,
    required this.elapsedSec,
    required this.reducedMotion,
    required this.paused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Halo que respira con el flote.
    final breathe = reducedMotion || paused
        ? 0.5
        : 0.5 + 0.5 * math.sin(elapsedSec * 2 * math.pi / 4);
    canvas.drawCircle(
      center,
      radius * (1.02 + 0.04 * breathe),
      Paint()..color = theme.accent.withValues(alpha: 0.10 + 0.08 * breathe),
    );

    // Esfera.
    canvas.drawCircle(center, radius, Paint()..color = theme.card);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = theme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Números 1..12 con pop escalonado de 30 ms.
    for (int i = 1; i <= 12; i++) {
      final local =
          ((entryT * 1000 - (i - 1) * 30) / 300).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final pop = Curves.easeOut.transform(local);
      final angle = (i / 12) * 2 * math.pi;
      final pos = center +
          Offset(math.sin(angle), -math.cos(angle)) * radius * 0.78;
      final scale = 0.6 + 0.4 * pop;
      final text = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            fontFamily: theme.fontDisplay,
            fontSize: 15 * scale,
            fontWeight: FontWeight.w700,
            color: theme.text.withValues(alpha: local),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        pos + Offset(-text.width / 2, -text.height / 2),
      );
    }

    // Agujas: giran una vuelta (800 ms) hasta la hora real y luego la siguen.
    final spinT = Curves.easeOutCubic.transform((entryT / 0.8).clamp(0.0, 1.0));
    final spin = (1 - spinT) * 2 * math.pi;
    final ms = now.millisecond / 1000;
    final secAngle = ((now.second + ms) / 60) * 2 * math.pi - spin;
    final minAngle =
        ((now.minute + now.second / 60) / 60) * 2 * math.pi - spin;
    final hourAngle =
        (((now.hour % 12) + now.minute / 60) / 12) * 2 * math.pi - spin;
    _hand(canvas, center, radius * 0.45, hourAngle, theme.text, 7);
    _hand(canvas, center, radius * 0.68, minAngle, theme.text, 5);
    _hand(canvas, center, radius * 0.82, secAngle, theme.accent, 2.5);
    canvas.drawCircle(center, 5, Paint()..color = theme.accent);

    // Destellos que titilan y giran.
    for (int i = 0; i < 6; i++) {
      final phase = i / 6;
      final tw = reducedMotion || paused
          ? 0.4
          : 0.5 + 0.5 * math.sin(elapsedSec * 2.4 + phase * 2 * math.pi);
      final rot = elapsedSec * 0.15 + phase * 2 * math.pi;
      final pos = center +
          Offset(math.cos(rot), math.sin(rot)) * radius * 0.92;
      canvas.drawCircle(
        pos,
        2 + (i % 2),
        Paint()..color = theme.accent.withValues(alpha: 0.25 + 0.35 * tw),
      );
    }

    // Brillo diagonal cada 8 s (franja blanca al 18%, 700 ms).
    if (!reducedMotion && !paused) {
      final cycle = elapsedSec % 8;
      if (cycle < 0.7) {
        final p = cycle / 0.7;
        final angle = -math.pi / 4;
        final dir = Offset(math.cos(angle), math.sin(angle));
        final normal = Offset(-dir.dy, dir.dx);
        final c = center + normal * (2 * radius * (p - 0.5)) * 1.4;
        canvas.drawLine(
          c - dir * radius * 1.5,
          c + dir * radius * 1.5,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18)
            ..strokeWidth = radius * 0.22
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _hand(Canvas canvas, Offset center, double length, double angle,
      Color color, double width) {
    final end =
        center + Offset(math.sin(angle), -math.cos(angle)) * length;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter old) => true;
}
