import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Fade + short rise on first build, staggered by [index]. Content is laid out
/// immediately; only its opacity/offset animate, and reduced motion skips it.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 14, this.scale = false});

  final Widget child;
  final int index;
  final double offset;
  final bool scale;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutQuart);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) {
        final v = _t.value;
        return Opacity(opacity: v, child: child);
      },
    );
  }
}

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.style, this.suffix = ''});

  final num value;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.easeOutQuart,
      builder: (_, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// One-shot paper confetti behind celebratory cards.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 60});

  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();
  late final List<_Piece> _pieces = List.generate(widget.count, (i) => _Piece(math.Random(i * 7919)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
      : x = r.nextDouble(),
        drift = (r.nextDouble() - 0.5) * 0.3,
        speed = 0.6 + r.nextDouble() * 0.6,
        delay = r.nextDouble() * 0.25,
        spin = r.nextDouble() * math.pi * 4,
        size = 5 + r.nextDouble() * 6,
        color = const [AppColors.green, AppColors.violet, Color(0xFFE9C46A), Color(0xFFE76F51), AppColors.charcoal][
            r.nextInt(5)];

  final double x, drift, speed, delay, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(local) * p.speed;
      final x = size.width * (p.x + p.drift * local);
      final paint = Paint()..color = p.color.withValues(alpha: (1 - local).clamp(0, 1) * 0.9 + 0.1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
            const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Soft breathing ring, used for the live recording state.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.color = AppColors.red});

  final Widget child;
  final Color color;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              spreadRadius: 14 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
