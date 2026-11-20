import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders relation & correlation catalog chart types (items 65 to 73) using
/// real data from [page.rows], [ReportPalette] tokens, and [Semantics]
/// summaries (reports#59, C1 to C23).
class RelationCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo xMeasure;
  final FieldInfo yMeasure;
  final FieldInfo? sizeMeasure;
  final List<FieldInfo> measures;
  final double height;

  const RelationCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.xMeasure,
    required this.yMeasure,
    this.sizeMeasure,
    this.measures = const [],
    this.height = 260,
  });

  /// Computes Pearson correlation matrix across [cols] from [rows].
  static List<List<double>> computeCorrelationMatrix(
    List<Map<String, dynamic>> rows,
    List<String> cols,
  ) {
    final k = cols.length;
    final out = List.generate(k, (_) => List<double>.filled(k, 0.0));
    if (rows.isEmpty || k == 0) return out;
    final series = <List<double>>[
      for (final c in cols)
        [
          for (final r in rows)
            (r[c] is num && (r[c] as num).isFinite)
                ? (r[c] as num).toDouble()
                : 0.0,
        ],
    ];
    final means = <double>[
      for (final s in series) s.reduce((a, b) => a + b) / s.length,
    ];
    for (var i = 0; i < k; i++) {
      for (var j = 0; j < k; j++) {
        if (i == j) {
          out[i][j] = 1.0;
          continue;
        }
        var numSum = 0.0, denA = 0.0, denB = 0.0;
        for (var idx = 0; idx < rows.length; idx++) {
          final da = series[i][idx] - means[i];
          final db = series[j][idx] - means[j];
          numSum += da * db;
          denA += da * da;
          denB += db * db;
        }
        final den = math.sqrt(denA * denB);
        out[i][j] = den > 1e-12 ? (numSum / den).clamp(-1.0, 1.0) : 0.0;
      }
    }
    return out;
  }

  /// Bins normalized `(x, y)` points in `[0, 1]^2` into `(col, row)` hex cells.
  static Map<(int, int), int> computeHexbinCounts(
    List<(double, double)> unitPoints, {
    int cols = 6,
    int rows = 4,
  }) {
    final counts = <(int, int), int>{};
    for (final (ux, uy) in unitPoints) {
      final r = ((1.0 - uy.clamp(0.0, 1.0)) * (rows - 1e-6))
          .floor()
          .clamp(0, rows - 1);
      final c = (ux.clamp(0.0, 1.0) * (cols - 1e-6))
          .floor()
          .clamp(0, cols - 1);
      counts[(c, r)] = (counts[(c, r)] ?? 0) + 1;
    }
    return counts;
  }

  /// Finds the `(ux, uy)` peak of a 2D Gaussian KDE over normalized points in `[0, 1]^2`.
  static (double, double) computeDensityPeak(
    List<(double, double)> unitPoints, {
    int grid = 16,
  }) {
    if (unitPoints.isEmpty) return (0.5, 0.5);
    const sigma = 0.18;
    const twoSig2 = 2 * sigma * sigma;
    var bestVal = -1.0;
    var best = (0.5, 0.5);
    for (var gy = 0; gy < grid; gy++) {
      final uy = (gy + 0.5) / grid;
      for (var gx = 0; gx < grid; gx++) {
        final ux = (gx + 0.5) / grid;
        var sum = 0.0;
        for (final (px, py) in unitPoints) {
          final dx = ux - px;
          final dy = uy - py;
          sum += math.exp(-(dx * dx + dy * dy) / twoSig2);
        }
        if (sum > bestVal) {
          bestVal = sum;
          best = (ux, uy);
        }
      }
    }
    return best;
  }

  /// Maps `(xCol, yCol)` values from [rows] to normalized `[0, 1]^2` points.
  static List<(double, double)> computeSplomCellPoints(
    List<Map<String, dynamic>> rows,
    String xCol,
    String yCol,
  ) {
    if (rows.isEmpty) return const [];
    final xs = [
      for (final r in rows)
        (r[xCol] is num && (r[xCol] as num).isFinite)
            ? (r[xCol] as num).toDouble()
            : 0.0,
    ];
    final ys = [
      for (final r in rows)
        (r[yCol] is num && (r[yCol] as num).isFinite)
            ? (r[yCol] as num).toDouble()
            : 0.0,
    ];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final spanX = (maxX - minX).abs() < 1e-9 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;
    return [
      for (var i = 0; i < rows.length; i++)
        ((xs[i] - minX) / spanX, (ys[i] - minY) / spanY),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final labels = [
      for (final r in page.rows) ChartParts.xLabel(r[label.name], label),
    ];
    final allMeasures = measures.isNotEmpty
        ? measures
        : [
            xMeasure,
            if (yMeasure.name != xMeasure.name) yMeasure,
            ?sizeMeasure,
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
                measures: allMeasures,
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
  final List<FieldInfo> measures;

  _RelationPainter({
    required this.palette,
    required this.visual,
    required this.rows,
    required this.label,
    required this.xMeasure,
    required this.yMeasure,
    required this.sizeMeasure,
    required this.measures,
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

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 80,
    Color? color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? palette.textMuted,
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

  List<(double, double)> _unitPoints() =>
      RelationCatalogChart.computeSplomCellPoints(
        rows,
        xMeasure.name,
        yMeasure.name,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || rows.isEmpty) return;
    switch (visual) {
      case Visual.heatmap:
        _paintHeatmap(canvas, size);
      case Visual.correlationMatrix:
        _paintCorrelationMatrix(canvas, size);
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
        Paint()
          ..color = palette
              .seriesAt(i % ReportPalette.slots)
              .withValues(alpha: 0.78),
      );
    }
    _drawText(canvas, numberText(minX, 1), Offset(plot.left, plot.bottom + 4));
    _drawText(
      canvas,
      numberText(maxX, 1),
      Offset(plot.right - 34, plot.bottom + 4),
    );
  }

  void _paintHeatmap(Canvas canvas, Size size) {
    final cols = measures.take(4).toList();
    final rowCount = math.min(6, rows.length);
    final plot = Rect.fromLTWH(56, 20, size.width - 72, size.height - 44);
    final cw = plot.width / math.max(1, cols.length);
    final ch = plot.height / math.max(1, rowCount);

    var minV = double.infinity, maxV = double.negativeInfinity;
    for (var r = 0; r < rowCount; r++) {
      for (final m in cols) {
        final v = _num(rows[r], m);
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;

    for (var c = 0; c < cols.length; c++) {
      _drawText(
        canvas,
        cols[c].label,
        Offset(plot.left + c * cw + 2, 4),
        maxWidth: cw - 4,
      );
    }
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < cols.length; c++) {
        final v = _num(rows[r], cols[c]);
        final t = ((v - minV) / span).clamp(0.0, 1.0);
        final rect = Rect.fromLTWH(
          plot.left + c * cw + 1,
          plot.top + r * ch + 1,
          cw - 2,
          ch - 2,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = palette.seriesAt(0).withValues(alpha: 0.12 + t * 0.83),
        );
        _drawText(
          canvas,
          numberText(v, 0),
          rect.topLeft + const Offset(4, 4),
          maxWidth: cw - 8,
          color: t > 0.55 ? palette.onAccent : palette.textPrimary,
        );
      }
      _drawText(
        canvas,
        ChartParts.xLabel(rows[r][label.name], label),
        Offset(2, plot.top + r * ch + ch * 0.25),
        maxWidth: 50,
      );
    }
    _drawText(
      canvas,
      '${numberText(minV, 0)} .. ${numberText(maxV, 0)}',
      Offset(plot.left, plot.bottom + 4),
      maxWidth: 140,
    );
  }

  void _paintCorrelationMatrix(Canvas canvas, Size size) {
    final cols = measures.take(4).toList();
    final colNames = [for (final m in cols) m.name];
    final matrix = RelationCatalogChart.computeCorrelationMatrix(rows, colNames);
    final k = cols.length;
    final plot = Rect.fromLTWH(52, 20, size.width - 68, size.height - 44);
    final cw = plot.width / k;
    final ch = plot.height / k;

    for (var c = 0; c < k; c++) {
      _drawText(
        canvas,
        cols[c].label,
        Offset(plot.left + c * cw + 2, 4),
        maxWidth: cw - 4,
      );
    }
    for (var r = 0; r < k; r++) {
      _drawText(
        canvas,
        cols[r].label,
        Offset(2, plot.top + r * ch + ch * 0.3),
        maxWidth: 46,
      );
      for (var c = 0; c < k; c++) {
        final v = matrix[r][c];
        final color = v >= 0
            ? palette.seriesAt(0).withValues(alpha: 0.12 + v.abs() * 0.83)
            : palette.negative.withValues(alpha: 0.12 + v.abs() * 0.83);
        final rect = Rect.fromLTWH(
          plot.left + c * cw + 1,
          plot.top + r * ch + 1,
          cw - 2,
          ch - 2,
        );
        canvas.drawRect(rect, Paint()..color = color);
        _drawText(
          canvas,
          v.toStringAsFixed(2),
          rect.topLeft + const Offset(4, 4),
          maxWidth: cw - 8,
          color: v.abs() > 0.55 ? palette.onAccent : palette.textPrimary,
        );
      }
    }
    _drawText(
      canvas,
      'r: -1.0 .. +1.0',
      Offset(plot.left, plot.bottom + 4),
      maxWidth: 140,
    );
  }

  void _paintHexbin(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(28, 14, size.width - 44, size.height - 38);
    _drawAxes(canvas, plot);
    const cols = 6;
    const hexRows = 4;
    final bins = RelationCatalogChart.computeHexbinCounts(
      _unitPoints(),
      cols: cols,
      rows: hexRows,
    );
    final maxCount = bins.isEmpty ? 1 : bins.values.reduce(math.max);
    final r = math.min(
      plot.width / (cols * 1.85),
      plot.height / (hexRows * 1.85),
    );
    for (final entry in bins.entries) {
      final (col, row) = entry.key;
      final count = entry.value;
      final cx =
          plot.left + r * 1.2 + col * r * 1.7 + (row.isOdd ? r * 0.85 : 0);
      final cy = plot.top + r * 1.1 + row * r * 1.5;
      final intensity = count / math.max(1, maxCount);
      final hex = Path();
      for (var k = 0; k < 6; k++) {
        final a = (math.pi / 3) * k + math.pi / 6;
        final pt = Offset(
          cx + math.cos(a) * r * 0.85,
          cy + math.sin(a) * r * 0.85,
        );
        if (k == 0) {
          hex.moveTo(pt.dx, pt.dy);
        } else {
          hex.lineTo(pt.dx, pt.dy);
        }
      }
      hex.close();
      canvas.drawPath(
        hex,
        Paint()..color = palette.seriesAt(0).withValues(alpha: 0.2 + intensity * 0.75),
      );
    }
    _drawText(
      canvas,
      'Count: 1 .. $maxCount (${rows.length} pts)',
      Offset(plot.left, plot.bottom + 4),
      maxWidth: 160,
    );
  }

  void _paintContour(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 34);
    _drawAxes(canvas, plot);
    final pts = _unitPoints();
    const grid = 14;
    const sigma = 0.2;
    const twoSig2 = 2 * sigma * sigma;
    final density = List.generate(grid, (_) => List<double>.filled(grid, 0.0));
    var peak = 1e-9;
    for (var gy = 0; gy < grid; gy++) {
      final uy = 1.0 - (gy + 0.5) / grid;
      for (var gx = 0; gx < grid; gx++) {
        final ux = (gx + 0.5) / grid;
        var sum = 0.0;
        for (final (px, py) in pts) {
          final dx = ux - px;
          final dy = uy - py;
          sum += math.exp(-(dx * dx + dy * dy) / twoSig2);
        }
        density[gy][gx] = sum;
        if (sum > peak) peak = sum;
      }
    }
    final cw = plot.width / grid;
    final ch = plot.height / grid;
    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        final level = ((density[gy][gx] / peak) * 4).floor();
        if (level <= 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(plot.left + gx * cw, plot.top + gy * ch, cw, ch),
          Paint()
            ..color = palette.seriesAt(0).withValues(alpha: 0.12 + level * 0.18),
        );
      }
    }
    for (final (px, py) in pts) {
      canvas.drawCircle(
        Offset(plot.left + px * plot.width, plot.bottom - py * plot.height),
        2.5,
        Paint()..color = palette.textPrimary.withValues(alpha: 0.7),
      );
    }
  }

  void _paintSplom(Canvas canvas, Size size) {
    final cols = measures.take(3).toList();
    final k = cols.length;
    final plot = Rect.fromLTWH(48, 20, size.width - 60, size.height - 32);
    final cellW = plot.width / k;
    final cellH = plot.height / k;

    for (var c = 0; c < k; c++) {
      _drawText(
        canvas,
        cols[c].label,
        Offset(plot.left + c * cellW + 4, 4),
        maxWidth: cellW - 8,
      );
    }
    for (var r = 0; r < k; r++) {
      _drawText(
        canvas,
        cols[r].label,
        Offset(2, plot.top + r * cellH + cellH * 0.35),
        maxWidth: 42,
      );
      for (var c = 0; c < k; c++) {
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
        if (r == c) {
          _drawText(
            canvas,
            cols[r].label,
            cell.topLeft + const Offset(4, 4),
            maxWidth: cell.width - 8,
            color: palette.textPrimary,
          );
          continue;
        }
        final pts = RelationCatalogChart.computeSplomCellPoints(
          rows,
          cols[c].name,
          cols[r].name,
        );
        for (final (ux, uy) in pts) {
          final px = cell.left + 4 + ux * math.max(2, cell.width - 8);
          final py = cell.bottom - 4 - uy * math.max(2, cell.height - 8);
          canvas.drawCircle(
            Offset(px, py),
            2.5,
            Paint()..color = palette.seriesAt(0),
          );
        }
      }
    }
  }

  void _paintTernary(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = Offset(cx, 20);
    final h = size.height - 46;
    final halfW = math.min(size.width * 0.4, h / math.sqrt(3) * 1.1);
    final bl = Offset(cx - halfW, size.height - 24);
    final br = Offset(cx + halfW, size.height - 24);
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
    final fB = measures.length > 1 ? measures[1] : yMeasure;
    final fC = measures.length > 2 ? measures[2] : (sizeMeasure ?? yMeasure);
    for (var i = 0; i < rows.length; i++) {
      final a = _num(rows[i], xMeasure).abs() + 1;
      final b = _num(rows[i], fB).abs() + 1;
      final c = _num(rows[i], fC).abs() + 1;
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
    _drawText(canvas, xMeasure.label, top + const Offset(-18, -16));
    _drawText(canvas, fB.label, bl + const Offset(-12, 4), maxWidth: 80);
    _drawText(canvas, fC.label, br + const Offset(-32, 4), maxWidth: 80);
  }

  @override
  bool shouldRepaint(covariant _RelationPainter old) =>
      old.visual != visual || old.rows != rows || old.palette != palette;
}
