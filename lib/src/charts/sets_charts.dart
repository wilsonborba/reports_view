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

/// Positioned circle and label for a Venn or Euler diagram.
class PositionedSetCircle {
  final String name;
  final double total;
  final Offset center;
  final double radius;
  final Rect labelRect;
  final String labelText;

  const PositionedSetCircle({
    required this.name,
    required this.total,
    required this.center,
    required this.radius,
    required this.labelRect,
    required this.labelText,
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
          .toSet()
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

  /// Returns the total count of intersections containing both [a] and [b].
  static double pairwiseOverlap(
    List<SetIntersection> intersections,
    String a,
    String b,
  ) {
    if (a == b) return 0.0;
    var sum = 0.0;
    for (final item in intersections) {
      if (item.sets.contains(a) && item.sets.contains(b)) {
        sum += item.count;
      }
    }
    return sum;
  }

  /// Computes UpSet columns sorted with multi-set intersections and largest
  /// counts prioritized so connected intersections are clearly visible.
  static List<SetIntersection> computeUpSetColumns(
    List<SetIntersection> intersections, {
    int maxCols = 8,
  }) {
    final sorted = [...intersections]
      ..sort((a, b) {
        final multiCmp = (b.sets.length > 1 ? 1 : 0).compareTo(
          a.sets.length > 1 ? 1 : 0,
        );
        if (multiCmp != 0) return multiCmp;
        return b.count.compareTo(a.count);
      });
    return sorted.take(maxCols).toList();
  }

  static TextPainter _layoutLabel(
    String text,
    ReportPalette palette, {
    double maxWidth = 120,
    double fontSize = 10,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          fontFamily: ReportPalette.font,
          fontFamilyFallback: ReportPalette.fontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
  }

  /// Computes non-overlapping circle and outer-label geometry for Venn or Euler.
  static List<PositionedSetCircle> layoutCircles(
    Size size,
    List<SetIntersection> intersections,
    Map<String, double> setTotals,
    ReportPalette palette, {
    required bool euler,
  }) {
    final entries = setTotals.entries.take(3).toList();
    final n = entries.length;
    if (n == 0) return const [];

    final maxTotal = entries.map((e) => e.value).fold<double>(1.0, math.max);
    final padX = 20.0;
    final padY = 24.0;
    final availW = math.max(40.0, size.width - padX * 2);
    final availH = math.max(40.0, size.height - padY * 2);
    final baseR = math.min(availW * 0.24, availH * 0.30);

    final radii = [
      for (final e in entries)
        euler
            ? baseR * (0.45 + 0.55 * math.sqrt((e.value / maxTotal).clamp(0.05, 1.0)))
            : baseR,
    ];

    final cx = size.width / 2;
    final cy = size.height / 2;
    final centers = List<Offset>.filled(n, Offset(cx, cy));

    if (!euler) {
      if (n == 2) {
        centers[0] = Offset(cx - baseR * 0.55, cy);
        centers[1] = Offset(cx + baseR * 0.55, cy);
      } else if (n == 3) {
        centers[0] = Offset(cx - baseR * 0.55, cy + baseR * 0.30);
        centers[1] = Offset(cx + baseR * 0.55, cy + baseR * 0.30);
        centers[2] = Offset(cx, cy - baseR * 0.48);
      }
    } else if (n == 2) {
      final ov = pairwiseOverlap(intersections, entries[0].key, entries[1].key);
      final minT = math.min(entries[0].value, entries[1].value).clamp(1.0, double.infinity);
      final d = ov > 0
          ? (radii[0] + radii[1]) * (1.0 - 0.45 * (ov / minT).clamp(0.18, 0.65))
          : radii[0] + radii[1] + 16.0;
      centers[0] = Offset(cx - d / 2, cy);
      centers[1] = Offset(cx + d / 2, cy);
    } else if (n == 3) {
      // Initial deterministic horizontal/triangle layout, then relax distances
      // so only pairs with pairwiseOverlap > 0 intersect.
      centers[0] = Offset(cx - baseR * 1.1, cy + baseR * 0.15);
      centers[1] = Offset(cx, cy - baseR * 0.15);
      centers[2] = Offset(cx + baseR * 1.1, cy + baseR * 0.15);

      for (var iter = 0; iter < 80; iter++) {
        final disp = List<Offset>.filled(n, Offset.zero);
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            final delta = centers[j] - centers[i];
            final dist = math.max(1.0, delta.distance);
            final dir = delta / dist;
            final ov = pairwiseOverlap(
              intersections,
              entries[i].key,
              entries[j].key,
            );
            final sumR = radii[i] + radii[j];
            if (ov > 0) {
              final minT = math
                  .min(entries[i].value, entries[j].value)
                  .clamp(1.0, double.infinity);
              final target = sumR * (1.0 - 0.42 * (ov / minT).clamp(0.18, 0.62));
              final push = (dist - target) * 0.18;
              disp[i] += dir * push;
              disp[j] -= dir * push;
            } else {
              final minSep = sumR + 14.0;
              if (dist < minSep) {
                final push = (minSep - dist) * 0.25;
                disp[i] -= dir * push;
                disp[j] += dir * push;
              }
            }
          }
        }
        for (var i = 0; i < n; i++) {
          centers[i] += disp[i];
        }
      }

      // Fit bounding box comfortably inside the canvas.
      var minX = double.infinity;
      var maxX = -double.infinity;
      var minY = double.infinity;
      var maxY = -double.infinity;
      for (var i = 0; i < n; i++) {
        minX = math.min(minX, centers[i].dx - radii[i]);
        maxX = math.max(maxX, centers[i].dx + radii[i]);
        minY = math.min(minY, centers[i].dy - radii[i]);
        maxY = math.max(maxY, centers[i].dy + radii[i]);
      }
      final boxW = math.max(1.0, maxX - minX);
      final boxH = math.max(1.0, maxY - minY);
      final scale = math.min(
        1.0,
        math.min((size.width - 140) / boxW, (size.height - 64) / boxH),
      );
      final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
      for (var i = 0; i < n; i++) {
        centers[i] = Offset(cx, cy) + (centers[i] - mid) * scale;
        radii[i] = radii[i] * scale;
      }
    }

    // Place labels outside each circle along outward radial direction so they
    // never collide inside overlapping regions.
    final centroid = centers.reduce((a, b) => a + b) / n.toDouble();
    final defaultDirs = [
      const Offset(-0.85, 0.52),
      const Offset(0.85, 0.52),
      const Offset(0.0, -1.0),
    ];
    final labelRects = <Rect>[];
    final labelTexts = <String>[];

    for (var i = 0; i < n; i++) {
      final text = '${entries[i].key} (${entries[i].value.toStringAsFixed(0)})';
      labelTexts.add(text);
      final tp = _layoutLabel(text, palette, maxWidth: math.max(80.0, size.width * 0.34));
      var dir = centers[i] - centroid;
      if (dir.distance < 4.0) {
        dir = defaultDirs[i % defaultDirs.length];
      } else {
        dir = dir / dir.distance;
      }
      final anchor = centers[i] +
          Offset(
            dir.dx * (radii[i] + 10 + tp.width * 0.48),
            dir.dy * (radii[i] + 10 + tp.height * 0.55),
          );
      final left = (anchor.dx - tp.width / 2).clamp(6.0, size.width - tp.width - 6.0);
      final top = (anchor.dy - tp.height / 2).clamp(6.0, size.height - tp.height - 6.0);
      labelRects.add(Rect.fromLTWH(left, top, tp.width, tp.height));
    }

    // Deterministic label-box separation pass.
    for (var iter = 0; iter < 12; iter++) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          if (labelRects[i].overlaps(labelRects[j])) {
            final dy = (labelRects[i].center.dy <= labelRects[j].center.dy) ? -6.0 : 6.0;
            labelRects[i] = labelRects[i].shift(Offset(0, dy));
            labelRects[j] = labelRects[j].shift(Offset(0, -dy));
            labelRects[i] = Rect.fromLTWH(
              labelRects[i].left.clamp(6.0, size.width - labelRects[i].width - 6.0),
              labelRects[i].top.clamp(6.0, size.height - labelRects[i].height - 6.0),
              labelRects[i].width,
              labelRects[i].height,
            );
            labelRects[j] = Rect.fromLTWH(
              labelRects[j].left.clamp(6.0, size.width - labelRects[j].width - 6.0),
              labelRects[j].top.clamp(6.0, size.height - labelRects[j].height - 6.0),
              labelRects[j].width,
              labelRects[j].height,
            );
          }
        }
      }
    }

    return [
      for (var i = 0; i < n; i++)
        PositionedSetCircle(
          name: entries[i].key,
          total: entries[i].value,
          center: centers[i],
          radius: radii[i],
          labelRect: labelRects[i],
          labelText: labelTexts[i],
        ),
    ];
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
    double maxWidth = 120,
    double fontSize = 10,
    Color? color,
    bool center = false,
  }) {
    final tp = SetsCatalogChart._layoutLabel(
      text,
      palette,
      maxWidth: maxWidth,
      fontSize: fontSize,
    );
    if (color != null) {
      final colored = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            fontFamily: ReportPalette.font,
            fontFamilyFallback: ReportPalette.fontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      final offset = center ? pos - Offset(colored.width / 2, colored.height / 2) : pos;
      colored.paint(canvas, offset);
      return;
    }
    final offset = center ? pos - Offset(tp.width / 2, tp.height / 2) : pos;
    tp.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || setTotals.isEmpty) return;
    switch (visual) {
      case Visual.venn:
        _paintCircles(canvas, size, euler: false);
      case Visual.euler:
        _paintCircles(canvas, size, euler: true);
      case Visual.upset:
      default:
        _paintUpSet(canvas, size);
    }
  }

  void _paintCircles(Canvas canvas, Size size, {required bool euler}) {
    final circles = SetsCatalogChart.layoutCircles(
      size,
      intersections,
      setTotals,
      palette,
      euler: euler,
    );
    final maxTotal = circles.fold<double>(
      1.0,
      (m, c) => math.max(m, c.total),
    );
    for (var i = 0; i < circles.length; i++) {
      final item = circles[i];
      final ratio = (item.total / maxTotal).clamp(0.0, 1.0);
      final c = palette.seriesAt(i);
      canvas.drawCircle(
        item.center,
        item.radius,
        Paint()..color = c.withValues(alpha: euler ? 0.28 : (0.14 + 0.28 * ratio)),
      );
      canvas.drawCircle(
        item.center,
        item.radius,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = euler ? 1.8 : (1.2 + 2.2 * ratio),
      );
    }
    // Paint outer labels after all circles so text stays crisp and unobstructed.
    for (var i = 0; i < circles.length; i++) {
      final item = circles[i];
      _drawText(
        canvas,
        item.labelText,
        item.labelRect.topLeft,
        maxWidth: item.labelRect.width + 2,
      );
    }
  }

  void _paintUpSet(Canvas canvas, Size size) {
    final sets = setTotals.keys.take(SetsCatalogChart.maxSets).toList();
    final cols = SetsCatalogChart.computeUpSetColumns(intersections, maxCols: 8);
    if (sets.isEmpty || cols.isEmpty) return;

    final leftW = math.min(150.0, size.width * 0.36);
    final topH = size.height * 0.48;
    final matrixTop = topH + 14;
    final rowH = (size.height - matrixTop - 16) / sets.length;
    final colW = (size.width - leftW - 16) / cols.length;

    final maxSet = setTotals.values.fold<double>(1.0, math.max);
    final maxCol = cols.map((c) => c.count).fold<double>(1.0, math.max);

    // Top vertical intersection-size bars with count labels
    for (var j = 0; j < cols.length; j++) {
      final bh = (cols[j].count / maxCol).clamp(0.05, 1.0) * (topH - 28);
      final x = leftW + j * colW + colW * 0.22;
      final bw = math.max(8.0, colW * 0.56);
      final barTop = topH - bh;
      canvas.drawRect(
        Rect.fromLTWH(x, barTop, bw, bh),
        Paint()..color = cols[j].sets.length >= 2 ? palette.accent : palette.seriesAt(1),
      );
      _drawText(
        canvas,
        cols[j].count.toStringAsFixed(0),
        Offset(x + bw / 2, barTop - 8),
        maxWidth: colW,
        fontSize: 8.5,
        color: palette.textMuted,
        center: true,
      );
    }

    // Left horizontal set-size bars + labels + matrix rows
    for (var i = 0; i < sets.length; i++) {
      final y = matrixTop + (i + 0.5) * rowH;
      _drawText(canvas, sets[i], Offset(6, y - 6), maxWidth: 64, fontSize: 9);
      final barMaxW = leftW - 76;
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
          4.2,
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
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SetsPainter old) =>
      old.visual != visual || old.intersections != intersections || old.palette != palette;
}
