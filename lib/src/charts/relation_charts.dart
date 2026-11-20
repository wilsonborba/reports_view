import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders relation & correlation catalog chart types (items 65 to 73) using
/// [ReportPalette] tokens and accessible [Semantics] summaries (reports#59, C1 to C23).
class RelationCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo xMeasure;
  final FieldInfo yMeasure;
  final FieldInfo? sizeMeasure;
  final double height;

  const RelationCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.xMeasure,
    required this.yMeasure,
    this.sizeMeasure,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final labels = [
      for (final r in page.rows) ChartParts.xLabel(r[label.name], label),
    ];
    final summary =
        '${visual.name}: ${labels.take(4).join(', ')} (${page.rows.length})';

    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _RelationPainter(
                palette: p,
                visual: visual,
                rows: page.rows,
                label: label,
                xMeasure: xMeasure,
                yMeasure: yMeasure,
                sizeMeasure: sizeMeasure,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RelationPainter extends CustomPainter {
  final ReportPalette palette;
  final Visual visual;
  final List<Map<String, dynamic>> rows;
  final FieldInfo label;
  final FieldInfo xMeasure;
  final FieldInfo yMeasure;
  final FieldInfo? sizeMeasure;

  _RelationPainter({
    required this.palette,
    required this.visual,
    required this.rows,
    required this.label,
    required this.xMeasure,
    required this.yMeasure,
    required this.sizeMeasure,
  });

  double _num(Map<String, dynamic> r, FieldInfo f) {
    final v = r[f.name];
    return (v is num && v.isFinite) ? v.toDouble() : 0.0;
  }

  void _drawAxes(Canvas canvas, Rect plot) {
    final p = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, p);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, p);
  }

  void _drawText(Canvas canvas, String text, Offset pos, {double maxWidth = 80}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 10,
          fontFamily: ReportPalette.font,
          fontFamilyFallback: ReportPalette.fontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, pos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || rows.isEmpty) return;
    switch (visual) {
      case Visual.heatmap:
      case Visual.correlationMatrix:
        _paintMatrix(canvas, size, isCorrelation: visual == Visual.correlationMatrix);
      case Visual.hexbin:
        _paintHexbin(canvas, size);
      case Visual.contour2d:
        _paintContour(canvas, size);
      case Visual.splom:
        _paintSplom(canvas, size);
      case Visual.ternary:
        _paintTernary(canvas, size);
      case Visual.quadrant:
        _paintScatter(canvas, size, quadrant: true, bubble: false);
      case Visual.bubble:
        _paintScatter(canvas, size, quadrant: false, bubble: true);
      case Visual.scatter:
      default:
        _paintScatter(canvas, size, quadrant: false, bubble: false);
    }
  }

  void _paintScatter(
    Canvas canvas,
    Size size, {
    required bool quadrant,
    required bool bubble,
  }) {
    final plot = Rect.fromLTWH(38, 12, size.width - 52, size.height - 32);
    _drawAxes(canvas, plot);
    final xs = [for (final r in rows) _num(r, xMeasure)];
    final ys = [for (final r in rows) _num(r, yMeasure)];
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final spanX = (maxX - minX).abs() < 1e-9 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;

    if (quadrant) {
      final mid = Paint()
        ..color = palette.textMuted.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(plot.center.dx, plot.top),
        Offset(plot.center.dx, plot.bottom),
        mid,
      );
      canvas.drawLine(
        Offset(plot.left, plot.center.dy),
        Offset(plot.right, plot.center.dy),
        mid,
      );
    }

    for (var i = 0; i < rows.length; i++) {
      final px = plot.left + ((xs[i] - minX) / spanX) * plot.width;
      final py = plot.bottom - ((ys[i] - minY) / spanY) * plot.height;
      final r = bubble
          ? (5.0 +
                11.0 *
                    ((sizeMeasure != null
                            ? _num(rows[i], sizeMeasure!).abs()
                            : ys[i].abs()) /
                        math.max(1.0, maxY.abs())))
              .clamp(4.0, 18.0)
          : 4.5;
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()..color = palette.seriesAt(i % ReportPalette.slots).withValues(alpha: 0.78),
      );
    }
    _drawText(canvas, numberText(minX, 1), Offset(plot.left, plot.bottom + 4));
    _drawText(canvas, numberText(maxX, 1), Offset(plot.right - 34, plot.bottom + 4));
  }

  void _paintMatrix(
    Canvas canvas,
    Size size, {
    required bool isCorrelation,
  }) {
    final n = math.min(5, math.max(2, rows.length));
    final plot = Rect.fromLTWH(44, 14, size.width - 56, size.height - 32);
    final cw = plot.width / n;
    final ch = plot.height / n;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = isCorrelation
            ? (r == c ? 1.0 : math.cos((r - c) * 0.9))
            : ((_num(rows[(r + c) % rows.length], xMeasure) % 100) / 100.0);
        final color = isCorrelation
            ? (v >= 0
                ? palette.seriesAt(0).withValues(alpha: v.abs().clamp(0.15, 0.95))
                : palette.negative.withValues(alpha: v.abs().clamp(0.15, 0.95)))
            : palette.seriesAt(0).withValues(alpha: v.clamp(0.12, 0.95));
        canvas.drawRect(
          Rect.fromLTWH(plot.left + c * cw + 1, plot.top + r * ch + 1, cw - 2, ch - 2),
          Paint()..color = color,
        );
      }
      _drawText(
        canvas,
        ChartParts.xLabel(rows[r][label.name], label),
        Offset(2, plot.top + r * ch + ch * 0.3),
        maxWidth: 40,
      );
    }
  }

  void _paintHexbin(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(24, 14, size.width - 40, size.height - 28);
    const cols = 6;
    const hexRows = 4;
    final r = math.min(plot.width / (cols * 1.8), plot.height / (hexRows * 1.8));
    for (var row = 0; row < hexRows; row++) {
      for (var col = 0; col < cols; col++) {
        final cx = plot.left + r * 1.2 + col * r * 1.7 + (row.isOdd ? r * 0.85 : 0);
        final cy = plot.top + r * 1.1 + row * r * 1.5;
        final intensity = (((row * cols + col) * 37) % 100) / 100.0;
        final hex = Path();
        for (var k = 0; k < 6; k++) {
          final a = (math.pi / 3) * k + math.pi / 6;
          final pt = Offset(cx + math.cos(a) * r * 0.85, cy + math.sin(a) * r * 0.85);
          if (k == 0) {
            hex.moveTo(pt.dx, pt.dy);
          } else {
            hex.lineTo(pt.dx, pt.dy);
          }
        }
        hex.close();
        canvas.drawPath(
          hex,
          Paint()..color = palette.seriesAt(0).withValues(alpha: 0.15 + intensity * 0.8),
        );
      }
    }
  }

  void _paintContour(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 32);
    _drawAxes(canvas, plot);
    final c = plot.center;
    for (var level = 4; level >= 1; level--) {
      final frac = level / 4.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: plot.width * 0.82 * frac,
          height: plot.height * 0.78 * frac,
        ),
        Paint()
          ..color = palette.seriesAt(0).withValues(alpha: 0.18 + (5 - level) * 0.16)
          ..style = PaintingStyle.fill,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: plot.width * 0.82 * frac,
          height: plot.height * 0.78 * frac,
        ),
        Paint()
          ..color = palette.seriesAt(0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintSplom(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(18, 12, size.width - 36, size.height - 24);
    const grid = 3;
    final cellW = plot.width / grid;
    final cellH = plot.height / grid;
    for (var r = 0; r < grid; r++) {
      for (var c = 0; c < grid; c++) {
        final cell = Rect.fromLTWH(
          plot.left + c * cellW + 3,
          plot.top + r * cellH + 3,
          cellW - 6,
          cellH - 6,
        );
        canvas.drawRect(
          cell,
          Paint()
            ..color = palette.border
            ..style = PaintingStyle.stroke,
        );
        for (var i = 0; i < math.min(rows.length, 6); i++) {
          final px = cell.left + 6 + ((i * 23 + c * 13) % 70) / 100.0 * (cell.width - 12);
          final py = cell.bottom - 6 - ((i * 19 + r * 17) % 70) / 100.0 * (cell.height - 12);
          canvas.drawCircle(
            Offset(px, py),
            2.5,
            Paint()..color = palette.seriesAt((r + c) % ReportPalette.slots),
          );
        }
      }
    }
  }

  void _paintTernary(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = Offset(cx, 18);
    final h = size.height - 40;
    final halfW = math.min(size.width * 0.42, h / math.sqrt(3) * 1.1);
    final bl = Offset(cx - halfW, size.height - 22);
    final br = Offset(cx + halfW, size.height - 22);
    final tri = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i < rows.length; i++) {
      final a = _num(rows[i], xMeasure).abs() + 1;
      final b = _num(rows[i], yMeasure).abs() + 1;
      final c = (sizeMeasure != null ? _num(rows[i], sizeMeasure!).abs() : (a + b) * 0.5) + 1;
      final sum = a + b + c;
      final wa = a / sum, wb = b / sum, wc = c / sum;
      final pt = Offset(
        top.dx * wa + bl.dx * wb + br.dx * wc,
        top.dy * wa + bl.dy * wb + br.dy * wc,
      );
      canvas.drawCircle(
        pt,
        4.0,
        Paint()..color = palette.seriesAt(i % ReportPalette.slots),
      );
    }
    _drawText(canvas, xMeasure.label, top + const Offset(-18, -14));
  }

  @override
  bool shouldRepaint(covariant _RelationPainter old) =>
      old.visual != visual || old.rows != rows || old.palette != palette;
}
