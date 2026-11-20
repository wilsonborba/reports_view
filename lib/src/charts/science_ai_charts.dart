import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders Science, AI, and Assessment catalog items 105 to 114
/// (`top_k_prob`, `calibration`, `confusion_matrix`, `roc_pr`, `learning_curve`,
/// `irt_icc`, `irt_iif`, `wright_map`, `item_diff_disc`, `kaplan_meier`)
/// from real [DatasetPage] rows using [ReportPalette] tokens and [Semantics].
class ScienceAiChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo? dimension;
  final List<FieldInfo> measures;
  final double height;

  /// Maximum rows/points rendered in compact card mode to preserve legibility.
  static const int maxItems = 24;

  const ScienceAiChart({
    super.key,
    required this.page,
    required this.visual,
    required this.dimension,
    required this.measures,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty || measures.isEmpty) return const SizedBox.shrink();
    final primary = measures.first;
    final secondary = measures.length > 1 ? measures[1] : null;
    final summary = '${visual.name}: ${primary.label} (${page.rows.length})';
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _ScienceAiPainter(
              visual: visual,
              rows: page.rows.take(maxItems).toList(),
              dimension: dimension,
              primary: primary,
              secondary: secondary,
              palette: p,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScienceAiPainter extends CustomPainter {
  final Visual visual;
  final List<Map<String, dynamic>> rows;
  final FieldInfo? dimension;
  final FieldInfo primary;
  final FieldInfo? secondary;
  final ReportPalette palette;

  const _ScienceAiPainter({
    required this.visual,
    required this.rows,
    required this.dimension,
    required this.primary,
    required this.secondary,
    required this.palette,
  });

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 96,
    double fontSize = 9.5,
    Color? color,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? palette.textPrimary,
          fontSize: fontSize,
          fontFamily: ReportPalette.font,
          fontFamilyFallback: ReportPalette.fontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final offset = center ? pos - Offset(tp.width / 2, tp.height / 2) : pos;
    tp.paint(canvas, offset);
  }

  List<double> _values(FieldInfo f) => [
    for (final r in rows) measureValue(r[f.name], f) ?? 0.0,
  ];

  String _label(int i) =>
      dimension != null ? ChartParts.xLabel(rows[i][dimension!.name], dimension!) : '${i + 1}';

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 24 || size.height <= 24 || rows.isEmpty) return;
    switch (visual) {
      case Visual.topKProb:
        _paintTopK(canvas, size);
      case Visual.calibration:
        _paintCurveWithDiagonal(canvas, size, diagonal: true);
      case Visual.confusionMatrix:
        _paintConfusionMatrix(canvas, size);
      case Visual.rocPr:
        _paintCurveWithDiagonal(canvas, size, diagonal: true, areaFill: true);
      case Visual.learningCurve:
        _paintLearningCurve(canvas, size);
      case Visual.irtIcc:
        _paintIrt(canvas, size, infoCurve: false);
      case Visual.irtIif:
        _paintIrt(canvas, size, infoCurve: true);
      case Visual.wrightMap:
        _paintWrightMap(canvas, size);
      case Visual.itemDiffDisc:
        _paintDiffDiscScatter(canvas, size);
      case Visual.kaplanMeier:
      default:
        _paintKaplanMeier(canvas, size);
    }
  }

  void _paintAxes(Canvas canvas, Rect plot) {
    final p = Paint()
      ..color = palette.border
      ..strokeWidth = 1.0;
    canvas.drawLine(plot.topLeft, plot.bottomLeft, p);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, p);
  }

  void _paintTopK(Canvas canvas, Size size) {
    final vals = _values(primary).map((v) => v.abs()).toList();
    final sum = vals.fold<double>(0.0, (a, b) => a + b).clamp(1e-6, double.infinity);
    final items = [
      for (var i = 0; i < rows.length; i++) (lbl: _label(i), prob: vals[i] / sum),
    ]..sort((a, b) => b.prob.compareTo(a.prob));
    final top = items.take(6).toList();
    final leftW = math.min(110.0, size.width * 0.32);
    final rightPad = 48.0;
    final barMaxW = math.max(20.0, size.width - leftW - rightPad);
    final rowH = (size.height - 16) / top.length;
    final maxP = top.map((e) => e.prob).fold<double>(1e-6, math.max);

    for (var i = 0; i < top.length; i++) {
      final y = 8 + i * rowH;
      final cy = y + rowH / 2;
      _drawText(canvas, top[i].lbl, Offset(6, cy - 6), maxWidth: leftW - 10);
      final bw = (top[i].prob / maxP).clamp(0.04, 1.0) * barMaxW;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftW, cy - 7, bw, 14),
          const Radius.circular(3),
        ),
        Paint()..color = palette.seriesAt(i == 0 ? 0 : 1).withValues(alpha: i == 0 ? 0.95 : 0.65),
      );
      _drawText(
        canvas,
        '${(top[i].prob * 100).toStringAsFixed(1)}%',
        Offset(leftW + bw + 6, cy - 6),
        maxWidth: 42,
        color: palette.textMuted,
      );
    }
  }

  void _paintCurveWithDiagonal(
    Canvas canvas,
    Size size, {
    bool diagonal = true,
    bool areaFill = false,
  }) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _paintAxes(canvas, plot);
    if (diagonal) {
      canvas.drawLine(
        plot.bottomLeft,
        plot.topRight,
        Paint()
          ..color = palette.textMuted.withValues(alpha: 0.45)
          ..strokeWidth = 1.0,
      );
    }
    final v1 = _values(primary);
    final v2 = secondary != null ? _values(secondary!) : <double>[];
    final max1 = v1.map((v) => v.abs()).fold<double>(1e-6, math.max);
    final max2 = v2.isEmpty
        ? 1.0
        : v2.map((v) => v.abs()).fold<double>(1e-6, math.max);
    final pts = <Offset>[];
    for (var i = 0; i < v1.length; i++) {
      final xNorm = v1.length == 1 ? 0.5 : i / (v1.length - 1);
      final yNorm = (v1[i].abs() / max1).clamp(0.0, 1.0);
      pts.add(
        Offset(
          plot.left + xNorm * plot.width,
          plot.bottom - yNorm * plot.height,
        ),
      );
    }
    if (pts.length >= 2) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      if (areaFill) {
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, plot.bottom)
          ..lineTo(pts.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(fill, Paint()..color = palette.accent.withValues(alpha: 0.14));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    for (final pt in pts) {
      canvas.drawCircle(pt, 3.2, Paint()..color = palette.accent);
    }
    if (v2.length >= 2) {
      final path2 = Path();
      for (var i = 0; i < v2.length; i++) {
        final xNorm = i / (v2.length - 1);
        final yNorm = (v2[i].abs() / max2).clamp(0.0, 1.0);
        final pt = Offset(
          plot.left + xNorm * plot.width,
          plot.bottom - yNorm * plot.height,
        );
        if (i == 0) {
          path2.moveTo(pt.dx, pt.dy);
        } else {
          path2.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path2,
        Paint()
          ..color = palette.seriesAt(1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    _drawText(canvas, '0.0', Offset(6, plot.bottom - 6), maxWidth: 26, color: palette.textMuted);
    _drawText(canvas, '1.0', Offset(6, plot.top - 4), maxWidth: 26, color: palette.textMuted);
  }

  void _paintConfusionMatrix(Canvas canvas, Size size) {
    final vals = _values(primary).map((v) => v.abs()).toList();
    final n = math.max(2, math.min(4, math.sqrt(vals.length).ceil()));
    final plot = Rect.fromLTWH(34, 16, size.width - 52, size.height - 32);
    final cellW = plot.width / n;
    final cellH = plot.height / n;
    final maxV = vals.fold<double>(1e-6, math.max);

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final idx = (r * n + c) % vals.length;
        final val = vals[idx];
        final ratio = (val / maxV).clamp(0.0, 1.0);
        final rect = Rect.fromLTWH(
          plot.left + c * cellW + 2,
          plot.top + r * cellH + 2,
          cellW - 4,
          cellH - 4,
        );
        final baseColor = r == c ? palette.positive : palette.accent;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = baseColor.withValues(alpha: 0.10 + ratio * 0.65),
        );
        _drawText(
          canvas,
          val.toStringAsFixed(0),
          rect.center,
          maxWidth: cellW - 8,
          center: true,
        );
      }
    }
  }

  void _paintLearningCurve(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _paintAxes(canvas, plot);
    final seriesList = [primary, ?secondary];
    final allVals = [for (final f in seriesList) ..._values(f)];
    final minV = allVals.fold<double>(double.infinity, math.min);
    final maxV = allVals.fold<double>(-double.infinity, math.max);
    final span = math.max(1e-6, maxV - minV);

    for (var s = 0; s < seriesList.length; s++) {
      final vals = _values(seriesList[s]);
      if (vals.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < vals.length; i++) {
        final x = vals.length == 1
            ? plot.center.dx
            : plot.left + (i / (vals.length - 1)) * plot.width;
        final y = plot.bottom - ((vals[i] - minV) / span) * plot.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.seriesAt(s)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  void _paintIrt(Canvas canvas, Size size, {required bool infoCurve}) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _paintAxes(canvas, plot);
    final vals = _values(primary);
    final maxV = vals.map((v) => v.abs()).fold<double>(1.0, math.max);
    final items = vals.take(3).toList();
    const steps = 40;

    for (var idx = 0; idx < items.length; idx++) {
      final ratio = (items[idx].abs() / maxV).clamp(0.1, 1.0);
      final b = (ratio - 0.5) * 2.4; // difficulty shift
      final a = 1.0 + idx * 0.45; // discrimination
      final path = Path();
      for (var s = 0; s <= steps; s++) {
        final theta = -3.0 + (s / steps) * 6.0;
        final p = 1.0 / (1.0 + math.exp(-a * (theta - b)));
        final yVal = infoCurve ? (a * a * p * (1.0 - p)) / (a * a * 0.25) : p;
        final x = plot.left + (s / steps) * plot.width;
        final y = plot.bottom - yVal.clamp(0.0, 1.0) * plot.height;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.seriesAt(idx)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
    _drawText(canvas, '-3', Offset(plot.left - 4, plot.bottom + 4), maxWidth: 24, color: palette.textMuted);
    _drawText(canvas, '+3', Offset(plot.right - 14, plot.bottom + 4), maxWidth: 24, color: palette.textMuted);
  }

  void _paintWrightMap(Canvas canvas, Size size) {
    final cx = size.width * 0.48;
    final top = 16.0;
    final bottom = size.height - 20.0;
    canvas.drawLine(
      Offset(cx, top),
      Offset(cx, bottom),
      Paint()
        ..color = palette.border
        ..strokeWidth = 1.4,
    );
    final vals = _values(primary);
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final span = math.max(1e-6, maxV - minV);

    for (var i = 0; i < rows.length; i++) {
      final norm = ((vals[i] - minV) / span).clamp(0.0, 1.0);
      final y = bottom - norm * (bottom - top);
      final barW = 18.0 + norm * math.min(90.0, cx - 24);
      canvas.drawRect(
        Rect.fromLTWH(cx - barW - 4, y - 4, barW, 8),
        Paint()..color = palette.accent.withValues(alpha: 0.55),
      );
      canvas.drawCircle(Offset(cx + 8, y), 3.5, Paint()..color = palette.seriesAt(i));
      _drawText(
        canvas,
        _label(i),
        Offset(cx + 16, y - 6),
        maxWidth: math.max(40.0, size.width - cx - 22),
      );
    }
  }

  void _paintDiffDiscScatter(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _paintAxes(canvas, plot);
    canvas.drawLine(
      Offset(plot.center.dx, plot.top),
      Offset(plot.center.dx, plot.bottom),
      Paint()..color = palette.border.withValues(alpha: 0.6),
    );
    canvas.drawLine(
      Offset(plot.left, plot.center.dy),
      Offset(plot.right, plot.center.dy),
      Paint()..color = palette.border.withValues(alpha: 0.6),
    );
    final v1 = _values(primary);
    final v2 = secondary != null ? _values(secondary!) : v1;
    final min1 = v1.reduce(math.min);
    final span1 = math.max(1e-6, v1.reduce(math.max) - min1);
    final min2 = v2.reduce(math.min);
    final span2 = math.max(1e-6, v2.reduce(math.max) - min2);

    for (var i = 0; i < rows.length; i++) {
      final x = plot.left + ((v1[i] - min1) / span1) * (plot.width - 16) + 8;
      final y = plot.bottom - ((v2[i] - min2) / span2) * (plot.height - 16) - 8;
      canvas.drawCircle(Offset(x, y), 5.0, Paint()..color = palette.seriesAt(i));
      _drawText(canvas, _label(i), Offset(x + 7, y - 6), maxWidth: 64, fontSize: 8.5);
    }
  }

  void _paintKaplanMeier(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _paintAxes(canvas, plot);
    final vals = _values(primary).map((v) => v.abs()).toList();
    final maxV = vals.fold<double>(1e-6, math.max);
    // Step-down survival curve
    final sorted = [...vals]..sort((a, b) => b.compareTo(a));
    final path = Path();
    Offset? prev;
    for (var i = 0; i < sorted.length; i++) {
      final x = sorted.length == 1
          ? plot.left
          : plot.left + (i / (sorted.length - 1)) * plot.width;
      final y = plot.bottom - (sorted[i] / maxV).clamp(0.0, 1.0) * plot.height;
      if (prev == null) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, prev.dy);
        path.lineTo(x, y);
      }
      canvas.drawLine(
        Offset(x, y - 3),
        Offset(x, y + 3),
        Paint()
          ..color = palette.accent
          ..strokeWidth = 1.4,
      );
      prev = Offset(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    _drawText(canvas, '1.0', Offset(6, plot.top - 4), maxWidth: 26, color: palette.textMuted);
    _drawText(canvas, '0.0', Offset(6, plot.bottom - 6), maxWidth: 26, color: palette.textMuted);
  }

  @override
  bool shouldRepaint(covariant _ScienceAiPainter old) =>
      old.visual != visual || old.rows != rows || old.palette != palette;
}
