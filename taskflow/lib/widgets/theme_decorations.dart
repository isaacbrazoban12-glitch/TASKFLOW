import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_themes.dart';

/// Decoraciones de fondo por tema (puntos 12-15), solo decorativas y detrás
/// del contenido. Cada una usa su propio controlador (mismo vsync de la
/// pantalla) y lo libera en dispose; se pausan en background.
class ThemeDecorations extends StatelessWidget {
  final TickerProvider vsync;
  final bool paused;

  const ThemeDecorations({
    super.key,
    required this.vsync,
    this.paused = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    final disabled = MediaQuery.of(context).disableAnimations;
    if (disabled && theme.id != AppThemeId.medianoche) {
      // Medianoche mantiene sus puntos fijos para no dejar el fondo vacío.
      return const SizedBox.expand();
    }
    switch (theme.id) {
      case AppThemeId.rosa:
        return _RosaHearts(vsync: vsync, paused: paused, theme: theme);
      case AppThemeId.medianoche:
        return _NightDots(vsync: vsync, paused: paused, theme: theme);
      case AppThemeId.grafito:
        return const SizedBox.expand();
      case AppThemeId.bosque:
        return _Fireflies(vsync: vsync, paused: paused, theme: theme);
    }
  }
}

class _Loop extends StatefulWidget {
  final TickerProvider vsync;
  final bool paused;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  const _Loop({
    required this.vsync,
    required this.paused,
    required this.duration,
    required this.builder,
  });

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: widget.vsync, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyLoop();
  }

  @override
  void didUpdateWidget(_Loop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _applyLoop();
  }

  void _applyLoop() {
    if (widget.paused || MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _controller.value),
      ),
    );
  }
}

/// Rosa: 5 corazoncitos que suben y se desvanecen, en bucle.
class _RosaHearts extends StatelessWidget {
  final TickerProvider vsync;
  final bool paused;
  final AppTheme theme;

  const _RosaHearts({
    required this.vsync,
    required this.paused,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty) return const SizedBox.expand();
        return _Loop(
          vsync: vsync,
          paused: paused,
          duration: const Duration(seconds: 9),
          builder: (context, t) => CustomPaint(
            size: size,
            painter: _HeartsPainter(theme: theme, t: t),
          ),
        );
      },
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final AppTheme theme;
  final double t;

  _HeartsPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 5; i++) {
      final phase = (t + i / 5) % 1.0;
      final x = size.width * ((0.15 + 0.7 * ((i * 0.37) % 1.0)) +
          0.03 * math.sin(phase * 2 * math.pi * 2 + i));
      final y = size.height * (1.05 - 1.15 * phase);
      final alpha = (phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85)
              .clamp(0.0, 1.0) *
          0.25;
      final s = 8.0 + (i % 2) * 2.0 + (i % 3);
      _heart(
        canvas,
        Offset(x, y),
        s,
        theme.accent.withValues(alpha: alpha),
      );
    }
  }

  void _heart(Canvas canvas, Offset c, double s, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.35)
      ..cubicTo(c.dx - s * 0.6, c.dy - s * 0.1, c.dx - s * 0.35, c.dy - s * 0.5,
          c.dx, c.dy - s * 0.2)
      ..cubicTo(c.dx + s * 0.35, c.dy - s * 0.5, c.dx + s * 0.6, c.dy - s * 0.1,
          c.dx, c.dy + s * 0.35)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.t != t;
}

/// Medianoche: puntos de luz que parpadean (el brillo del borde va aparte).
class _NightDots extends StatelessWidget {
  final TickerProvider vsync;
  final bool paused;
  final AppTheme theme;

  const _NightDots({
    required this.vsync,
    required this.paused,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty) return const SizedBox.expand();
        return _Loop(
          vsync: vsync,
          paused: paused,
          duration: const Duration(seconds: 5),
          builder: (context, t) => CustomPaint(
            size: size,
            painter: _DotsPainter(theme: theme, t: t),
          ),
        );
      },
    );
  }
}

class _DotsPainter extends CustomPainter {
  final AppTheme theme;
  final double t;

  _DotsPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 14; i++) {
      final fx = (i * 0.173 + 0.07) % 1.0;
      final fy = (i * 0.311 + 0.13) % 1.0;
      final tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 1.7);
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        1.5 + (i % 2),
        Paint()..color = theme.accent.withValues(alpha: 0.08 + 0.18 * tw),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.t != t;
}

/// Bosque: 6 luciérnagas con movimiento suave y parpadeo.
class _Fireflies extends StatelessWidget {
  final TickerProvider vsync;
  final bool paused;
  final AppTheme theme;

