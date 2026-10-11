import 'package:flutter/material.dart';

/// Entrada en cascada: sube 16 px y aparece en 450 ms con easeOutCubic,
/// empezando tras [index] * [stepMs] milisegundos.
/// Con [bounce], entra con rebote (escala 0.9 a 1.0, easeOutBack).
/// Con [slideHorizontal], el desliz es lateral rápido ([durationMs]) en vez de
/// vertical (Grafito).
/// Un TickerProvider por pantalla: el [vsync] lo pone el dueño (HomePage).
class StaggeredEntrance extends StatefulWidget {
  final int index;
  final int stepMs;
  final int durationMs;
  final bool bounce;
  final bool slideHorizontal;
  final TickerProvider vsync;
  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    this.stepMs = 70,
    this.durationMs = 450,
    this.bounce = false,
    this.slideHorizontal = false,
    required this.vsync,
    required this.child,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _shift;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: widget.vsync,
      duration: Duration(milliseconds: widget.durationMs),
      value: MediaQuery.of(context).disableAnimations ? 1 : 0,
    );
    if (_controller.value < 1) {
      Future.delayed(Duration(milliseconds: widget.index * widget.stepMs), () {
        if (mounted) _controller.forward();
      });
    }
    final curved =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fade = curved;
    _shift = Tween<double>(begin: 16, end: 0).animate(curved);
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
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
        builder: (context, child) {
          final dx = widget.slideHorizontal ? _shift.value : 0.0;
          final dy = widget.slideHorizontal ? 0.0 : _shift.value;
          Widget out = Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(opacity: _fade.value, child: child),
          );
          if (widget.bounce) {
            out = Transform.scale(scale: _scale.value, child: out);
          }
          return out;
        },
        child: widget.child,
      ),
    );
  }
}
