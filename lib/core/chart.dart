import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// Per-day line chart: dashed day grid, scrollable, tap a day to inspect.
/// Draws itself in on first build.
class DayLineChart extends StatefulWidget {
  const DayLineChart({
    super.key,
    required this.dates,
    required this.values,
    required this.format,
    this.selected,
    this.onSelect,
    this.reference,
    this.minValue,
    this.height = 250,
  });

  final List<DateTime> dates;
  final List<double?> values;
  final String Function(double) format;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final double? reference;
  final double? minValue;
  final double height;

  @override
  State<DayLineChart> createState() => _DayLineChartState();
}

class _DayLineChartState extends State<DayLineChart> with SingleTickerProviderStateMixin {
  static const step = 52.0;
  static const left = 34.0;
  final _scroll = ScrollController();
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _draw.value = reduceMotion(context) ? 1 : 0;
      _draw.forward();
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(covariant DayLineChart old) {
    super.didUpdateWidget(old);
    if (old.values != widget.values) {
      _draw.forward(from: reduceMotion(context) ? 1 : 0);
    }
    if (old.selected != widget.selected || old.dates.length != widget.dates.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    final i = widget.selected ?? widget.dates.length - 1;
    final target = (left + step * i - _scroll.position.viewportDimension / 2 + step / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 360), curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = left + step * widget.dates.length + 12;
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: GestureDetector(
          onTapUp: (e) {
            final i = ((e.localPosition.dx - left - step / 2) / step).round();
            if (i >= 0 && i < widget.dates.length) widget.onSelect?.call(i);
          },
          child: AnimatedBuilder(
            animation: _draw,
            builder: (_, _) => CustomPaint(
              size: Size(width, widget.height),
              painter: _Painter(
                dates: widget.dates,
                values: widget.values,
                selected: widget.selected,
                format: widget.format,
                reference: widget.reference,
                minValue: widget.minValue,
                progress: Curves.easeOutQuart.transform(_draw.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter({
    required this.dates,
    required this.values,
    required this.selected,
    required this.format,
    required this.progress,
    this.reference,
    this.minValue,
  });

  final List<DateTime> dates;
  final List<double?> values;
  final int? selected;
  final String Function(double) format;
  final double progress;
  final double? reference;
  final double? minValue;

  static const _top = 40.0;
  static const _bottom = 42.0;

  void _text(Canvas c, String s, Offset at, TextStyle style, {bool center = false}) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const step = _DayLineChartState.step;
    const left = _DayLineChartState.left;
    final present = values.whereType<double>().toList();
    var lo = minValue ?? 0;
    var hi = present.isEmpty ? 5.0 : present.reduce(math.max);
    if (reference != null) hi = math.max(hi, reference!);
    if (minValue != null && present.isNotEmpty) lo = math.min(lo, present.reduce(math.min));
    hi = hi <= lo ? lo + 5 : lo + ((hi - lo) * 1.25).ceilToDouble();
    final chartH = size.height - _top - _bottom;
    double y(double v) => _top + chartH * (1 - (v - lo) / (hi - lo));
    double x(int i) => left + step * i + step / 2;

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    const label = TextStyle(fontSize: 10, color: AppColors.ink3, fontWeight: FontWeight.w500);
    for (var k = 0; k <= 5; k++) {
      final v = lo + (hi - lo) * k / 5;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), grid);
      _text(canvas, format(v).replaceAll(' ч', ''), Offset(2, y(v) - 7), label);
    }
    final dash = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < dates.length; i++) {
      for (double dy = _top; dy < size.height - _bottom; dy += 6) {
        canvas.drawLine(Offset(x(i), dy), Offset(x(i), dy + 3), dash);
      }
      final d = dates[i];
      final isSel = i == selected;
      _text(canvas, '${d.day}', Offset(x(i), size.height - _bottom + 8),
          label.copyWith(fontSize: 12, color: isSel ? AppColors.ink : AppColors.ink3, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500),
          center: true);
      _text(canvas, _weekdays[d.weekday - 1], Offset(x(i), size.height - _bottom + 24),
          label.copyWith(color: isSel ? AppColors.ink : AppColors.ink4, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500),
          center: true);
    }
    if (reference != null) {
      final paint = Paint()
        ..color = AppColors.violet.withValues(alpha: 0.55)
        ..strokeWidth = 1.2;
      for (double dx = left; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, y(reference!)), Offset(dx + 4, y(reference!)), paint);
      }
    }

    // Line, revealed left to right.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, left + (size.width - left) * progress, size.height));
    final line = Paint()
      ..color = AppColors.charcoal
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      final p = Offset(x(i), y(v));
      path == null ? path = (Path()..moveTo(p.dx, p.dy)) : path.lineTo(p.dx, p.dy);
    }
    if (path != null) canvas.drawPath(path, line);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(x(i), y(v));
      if (i == selected) canvas.drawCircle(p, 9, Paint()..color = AppColors.chip);
      canvas.drawCircle(p, i == selected ? 5 : 3.5, Paint()..color = AppColors.charcoal);
    }
    canvas.restore();

    final sel = selected;
    if (sel != null && sel < values.length && values[sel] != null) {
      final p = Offset(x(sel), y(values[sel]!));
      final d = dates[sel];
      final text = '${d.day}, ${_weekdays[d.weekday - 1]} · ${format(values[sel]!)}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + 20;
      final l = (p.dx - w / 2).clamp(left, size.width - w - 4);
      final top = math.max(2.0, p.dy - 42);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l, top, w, 28), const Radius.circular(10)),
          Paint()..color = AppColors.charcoal.withValues(alpha: progress));
      tp.paint(canvas, Offset(l + 10, top + (28 - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.progress != progress || old.selected != selected || old.values != values;
}