  const _Fireflies({
    required this.vsync,
    required this.paused,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty) return const SizedBox.expand();
        return _Loop(
          vsync: vsync,
          paused: paused,
          duration: const Duration(seconds: 12),
          builder: (context, t) => CustomPaint(
            size: size,
            painter: _FirefliesPainter(theme: theme, t: t),
          ),
        );
      },
    );
  }
}

class _FirefliesPainter extends CustomPainter {
  final AppTheme theme;
  final double t;

  _FirefliesPainter({required this.theme, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 6; i++) {
      final seed = i * 2.39 + 0.7;
      final x = size.width *
          (0.5 +
              0.38 * math.sin(t * 2 * math.pi * 0.9 + seed) *
                  math.sin(t * 2 * math.pi * 0.23 + seed * 1.3));
      final y = size.height *
          (0.5 +
              0.40 * math.cos(t * 2 * math.pi * 0.7 + seed * 0.8) *
                  math.sin(t * 2 * math.pi * 0.31 + seed));
      final blink = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.7 + seed * 2.1);
      final r = 4.0 + (i % 3) * 1.0;
      final glow = theme.accent;
      canvas.drawCircle(
        Offset(x, y),
        r * 2.4,
        Paint()..color = glow.withValues(alpha: 0.10 + 0.10 * blink),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = glow.withValues(alpha: 0.45 + 0.40 * blink),
      );
    }
  }

  @override
  bool shouldRepaint(_FirefliesPainter old) => old.t != t;
}

/// Medianoche: brillo cian que recorre el borde de la tarjeta cada 6 s.
class BorderGlow extends StatefulWidget {
  final double radius;
  final TickerProvider vsync;
  final bool paused;
  final Widget child;

  const BorderGlow({
    super.key,
    required this.radius,
    required this.vsync,
    this.paused = false,
    required this.child,
  });

  @override
  State<BorderGlow> createState() => _BorderGlowState();
}

class _BorderGlowState extends State<BorderGlow> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: widget.vsync,
      duration: const Duration(seconds: 6),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyLoop();
  }

  @override
  void didUpdateWidget(BorderGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _applyLoop();
  }

  void _applyLoop() {
    if (widget.paused || MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeScope.of(context);
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _BorderGlowPainter(
              progress: _controller.value,
              color: theme.accent,
              radius: widget.radius,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _BorderGlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double radius;

  _BorderGlowPainter({
    required this.progress,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(radius));
    final perimeter = _perimeter(rrect);
    final target = progress * perimeter;
    final point = _pointAt(rrect, target, perimeter);
    for (final entry in [(10.0, 0.10), (6.0, 0.25), (3.0, 0.60)]) {
      canvas.drawCircle(
        point,
        entry.$1,
        Paint()..color = color.withValues(alpha: entry.$2),
      );
    }
  }

  double _perimeter(RRect r) {
    // Perímetro aproximado del rectángulo redondeado.
    final straight =
        2 * (r.width - 2 * r.tlRadiusX) + 2 * (r.height - 2 * r.tlRadiusY);
    const arc = 2 * math.pi; // cuatro cuartos de radio medio ~ r
    return straight + arc * r.tlRadiusX;
  }

  Offset _pointAt(RRect r, double dist, double total) {
    double d = dist % total;
    final w = r.width;
    final h = r.height;
    final cr = r.tlRadiusX;
    // Recorrido simplificado por el rectángulo (las esquinas se redondean).
    final top = w - 2 * cr;
    final side = h - 2 * cr;
    final arcLen = math.pi / 2 * cr;
    final segs = [top, arcLen, side, arcLen, top, arcLen, side, arcLen];
    int i = 0;
    while (i < segs.length && d > segs[i]) {
      d -= segs[i];
      i++;
    }
    final x0 = cr;
    final y0 = 0.0;
    switch (i) {
      case 0:
        return Offset(r.left + x0 + d, r.top + y0);
      case 1:
        final a = -math.pi / 2 + (d / arcLen) * (math.pi / 2);
        return Offset(r.right - cr + cr * math.cos(a), r.top + cr + cr * math.sin(a));
      case 2:
        return Offset(r.right, r.top + cr + d);
      case 3:
        final a = (d / arcLen) * (math.pi / 2);
        return Offset(r.right - cr + cr * math.cos(a), r.bottom - cr + cr * math.sin(a));
      case 4:
        return Offset(r.right - cr - d, r.bottom);
      case 5:
        final a = math.pi / 2 + (d / arcLen) * (math.pi / 2);
        return Offset(r.left + cr + cr * math.cos(a), r.bottom - cr + cr * math.sin(a));
      case 6:
        return Offset(r.left, r.bottom - cr - d);
      default:
        final a = math.pi + (d / arcLen) * (math.pi / 2);
        return Offset(r.left + cr + cr * math.cos(a), r.top + cr + cr * math.sin(a));
    }
  }

  @override
  bool shouldRepaint(_BorderGlowPainter old) => old.progress != progress;
}
