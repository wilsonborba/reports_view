import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// One set intersection entry extracted from [DatasetPage] rows.
class SetIntersection {
  final String label;
  final List<String> sets;
  final double count;

  const SetIntersection({
    required this.label,
    required this.sets,
    required this.count,
  });
}

/// Renders set visualization catalog items 90 to 92 (`venn`, `euler`, `upset`)
/// from real [DatasetPage] rows using [ReportPalette] tokens and [Semantics].
class SetsCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo measure;
  final double height;

  /// Maximum distinct sets displayed before folding to keep diagrams legible (D7).
  static const int maxSets = 5;

  const SetsCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.measure,
    this.height = 260,
  });

  /// Extracts set intersections from [rows] where [label] contains set names
  /// (e.g. `"A & B"`, `"A+B"`, or single set names).
  static List<SetIntersection> extractIntersections(
    List<Map<String, dynamic>> rows,
    FieldInfo label,
    FieldInfo measure,
  ) {
    final out = <SetIntersection>[];
    for (final r in rows) {
      final raw = ChartParts.xLabel(r[label.name], label);
      final parts = raw
          .split(RegExp(r'\s*[&+,|]\s*'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final sets = parts.isEmpty ? [raw] : parts;
      final val = (measureValue(r[measure.name], measure) ?? 0.0).abs();
      out.add(SetIntersection(label: raw, sets: sets, count: val));
    }
    return out;
  }

  /// Computes total size per individual set across [intersections], capped at [limit].
  static Map<String, double> computeSetTotals(
    List<SetIntersection> intersections, {
    int limit = maxSets,
  }) {
    final totals = <String, double>{};
    for (final item in intersections) {
      for (final s in item.sets) {
        totals[s] = (totals[s] ?? 0.0) + item.count;
      }
    }
    final keys = totals.keys.take(limit).toList();
    return {for (final k in keys) k: totals[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final intersections = extractIntersections(page.rows, label, measure);
    final setTotals = computeSetTotals(intersections);
    final summary =
        '${visual.name}: ${setTotals.keys.take(4).join(', ')} (${intersections.length})';
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _SetsPainter(
              visual: visual,
              intersections: intersections,
              setTotals: setTotals,
              palette: p,
            ),
          ),
        ),
      ),
    );
  }
}

class _SetsPainter extends CustomPainter {
  final Visual visual;
  final List<SetIntersection> intersections;
  final Map<String, double> setTotals;
  final ReportPalette palette;

  const _SetsPainter({
    required this.visual,
    required this.intersections,
    required this.setTotals,
    required this.palette,
  });

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 84,
    double fontSize = 10,
    Color? color,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? palette.textPrimary, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final offset = center ? pos - Offset(tp.width / 2, tp.height / 2) : pos;
    tp.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || setTotals.isEmpty) return;
    switch (visual) {
      case Visual.venn:
        _paintCircles(canvas, size, proportional: false);
      case Visual.euler:
        _paintCircles(canvas, size, proportional: true);
      case Visual.upset:
      default:
        _paintUpSet(canvas, size);
    }
  }

  void _paintCircles(Canvas canvas, Size size, {required bool proportional}) {
    final entries = setTotals.entries.take(3).toList();
    final n = entries.length;
    final maxTotal = entries.map((e) => e.value).fold<double>(1.0, math.max);
    final baseR = math.min(size.width, size.height) * 0.27;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final centers = n == 1
        ? [Offset(cx, cy)]
        : n == 2
        ? [Offset(cx - baseR * 0.55, cy), Offset(cx + baseR * 0.55, cy)]
        : [
            Offset(cx - baseR * 0.52, cy + baseR * 0.25),
            Offset(cx + baseR * 0.52, cy + baseR * 0.25),
            Offset(cx, cy - baseR * 0.45),
          ];

    for (var i = 0; i < n; i++) {
      final ratio = entries[i].value / maxTotal;
      final r = proportional
          ? baseR * (0.48 + 0.52 * math.sqrt(ratio.clamp(0.05, 1.0)))
          : baseR;
      final c = palette.seriesAt(i);
      final alpha = proportional ? 0.28 : (0.14 + 0.32 * ratio.clamp(0.0, 1.0));
      final sw = proportional ? 1.6 : (1.2 + 2.2 * ratio.clamp(0.0, 1.0));
      canvas.drawCircle(centers[i], r, Paint()..color = c.withValues(alpha: alpha));
      canvas.drawCircle(
        centers[i],
        r,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw,
      );
      _drawText(
        canvas,
        '${entries[i].key} (${entries[i].value.toStringAsFixed(0)})',
        centers[i],
        maxWidth: r * 1.6,
        center: true,
      );
    }
  }

  void _paintUpSet(Canvas canvas, Size size) {
    final sets = setTotals.keys.take(SetsCatalogChart.maxSets).toList();
    final cols = intersections.take(8).toList();
    if (sets.isEmpty || cols.isEmpty) return;

    final leftW = math.min(130.0, size.width * 0.34);
    final topH = size.height * 0.46;
    final matrixTop = topH + 14;
    final rowH = (size.height - matrixTop - 16) / sets.length;
    final colW = (size.width - leftW - 16) / cols.length;

    final maxSet = setTotals.values.fold<double>(1.0, math.max);
    final maxCol = cols.map((c) => c.count).fold<double>(1.0, math.max);

    // Top vertical intersection-size bars
    for (var j = 0; j < cols.length; j++) {
      final bh = (cols[j].count / maxCol).clamp(0.04, 1.0) * (topH - 22);
      final x = leftW + j * colW + colW * 0.22;
      final bw = math.max(6.0, colW * 0.56);
      canvas.drawRect(
        Rect.fromLTWH(x, topH - bh, bw, bh),
        Paint()..color = palette.accent,
      );
    }

    // Left horizontal set-size bars + labels + matrix rows
    for (var i = 0; i < sets.length; i++) {
      final y = matrixTop + (i + 0.5) * rowH;
      _drawText(canvas, sets[i], Offset(6, y - 6), maxWidth: 52, fontSize: 9);
      final barMaxW = leftW - 64;
      final bw = ((setTotals[sets[i]] ?? 0) / maxSet).clamp(0.04, 1.0) * barMaxW;
      canvas.drawRect(
        Rect.fromLTWH(leftW - 6 - bw, y - 4, bw, 8),
        Paint()..color = palette.seriesAt(i),
      );
    }

    // Intersection dot matrix + vertical connectors
    for (var j = 0; j < cols.length; j++) {
      final cx = leftW + (j + 0.5) * colW;
      final activeRows = <int>[];
      for (var i = 0; i < sets.length; i++) {
        final cy = matrixTop + (i + 0.5) * rowH;
        final active = cols[j].sets.contains(sets[i]);
        if (active) activeRows.add(i);
        canvas.drawCircle(
          Offset(cx, cy),
          4.0,
          Paint()..color = active ? palette.textPrimary : palette.surfaceAlt,
        );
      }
      if (activeRows.length >= 2) {
        final y1 = matrixTop + (activeRows.first + 0.5) * rowH;
        final y2 = matrixTop + (activeRows.last + 0.5) * rowH;
        canvas.drawLine(
          Offset(cx, y1),
          Offset(cx, y2),
          Paint()
            ..color = palette.textPrimary
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SetsPainter old) =>
      old.visual != visual || old.intersections != intersections || old.palette != palette;
}
