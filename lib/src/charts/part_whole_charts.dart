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
    final total = _total();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < page.rows.length; i++)
          if (_v(page.rows[i]) > 0)
            Expanded(
              flex: math.max(1, ((_v(page.rows[i]) / total) * 1000).round()),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.all(6),
                color: p.seriesAt(i % ReportPalette.slots),
                child: Text(
                  ChartParts.xLabel(page.rows[i][label.name], label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.onAccent),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildIcicle(ReportPalette p) {
    final total = _total();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 28,
          margin: const EdgeInsets.only(bottom: 4),
          color: p.surfaceAlt,
          alignment: Alignment.center,
          child: Text(
            label.label,
            style: TextStyle(fontSize: 11, color: p.textPrimary),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < page.rows.length; i++)
                if (_v(page.rows[i]) > 0)
                  Expanded(
                    flex: math.max(
                      1,
                      ((_v(page.rows[i]) / total) * 1000).round(),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: p.seriesAt(i % ReportPalette.slots),
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
      final step = (2 * math.pi) / math.max(1, rows.length);
      for (var i = 0; i < rows.length; i++) {
        final frac = (vals[i] / safeTotal).clamp(0.05, 1.0);
        final r = radius * 0.2 + radius * 0.3 * math.sqrt(frac);
        final angle = i * step;
        final c =
            center +
            Offset(
              math.cos(angle) * radius * 0.45,
              math.sin(angle) * radius * 0.45,
            );
        canvas.drawCircle(
          c,
          r,
          Paint()..color = palette.seriesAt(i % ReportPalette.slots),
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

    // Pie & Sunburst.
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
      if (visual == Visual.sunburst) {
        canvas.drawCircle(
          center,
          radius * 0.4,
          Paint()..color = palette.surface,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PartWholePainter old) =>
      old.rows != rows || old.visual != visual;
}
