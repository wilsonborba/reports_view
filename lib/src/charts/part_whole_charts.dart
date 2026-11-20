import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders part-of-a-whole catalog chart types (items 45 to 54) using
/// [ReportPalette] tokens and accessible [Semantics] summaries (reports#57, C1 to C23).
class PartWholeCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo value;
  final double height;

  const PartWholeCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.value,
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
        child: switch (visual) {
          Visual.meter => _buildMeter(p),
          Visual.waffle => _buildWaffle(p),
          Visual.treemap => _buildTreemap(p),
          Visual.icicle => _buildIcicle(p),
          Visual.funnel => _buildFunnel(p),
          _ => CustomPaint(
            painter: _PartWholePainter(
              rows: page.rows,
              value: value,
              visual: visual,
              palette: p,
            ),
            child: const SizedBox.expand(),
          ),
        },
      ),
    );
  }

  double _v(Map<String, dynamic> r) =>
      math.max(0.0, measureValue(r[value.name], value) ?? 0.0);

  double _total() {
    final s = page.rows.fold<double>(0.0, (a, r) => a + _v(r));
    return s > 0 ? s : 1.0;
  }

  Widget _buildMeter(ReportPalette p) {
    final total = _total();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 22,
            child: Row(
              children: [
                for (var i = 0; i < page.rows.length; i++)
                  if (_v(page.rows[i]) > 0)
                    Expanded(
                      flex: math.max(
                        1,
                        ((_v(page.rows[i]) / total) * 1000).round(),
                      ),
                      child: Container(
                        color: p.seriesAt(i % ReportPalette.slots),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < page.rows.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    color: p.seriesAt(i % ReportPalette.slots),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ChartParts.xLabel(page.rows[i][label.name], label),
                    style: TextStyle(fontSize: 11, color: p.textPrimary),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaffle(ReportPalette p) {
    final total = _total();
    final cells = <Color>[];
    for (var i = 0; i < page.rows.length; i++) {
      final count = ((_v(page.rows[i]) / total) * 100).round();
      for (var k = 0; k < count && cells.length < 100; k++) {
        cells.add(p.seriesAt(i % ReportPalette.slots));
      }
    }
    while (cells.length < 100) {
      cells.add(p.surfaceAlt);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 100,
          itemBuilder: (_, i) => Container(color: cells[i]),
        ),
      ),
    );
  }

  Widget _buildTreemap(ReportPalette p) {
    final items = [
      for (var i = 0; i < page.rows.length; i++)
        if (_v(page.rows[i]) > 0)
          (
            ChartParts.xLabel(page.rows[i][label.name], label),
            _v(page.rows[i]),
            p.seriesAt(i % ReportPalette.slots),
          ),
    ];
    return CustomPaint(
      painter: _TreemapPainter(items: items, textColor: p.onAccent, border: p.canvas),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildIcicle(ReportPalette p) {
    final total = _total();
    final items = [
      for (var i = 0; i < page.rows.length; i++)
        if (_v(page.rows[i]) > 0) (i, page.rows[i], _v(page.rows[i])),
    ];
    final mid = math.max(1, (items.length / 2).ceil());
    final g1 = items.take(mid).toList();
    final g2 = items.skip(mid).toList();
    final g1Sum = g1.fold<double>(0, (s, e) => s + e.$3);
    final g2Sum = g2.fold<double>(0, (s, e) => s + e.$3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 24,
          margin: const EdgeInsets.only(bottom: 2),
          color: p.surfaceAlt,
          alignment: Alignment.center,
          child: Text(
            label.label,
            style: TextStyle(fontSize: 11, color: p.textPrimary),
          ),
        ),
        SizedBox(
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (g1.isNotEmpty)
                Expanded(
                  flex: math.max(1, ((g1Sum / total) * 1000).round()),
                  child: Container(
                    margin: const EdgeInsets.only(right: 1, bottom: 2),
                    color: p.seriesAt(0).withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Text(
                      'Group 1',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.textPrimary),
                    ),
                  ),
                ),
              if (g2.isNotEmpty)
                Expanded(
                  flex: math.max(1, ((g2Sum / total) * 1000).round()),
                  child: Container(
                    margin: const EdgeInsets.only(left: 1, bottom: 2),
                    color: p.seriesAt(1).withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: Text(
                      'Group 2',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.textPrimary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Expanded(
                  flex: math.max(1, ((item.$3 / total) * 1000).round()),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: p.seriesAt(item.$1 % ReportPalette.slots),
                    alignment: Alignment.center,
                    child: Text(
                      ChartParts.xLabel(item.$2[label.name], label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.onAccent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFunnel(ReportPalette p) {
    var maxV = 1e-9;
    for (final r in page.rows) {
      final v = _v(r);
      if (v > maxV) maxV = v;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < page.rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: FractionallySizedBox(
              widthFactor: (_v(page.rows[i]) / maxV).clamp(0.15, 1.0),
              child: Container(
                height: 24,
                color: p.seriesAt(i % ReportPalette.slots),
                alignment: Alignment.center,
                child: Text(
                  ChartParts.xLabel(page.rows[i][label.name], label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.onAccent),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PartWholePainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo value;
  final Visual visual;
  final ReportPalette palette;

  _PartWholePainter({
    required this.rows,
    required this.value,
    required this.visual,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final vals = [
      for (final r in rows)
        math.max(0.0, measureValue(r[value.name], value) ?? 0.0),
    ];
    final total = vals.fold<double>(0.0, (a, b) => a + b);
    final safeTotal = total > 0 ? total : 1.0;

    if (visual == Visual.gauge) {
      final first = vals.isNotEmpty
          ? (vals.first / safeTotal).clamp(0.0, 1.0)
          : 0.0;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = palette.surfaceAlt
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * first,
        false,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );
      return;
    }

    if (visual == Visual.circlePacking) {
      // Strictly area-proportional radii (r ~ sqrt(val)) packed without overlap.
      final maxV = vals.fold<double>(1e-9, math.max);
      final maxR = radius * 0.42;
      final placed = <(Offset, double, int)>[];
      final order = [for (var i = 0; i < rows.length; i++) i]
        ..sort((a, b) => vals[b].compareTo(vals[a]));
      for (final idx in order) {
        final r = math.max(4.0, maxR * math.sqrt(vals[idx] / maxV));
        if (placed.isEmpty) {
          placed.add((center, r, idx));
          continue;
        }
        var best = center;
        var found = false;
        for (var dist = r; dist < radius * 1.4 && !found; dist += 3.0) {
          for (var a = 0; a < 24; a++) {
            final ang = (a / 24) * 2 * math.pi;
            final cand = center + Offset(math.cos(ang) * dist, math.sin(ang) * dist);
            final overlaps = placed.any((p) => (p.$1 - cand).distance < p.$2 + r + 2.0);
            if (!overlaps) {
              best = cand;
              found = true;
              break;
            }
          }
        }
        placed.add((best, r, idx));
      }
      for (final p in placed) {
        canvas.drawCircle(
          p.$1,
          p.$2,
          Paint()..color = palette.seriesAt(p.$3 % ReportPalette.slots),
        );
      }
      return;
    }

    if (visual == Visual.nightingaleRose) {
      final maxV = vals.fold<double>(1e-9, math.max);
      final sweep = (2 * math.pi) / math.max(1, rows.length);
      var start = -math.pi / 2;
      for (var i = 0; i < rows.length; i++) {
        final r = radius * (vals[i] / maxV).clamp(0.15, 1.0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          start,
          sweep,
          true,
          Paint()..color = palette.seriesAt(i % ReportPalette.slots),
        );
        start += sweep;
      }
      return;
    }

    if (visual == Visual.sunburst) {
      // Multi-ring hierarchy: outer leaf ring, inner parent ring, center root.
      final innerR = radius * 0.58;
      final outerR = radius * 0.96;
      final mid = math.max(1, (rows.length / 2).ceil());
      final g1 = vals.take(mid).fold<double>(0, (s, v) => s + v);
      final g2 = vals.skip(mid).fold<double>(0, (s, v) => s + v);
      var start = -math.pi / 2;
      for (var i = 0; i < rows.length; i++) {
        final sweep = (vals[i] / safeTotal) * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerR),
          start,
          sweep,
          true,
          Paint()..color = palette.seriesAt(i % ReportPalette.slots),
        );
        start += sweep;
      }
      canvas.drawCircle(
        center,
        innerR + 2,
        Paint()..color = palette.surface,
      );
      start = -math.pi / 2;
      for (final (gi, gv) in [(0, g1), (1, g2)]) {
        if (gv <= 0) continue;
        final sweep = (gv / safeTotal) * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: innerR),
          start,
          sweep,
          true,
          Paint()..color = palette.seriesAt(gi).withValues(alpha: 0.75),
        );
        start += sweep;
      }
      canvas.drawCircle(
        center,
        radius * 0.28,
        Paint()..color = palette.surface,
      );
      return;
    }

    // Pie.
    var start = -math.pi / 2;
    for (var i = 0; i < rows.length; i++) {
      final sweep = (vals[i] / safeTotal) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = palette.seriesAt(i % ReportPalette.slots),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PartWholePainter old) =>
      old.rows != rows || old.visual != visual;
}

class _TreemapPainter extends CustomPainter {
  final List<(String, double, Color)> items;
  final Color textColor;
  final Color border;

  _TreemapPainter({
    required this.items,
    required this.textColor,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || size.width <= 4 || size.height <= 4) return;
    final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
    _slice(canvas, Rect.fromLTWH(0, 0, size.width, size.height), sorted);
  }

  void _slice(Canvas canvas, Rect rect, List<(String, double, Color)> list) {
    if (list.isEmpty) return;
    if (list.length == 1) {
      final item = list.first;
      canvas.drawRect(rect.deflate(1), Paint()..color = item.$3);
      if (rect.width > 24 && rect.height > 16) {
        final tp = TextPainter(
          text: TextSpan(
            text: item.$1,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: ReportPalette.font,
              fontFamilyFallback: ReportPalette.fontFallback,
            ).copyWith(color: textColor),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '...',
        )..layout(maxWidth: rect.width - 8);
        tp.paint(canvas, rect.topLeft + const Offset(4, 4));
      }
      return;
    }
    final total = list.fold<double>(0, (s, e) => s + e.$2);
    final mid = (list.length / 2).ceil();
    final left = list.take(mid).toList();
    final right = list.skip(mid).toList();
    final leftSum = left.fold<double>(0, (s, e) => s + e.$2);
    final frac = total > 0 ? (leftSum / total).clamp(0.05, 0.95) : 0.5;
    if (rect.width >= rect.height) {
      final w1 = rect.width * frac;
      _slice(canvas, Rect.fromLTWH(rect.left, rect.top, w1, rect.height), left);
      _slice(
        canvas,
        Rect.fromLTWH(rect.left + w1, rect.top, rect.width - w1, rect.height),
        right,
      );
    } else {
      final h1 = rect.height * frac;
      _slice(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, h1), left);
      _slice(
        canvas,
        Rect.fromLTWH(rect.left, rect.top + h1, rect.width, rect.height - h1),
        right,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TreemapPainter old) => old.items != items;
}
