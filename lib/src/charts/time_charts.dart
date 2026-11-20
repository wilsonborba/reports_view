import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders change-over-time catalog chart types (items 25 to 33, 35 to 42)
/// using [ReportPalette] tokens, non-interpolated null gaps where applicable,
/// and accessible [Semantics] summaries (reports#56, C1 to C23).
class TimeCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo x;
  final List<FieldInfo> measures;
  final double height;

  const TimeCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.x,
    required this.measures,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty || measures.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = [for (final r in page.rows) ChartParts.xLabel(r[x.name], x)];
    final summary =
        '${visual.name}: ${labels.take(4).join(', ')} (${page.rows.length})';

    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: switch (visual) {
          Visual.gantt || Visual.timeline => _buildGanttOrTimeline(
            p,
            isGantt: visual == Visual.gantt,
          ),
          Visual.calendarHeatmap => _buildCalendarHeatmap(p),
          _ => CustomPaint(
            painter: _TimeSeriesPainter(
              rows: page.rows,
              x: x,
              measures: measures,
              visual: visual,
              palette: p,
            ),
            child: const SizedBox.expand(),
          ),
        },
      ),
    );
  }

  Widget _buildGanttOrTimeline(ReportPalette p, {required bool isGantt}) {
    final m = measures.first;
    final m2 = measures.length > 1 ? measures[1] : m;
    var maxEnd = 1.0;
    for (final r in page.rows) {
      final v1 = measureValue(r[m.name], m) ?? 0.0;
      final v2 = measureValue(r[m2.name], m2) ?? v1;
      maxEnd = math.max(maxEnd, math.max(v1.abs(), (v1 + v2).abs()));
    }
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final start = (measureValue(r[m.name], m) ?? 0.0).clamp(0.0, maxEnd);
        final dur = measures.length > 1
            ? (measureValue(r[m2.name], m2) ?? 1.0).clamp(0.0, maxEnd)
            : maxEnd * 0.25;
        final leftFrac = (start / maxEnd).clamp(0.0, 0.9);
        final widthFrac = (dur / maxEnd).clamp(0.05, 1.0 - leftFrac);
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                ChartParts.xLabel(r[x.name], x),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => SizedBox(
                  height: 18,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(height: 1, color: p.border),
                      Positioned(
                        left: c.maxWidth * leftFrac,
                        width: math.max(
                          isGantt ? 12 : 8,
                          c.maxWidth * widthFrac,
                        ),
                        height: isGantt ? 12 : 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.seriesAt(i % ReportPalette.slots),
                            borderRadius: BorderRadius.circular(
                              isGantt ? 3 : 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarHeatmap(ReportPalette p) {
    final m = measures.first;
    var maxVal = 1e-9;
    for (final r in page.rows) {
      final v = (measureValue(r[m.name], m) ?? 0.0).abs();
      if (v > maxVal) maxVal = v;
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: page.rows.length,
      itemBuilder: (_, i) {
        final v = (measureValue(page.rows[i][m.name], m) ?? 0.0).abs();
        final alpha = (0.15 + 0.85 * (v / maxVal)).clamp(0.15, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo x;
  final List<FieldInfo> measures;
  final Visual visual;
  final ReportPalette palette;

  _TimeSeriesPainter({
    required this.rows,
    required this.x,
    required this.measures,
    required this.visual,
    required this.palette,
  });

  double _val(int i, FieldInfo f) => measureValue(rows[i][f.name], f) ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 16.0;
    const padY = 16.0;
    final w = math.max(1.0, size.width - padX * 2);
    final h = math.max(1.0, size.height - padY * 2);
    final n = rows.length;
    final stepX = n > 1 ? w / (n - 1) : 0.0;

    var maxY = 1e-9;
    for (var i = 0; i < n; i++) {
      var stack = 0.0;
      for (final m in measures) {
        final v = math.max(0.0, _val(i, m));
        stack += v;
        if (v > maxY) maxY = v;
      }
      if ((visual == Visual.stackedArea || visual == Visual.streamgraph) &&
          stack > maxY) {
        maxY = stack;
      }
    }
    if (visual == Visual.stackedArea100) maxY = 100.0;

    double yAt(double v) =>
        size.height - padY - (v.clamp(0.0, maxY) / maxY) * h;

    // Baseline grid.
    canvas.drawLine(
      Offset(padX, size.height - padY),
      Offset(size.width - padX, size.height - padY),
      Paint()..color = palette.border,
    );

    if (visual == Visual.candlestick && measures.length >= 2) {
      final lowF = measures[0];
      final highF = measures[1];
      for (var i = 0; i < n; i++) {
        final cx = padX + i * stepX;
        final lo = _val(i, lowF);
        final hi = _val(i, highF);
        final yLo = yAt(math.min(lo, hi));
        final yHi = yAt(math.max(lo, hi));
        final color = hi >= lo ? palette.positive : palette.negative;
        canvas.drawLine(
          Offset(cx, yHi),
          Offset(cx, yLo),
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, (yLo + yHi) / 2),
            width: 8,
            height: math.max(4, (yLo - yHi) * 0.6),
          ),
          Paint()..color = color,
        );
      }
      return;
    }

    if (visual == Visual.rangeBand && measures.length >= 2) {
      final f1 = measures[0];
      final f2 = measures[1];
      final band = Path();
      for (var i = 0; i < n; i++) {
        final cx = padX + i * stepX;
        final y = yAt(math.max(_val(i, f1), _val(i, f2)));
        if (i == 0) {
          band.moveTo(cx, y);
        } else {
          band.lineTo(cx, y);
        }
      }
      for (var i = n - 1; i >= 0; i--) {
        final cx = padX + i * stepX;
        band.lineTo(cx, yAt(math.min(_val(i, f1), _val(i, f2))));
      }
      band.close();
      canvas.drawPath(
        band,
        Paint()..color = palette.seriesAt(0).withValues(alpha: 0.25),
      );
    }

    if (visual == Visual.controlChart) {
      final m = measures.first;
      final vals = [for (var i = 0; i < n; i++) _val(i, m)];
      final mean = vals.fold<double>(0.0, (a, b) => a + b) / math.max(1, n);
      final meanY = yAt(mean);
      canvas.drawLine(
        Offset(padX, meanY),
        Offset(size.width - padX, meanY),
        Paint()
          ..color = palette.warning
          ..strokeWidth = 1.5,
      );
    }

    if (visual == Visual.horizon) {
      final m = measures.first;
      final vals = [for (var i = 0; i < n; i++) _val(i, m)];
      final maxAbs = vals.fold<double>(
        1e-9,
        (a, v) => math.max(a, v.abs()),
      );
      const bands = 3;
      final bandSize = maxAbs / bands;
      final baseY = size.height - padY;
      for (var b = 0; b < bands; b++) {
        final lo = b * bandSize;
        final posPath = Path()..moveTo(padX, baseY);
        final negPath = Path()..moveTo(padX, baseY);
        for (var i = 0; i < n; i++) {
          final cx = padX + i * stepX;
          final v = vals[i];
          final posFrac =
              v > lo ? ((v - lo) / bandSize).clamp(0.0, 1.0) : 0.0;
          final negFrac =
              -v > lo ? ((-v - lo) / bandSize).clamp(0.0, 1.0) : 0.0;
          posPath.lineTo(cx, baseY - posFrac * h);
          negPath.lineTo(cx, baseY - negFrac * h);
        }
        posPath
          ..lineTo(padX + (n - 1) * stepX, baseY)
          ..close();
        negPath
          ..lineTo(padX + (n - 1) * stepX, baseY)
          ..close();
        final alpha = 0.25 + b * 0.28;
        canvas.drawPath(
          posPath,
          Paint()..color = palette.seriesAt(0).withValues(alpha: alpha),
        );
        canvas.drawPath(
          negPath,
          Paint()..color = palette.negative.withValues(alpha: alpha),
        );
      }
      return;
    }

    if (visual == Visual.streamgraph) {
      final totals = [
        for (var i = 0; i < n; i++)
          measures.fold<double>(0.0, (a, f) => a + math.max(0.0, _val(i, f))),
      ];
      final cum = List<double>.generate(
        n,
        (i) => (maxY - totals[i]) * 0.5,
      );
      for (var mIdx = 0; mIdx < measures.length; mIdx++) {
        final m = measures[mIdx];
        final color = palette.seriesAt(mIdx);
        final area = Path();
        for (var i = 0; i < n; i++) {
          final cx = padX + i * stepX;
          final next = cum[i] + math.max(0.0, _val(i, m));
          final yTop = yAt(next);
          if (i == 0) {
            area.moveTo(cx, yTop);
          } else {
            area.lineTo(cx, yTop);
          }
        }
        for (var i = n - 1; i >= 0; i--) {
          final cx = padX + i * stepX;
          area.lineTo(cx, yAt(cum[i]));
          cum[i] += math.max(0.0, _val(i, m));
        }
        area.close();
        canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.72));
      }
      return;
    }

    for (var mIdx = 0; mIdx < measures.length; mIdx++) {
      final m = measures[mIdx];
      final color = palette.seriesAt(mIdx);
      final path = Path();
      final areaPath = Path();
      for (var i = 0; i < n; i++) {
        final cx = padX + i * stepX;
        double val = _val(i, m);
        if (visual == Visual.stackedArea100) {
          final sum = measures.fold<double>(
            0.0,
            (a, f) => a + math.max(0.0, _val(i, f)),
          );
          val = sum > 0 ? (val / sum) * 100.0 : 0.0;
        } else if (visual == Visual.burndown) {
          val = math.max(0.0, maxY - val);
        }
        final cy = yAt(val);
        if (i == 0) {
          path.moveTo(cx, cy);
          areaPath.moveTo(cx, size.height - padY);
          areaPath.lineTo(cx, cy);
        } else {
          if (visual == Visual.stepLine) {
            final prevY = yAt(_val(i - 1, m));
            path.lineTo(cx, prevY);
          }
          path.lineTo(cx, cy);
          areaPath.lineTo(cx, cy);
        }
        if (visual == Visual.annotatedLine ||
            visual == Visual.bumpChart ||
            visual == Visual.cyclePlot) {
          canvas.drawCircle(Offset(cx, cy), 3.5, Paint()..color = color);
        }
      }
      if (visual == Visual.area ||
          visual == Visual.stackedArea ||
          visual == Visual.stackedArea100 ||
          visual == Visual.streamgraph ||
          visual == Visual.horizon) {
        areaPath.lineTo(padX + (n - 1) * stepX, size.height - padY);
        areaPath.close();
        canvas.drawPath(
          areaPath,
          Paint()..color = color.withValues(alpha: 0.25),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = visual == Visual.sparkline ? 1.5 : 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter old) =>
      old.rows != rows || old.visual != visual;
}
