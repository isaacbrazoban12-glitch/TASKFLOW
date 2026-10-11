import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_themes.dart';

/// Reloj vivo de la pantalla vacía, copia al píxel del SVG de referencia
/// (viewBox 230x230): borde con degradado, esfera con degradado radial,
/// marcas menores/mayores, números 1-12 en Playfair, "TASKFLOW", ventanita
/// del día, agujas, segundero con estela, destellos de 4 puntas y halo.
///
/// La hora, los segundos, AM/PM y el día salen de [DateTime.now()] y se
/// actualizan con un [Ticker] continuo; el segundero se desliza sin saltos
/// (usa milisegundos). Conserva la entrada (rebote de esfera, pop de números
/// y vuelta de agujas), la flotación suave, la pausa en segundo plano y el
/// modo sin animaciones.
class VivoClock extends StatefulWidget {
  final double size;
  final TickerProvider vsync;
  final bool paused;

  const VivoClock({
    super.key,
    this.size = 230,
    required this.vsync,
    this.paused = false,
  });

  @override
  State<VivoClock> createState() => _VivoClockState();
}

class _VivoClockState extends State<VivoClock> {
  late final AnimationController _entry;
  Ticker? _ticker;
  Timer? _minuteTimer;
  Duration _elapsed = Duration.zero;
  bool _reducedMotion = false;
  bool? _tickingPaused;
  bool? _tickingReduced;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    _reducedMotion = reduced;
    if (reduced) {
      _entry.value = 1;
    } else if (!_entry.isCompleted && _entry.value == 0) {
      _entry.forward();
    } else if (!reduced && !_entry.isCompleted) {
      _entry.forward();
    }
    // No reiniciar el ticker si solo cambió el MediaQuery: solo cuando
    // cambian paused/reduced o aún no hay ticker.
    if (_tickingPaused != widget.paused ||
        _tickingReduced != reduced ||
        (_ticker == null && _minuteTimer == null)) {
      _applyTicking();
    }
  }

  @override
  void didUpdateWidget(VivoClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _applyTicking();
  }

  void _applyTicking() {
    _tickingPaused = widget.paused;
    _tickingReduced = _reducedMotion;
    _ticker?.dispose();
    _ticker = null;
    _minuteTimer?.cancel();
    _minuteTimer = null;
    if (widget.paused) return;
    if (_reducedMotion) {
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _minuteTimer?.cancel();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final palette = clockPalette(theme.id);
    final elapsedSec = _elapsed.inMicroseconds / 1e6;
    final now = DateTime.now();
    final shadowColor = theme.id == AppThemeId.rosa
        ? const Color(0x593A2557)
        : Colors.black.withValues(alpha: 0.35);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, _) {
          final faceT = Curves.easeOutBack.transform(
            (_entry.value / 0.5).clamp(0.0, 1.0),
          );
          final faceScale = 0.85 + 0.15 * faceT;
          final entryT = Curves.easeOutCubic.transform(_entry.value);
          // Flotación suave: +-4 px en ciclos de 4 s (congelada sin
          // animaciones o en pausa).
          final frozen = _reducedMotion || widget.paused;
          final floatY =
              frozen ? 0.0 : math.sin(elapsedSec * 2 * math.pi / 4) * 4;
          return Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(
              scale: faceScale,
              child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Halo que respira (inset -16, br 3 s alternate).
                  Positioned(
                    left: -16,
                    top: -16,
                    right: -16,
                    bottom: -16,
                    child: _Halo(
                      color: palette.halo,
                      elapsedSec: elapsedSec,
                      disabled: _reducedMotion || widget.paused,
                    ),
                  ),
                  // Anillo exterior fino (inset -8).
                  Positioned(
                    left: -8,
                    top: -8,
                    right: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.halo.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  // Destellos de 4 puntas (tw 2.6 s).
                  ..._sparkles(
                    widget.size,
                    palette,
                    elapsedSec,
                    _reducedMotion || widget.paused,
                  ),
                  // Esfera con sombra del SVG.
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            offset: const Offset(0, 14),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _ClockFacePainter(
                          theme: theme,
                          palette: palette,
                          now: now,
                          entryT: entryT,
                          elapsedSec: elapsedSec,
                          reducedMotion: _reducedMotion,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sparkles(
    double size,
    ClockPalette palette,
    double elapsedSec,
    bool frozen,
  ) {
    // (size, left, top, color, delay) copiados del HTML para 230.
    final k = size / 230;
    final defs = [
      (22.0 * k, -58.0 * k, 18.0 * k, palette.sparkA, 0.0),
      (16.0 * k, size + 34.0 * k, 66.0 * k, palette.sparkB, 0.8),
      (14.0 * k, -42.0 * k, size - 40.0 * k, palette.sparkC, 1.5),
      (24.0 * k, size + 34.0 * k, size - 34.0 * k, palette.sparkA, 0.4),
    ];
    return [
      for (final d in defs)
        Positioned(
          left: d.$2,
          top: d.$3,
          child: _Sparkle(
            size: d.$1,
            color: d.$4,
            delay: d.$5,
            elapsedSec: frozen ? 0.65 : elapsedSec,
          ),
        ),
    ];
  }
}

/// Halo exterior con respiración br (escala 1→1.06, opacidad .18→.08).
class _Halo extends StatelessWidget {
  final Color color;
  final double elapsedSec;
  final bool disabled;

  const _Halo({
    required this.color,
    required this.elapsedSec,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final phase = disabled
        ? 0.5
        : 0.5 + 0.5 * math.sin(elapsedSec * 2 * math.pi / 3);
    final scale = 1 + 0.06 * phase;
    final opacity = 0.18 - 0.10 * phase;
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

/// Destello de 4 puntas del SVG (tw 2.6 s).
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  final double delay;
  final double elapsedSec;

  const _Sparkle({
    required this.size,
    required this.color,
    required this.delay,
    required this.elapsedSec,
  });

  @override
  Widget build(BuildContext context) {
    const period = 2.6;
    final t = ((elapsedSec + delay) % period) / period;
    final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi - math.pi / 2);
    final scale = 0.6 + 0.5 * wave;
    final opacity = 0.35 + 0.65 * wave;
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: wave * 20 * math.pi / 180,
        child: Opacity(
          opacity: opacity,
          child: CustomPaint(
            size: Size(size, size),
            painter: _StarPainter(color: color),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;

  _StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // M12 0C12 7 17 12 24 12C17 12 12 17 12 24C12 17 7 12 0 12C7 12 12 7 12 0Z
    final k = size.width / 24;
    final path = Path()
      ..moveTo(12 * k, 0)
      ..cubicTo(12 * k, 7 * k, 17 * k, 12 * k, 24 * k, 12 * k)
      ..cubicTo(17 * k, 12 * k, 12 * k, 17 * k, 12 * k, 24 * k)
      ..cubicTo(12 * k, 17 * k, 7 * k, 12 * k, 0, 12 * k)
      ..cubicTo(7 * k, 12 * k, 12 * k, 7 * k, 12 * k, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

class _ClockFacePainter extends CustomPainter {
  final AppTheme theme;
  final ClockPalette palette;
  final DateTime now;
  final double entryT;
  final double elapsedSec;
  final bool reducedMotion;

  _ClockFacePainter({
    required this.theme,
    required this.palette,
    required this.now,
    required this.entryT,
    required this.elapsedSec,
    required this.reducedMotion,
  });

  static const double _vb = 230;
  static const double _cx = 115;
  static const double _cy = 115;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _vb;
    canvas.save();
    canvas.scale(s);
    const center = Offset(_cx, _cy);

    // Esfera con degradado radial (50% 38% r70%).
    final faceRect = Rect.fromCircle(center: center, radius: 112);
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 0.95,
        colors: [palette.faceFrom, palette.faceTo],
        stops: const [0.0, 1.0],
      ).createShader(faceRect);
    canvas.drawCircle(center, 112, facePaint);

    // Borde con degradado lineal.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFD3E4),
          Color(0xFFC93C74),
          Color(0xFF8F2A55),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(faceRect);
    // Para los otros temas se tiñe con su paleta manteniendo el diseño.
    if (theme.id != AppThemeId.rosa) {
      ringPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.ringLight, palette.ringMid, palette.ringDark],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(faceRect);
    }
    canvas.drawCircle(center, 112, ringPaint);

    // Círculo interior fino r104.
    canvas.drawCircle(
      center,
      104,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.tick.withValues(alpha: 0.25),
    );

    // Brillo diagonal recortado a r104.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: 104)));
    final gloss = Path()
      ..moveTo(0, 70)
      ..lineTo(70, 0)
      ..lineTo(150, 0)
      ..lineTo(0, 150)
      ..close();
    canvas.drawPath(
      gloss,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07),
    );
    canvas.restore();

    // Marcas menores (48) y mayores (12).
    const minors = [
      6, 12, 18, 24, 36, 42, 48, 54, 66, 72, 78, 84, 96, 102, 108, 114,
      126, 132, 138, 144, 156, 162, 168, 174, 186, 192, 198, 204, 216,
      222, 228, 234, 246, 252, 258, 264, 276, 282, 288, 294, 306, 312,
      318, 324, 336, 342, 348, 354,
    ];
    for (final deg in minors) {
      _tick(canvas, center, deg.toDouble(), 100, 96, palette.tick, 0.4, 1);
    }
    const majors = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330];
    for (final deg in majors) {
      _tick(
        canvas,
        center,
        deg.toDouble(),
        100,
        89,
        theme.id == AppThemeId.rosa
            ? const Color(0xFFFFD3E4)
            : palette.numbersQuarter,
        1.0,
        3,
      );
    }

    // Números 1..12 con pop escalonado de entrada (30 ms).
    const pos = {
      1: Offset(150.0, 54.4),
      2: Offset(175.6, 80.0),
      3: Offset(185.0, 115.0),
      4: Offset(175.6, 150.0),
      5: Offset(150.0, 175.6),
      6: Offset(115.0, 185.0),
      7: Offset(80.0, 175.6),
      8: Offset(54.4, 150.0),
      9: Offset(45.0, 115.0),
      10: Offset(54.4, 80.0),
      11: Offset(80.0, 54.4),
      12: Offset(115.0, 45.0),
    };
    for (int i = 1; i <= 12; i++) {
      final local = ((entryT * 1000 - (i - 1) * 30) / 300).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final pop = Curves.easeOut.transform(local);
      final quarter = i % 3 == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: (quarter ? 22 : 16) * (0.6 + 0.4 * pop),
            fontWeight: FontWeight.w700,
            color: (quarter ? palette.numbersQuarter : palette.numbers)
                .withValues(alpha: local),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = pos[i]!;
      tp.paint(canvas, p + Offset(-tp.width / 2, -tp.height / 2));
    }

    // Marca TASKFLOW.
    final brand = TextPainter(
      text: TextSpan(
        text: 'TASKFLOW',
        style: TextStyle(
          fontFamily: theme.fontBody,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
          color: palette.brand.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    brand.paint(canvas, Offset(115 - brand.width / 2, 86 - brand.height / 2));

    // Ventanita del día.
    final winRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(88, 140, 54, 22),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      winRect,
      Paint()..color = palette.winBg.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      winRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.winBorder.withValues(alpha: 0.25),
    );
    final winText = TextPainter(
      text: TextSpan(
        text: _dayWindow(now),
        style: TextStyle(
          fontFamily: theme.fontBody,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.winText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    winText.paint(
      canvas,
      Offset(115 - winText.width / 2, 155 - winText.height / 2 - 1),
    );

    // Agujas con vuelta de entrada (800 ms).
    final spinT = Curves.easeOutCubic.transform((entryT / 0.8).clamp(0.0, 1.0));
    final spin = (1 - spinT) * 2 * math.pi;
    final secFloat = reducedMotion
        ? now.second.toDouble()
        : now.second + now.millisecond / 1000 + now.microsecond / 1e6;
    final secAngle = (secFloat / 60) * 2 * math.pi - spin;
    final minAngle =
        ((now.minute + now.second / 60) / 60) * 2 * math.pi - spin;
    final hourAngle =
        (((now.hour % 12) + now.minute / 60 + now.second / 3600) / 12) *
                2 *
                math.pi -
            spin;
    _hand(
      canvas,
      center,
      const [Offset(115, 58), Offset(120, 115), Offset(115, 125), Offset(110, 115)],
      hourAngle,
      palette.hands,
    );
    _hand(
      canvas,
      center,
      const [Offset(115, 32), Offset(119, 115), Offset(115, 124), Offset(111, 115)],
      minAngle,
      palette.hands,
    );

    // Segundero con estela.
    final secPaint = Paint()..color = palette.second;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(secAngle);
    // Estelas de 30° y 12° hacia atrás.
    for (final entry in [(30.0, 0.12), (12.0, 0.22)]) {
      final sweep = entry.$1 * math.pi / 180;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(0, -100)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: 100), -math.pi / 2, -sweep, false)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = palette.second.withValues(alpha: entry.$2),
      );
    }
    canvas.drawLine(
      const Offset(0, 15),
      const Offset(0, -93),
      secPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(0, 15), 4, secPaint);
    canvas.drawCircle(const Offset(0, -65), 4.5, secPaint);
    canvas.restore();

    // Buje central.
    canvas.drawCircle(
      center,
      12,
      Paint()..color = palette.second.withValues(alpha: 0.25),
    );
    canvas.drawCircle(center, 7, Paint()..color = palette.second);
    canvas.drawCircle(center, 3, Paint()..color = palette.hub);

    canvas.restore();
  }

  void _tick(
    Canvas canvas,
    Offset center,
    double deg,
    double rOuter,
    double rInner,
    Color color,
    double opacity,
    double width,
  ) {
    final a = deg * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(
      center + dir * rInner,
      center + dir * rOuter,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = width
        ..strokeCap =
            width > 1 ? StrokeCap.round : StrokeCap.butt,
    );
  }

  void _hand(
    Canvas canvas,
    Offset center,
    List<Offset> points,
    double angle,
    Color color,
  ) {
    // Rotación horaria en coordenadas de pantalla (y hacia abajo):
    // x' = x cos − y sin, y' = x sin + y cos.
    final pts = points.map((p) {
      final v = p - center;
      final c = math.cos(angle);
      final s = math.sin(angle);
      return center + Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    }).toList();
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  String _dayWindow(DateTime d) {
    const short = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return '${short[d.weekday - 1]} ${d.day}';
  }

  @override
  bool shouldRepaint(_ClockFacePainter old) => true;
}

/// Hora digital con segundos (44 px) + AM/PM, del HTML.
/// Usa su propio [Ticker] para actualizarse cada cuadro.
class ClockDigitalTime extends StatefulWidget {
  const ClockDigitalTime({super.key});

  @override
  State<ClockDigitalTime> createState() => _ClockDigitalTimeState();
}

class _ClockDigitalTimeState extends State<ClockDigitalTime> {
  Ticker? _ticker;
  bool? _tickingReduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    if (_ticker == null || _tickingReduced != reduced) {
      _tickingReduced = reduced;
      _ticker?.dispose();
      if (reduced) {
        _ticker = null;
      } else {
        _ticker = Ticker((_) {
          if (mounted) setState(() {});
        })
          ..start();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final now = DateTime.now();
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final hm = '$h12:${now.minute.toString().padLeft(2, '0')}';
    final ss = now.second.toString().padLeft(2, '0');
    final ap = now.hour < 12 ? 'AM' : 'PM';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hm,
          style: TextStyle(
            fontFamily: theme.fontDisplay,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.text,
          ),
        ),
        Text(
          ':',
          style: TextStyle(
            fontFamily: theme.fontDisplay,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: theme.accent,
          ),
        ),
        Text(
          ss,
          style: TextStyle(
            fontFamily: theme.fontDisplay,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.accent,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            ap,
            style: TextStyle(
              fontFamily: theme.fontBody,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.28,
              color: theme.muted,
            ),
          ),
        ),
      ],
    );
  }
}
