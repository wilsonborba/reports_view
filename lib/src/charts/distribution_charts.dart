import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders distribution catalog chart types (items 55 to 64) using
/// [ReportPalette] tokens and accessible [Semantics] summaries (reports#58, C1 to C23).
class DistributionCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo value;
  final FieldInfo? secondValue;
  final double height;

  const DistributionCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.value,
    this.secondValue,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberLanguage = numberLanguageFor(context);
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final labels = [
      for (final r in page.rows)
        ChartParts.xLabel(r[label.name], label, language: numberLanguage),
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
              painter: _DistributionPainter(
                palette: p,
                visual: visual,
                rows: page.rows,
                label: label,
                value: value,
                secondValue: secondValue,
                numberLanguage: numberLanguage,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  final ReportPalette palette;
  final Visual visual;
  final List<Map<String, dynamic>> rows;
  final FieldInfo label;
  final FieldInfo value;
  final FieldInfo? secondValue;
  final String numberLanguage;

  _DistributionPainter({
    required this.palette,
    required this.visual,
    required this.rows,
    required this.label,
    required this.value,
    required this.secondValue,
    required this.numberLanguage,
  });

  List<double> _numericValues(FieldInfo field) {
    final out = <double>[];
    for (final r in rows) {
      final v = r[field.name];
      if (v is num && v.isFinite) {
        out.add(v.toDouble());
      }
    }
    return out;
  }

  Map<String, List<double>> _groupedValues() {
    final groups = <String, List<double>>{};
    for (final r in rows) {
      final v = r[value.name];
      if (v is! num || !v.isFinite) continue;
      final key = ChartParts.xLabel(
        r[label.name],
        label,
        language: numberLanguage,
      );
      groups.putIfAbsent(key, () => []).add(v.toDouble());
    }
    return groups;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16) return;
    final vals = _numericValues(value);
    if (vals.isEmpty) return;

    switch (visual) {
      case Visual.histogram:
        _paintHistogram(canvas, size, vals);
      case Visual.boxPlot:
        _paintBoxPlot(canvas, size);
      case Visual.violin:
        _paintViolin(canvas, size);
      case Visual.density:
        _paintDensity(canvas, size, vals);
      case Visual.ridgeline:
        _paintRidgeline(canvas, size);
      case Visual.strip:
        _paintStrip(canvas, size);
      case Visual.ecdf:
        _paintEcdf(canvas, size, vals);
      case Visual.qqPlot:
        _paintQqPlot(canvas, size, vals);
      case Visual.populationPyramid:
        _paintPopulationPyramid(canvas, size);
      case Visual.raincloud:
        _paintRaincloud(canvas, size);
      default:
        _paintHistogram(canvas, size, vals);
    }
  }

  void _drawAxes(Canvas canvas, Rect plot) {
    final axisPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axisPaint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 90,
  }) {
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

  void _paintHistogram(Canvas canvas, Size size, List<double> vals) {
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 32);
    _drawAxes(canvas, plot);
    final sorted = [...vals]..sort();
    final minV = sorted.first;
    final maxV = sorted.last;
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    const bins = 8;
    final counts = List<int>.filled(bins, 0);
    for (final v in sorted) {
      final idx = (((v - minV) / span) * (bins - 1)).floor().clamp(0, bins - 1);
      counts[idx]++;
    }
    final maxCount = counts.reduce(math.max).clamp(1, 1 << 30);
    final bw = plot.width / bins;
    final fill = Paint()..color = palette.seriesAt(0);
    for (var i = 0; i < bins; i++) {
      final bh = (counts[i] / maxCount) * (plot.height - 4);
      final rect = Rect.fromLTWH(
        plot.left + i * bw + 2,
        plot.bottom - bh,
        math.max(2, bw - 4),
        bh,
      );
      canvas.drawRect(rect, fill);
    }
    _drawText(
      canvas,
      numberText(minV, 1, language: numberLanguage),
      Offset(plot.left, plot.bottom + 4),
    );
    _drawText(
      canvas,
      numberText(maxV, 1, language: numberLanguage),
      Offset(plot.right - 36, plot.bottom + 4),
    );
  }

  (double, double, double, double, double) _fiveNum(List<double> raw) {
    final s = [...raw]..sort();
    double at(double q) {
      if (s.length == 1) return s.first;
      final idx = q * (s.length - 1);
      final lo = idx.floor();
      final hi = idx.ceil();
      return s[lo] + (s[hi] - s[lo]) * (idx - lo);
    }

    return (s.first, at(0.25), at(0.5), at(0.75), s.last);
  }

  void _paintBoxPlot(Canvas canvas, Size size) {
    final groups = _groupedValues();
    final entries = groups.entries.take(8).toList();
    if (entries.isEmpty) return;
    final all = entries.expand((e) => e.value).toList();
    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 34);
    _drawAxes(canvas, plot);

    double mapY(double v) => plot.bottom - ((v - minV) / span) * plot.height;
    final colW = plot.width / entries.length;
    for (var i = 0; i < entries.length; i++) {
      final (lo, q1, med, q3, hi) = _fiveNum(entries[i].value);
      final cx = plot.left + colW * (i + 0.5);
      final boxW = math.min(28.0, colW * 0.55);
      final c = palette.seriesAt(i);
      final stroke = Paint()
        ..color = c
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final fill = Paint()..color = c.withValues(alpha: 0.25);

      canvas.drawLine(Offset(cx, mapY(lo)), Offset(cx, mapY(hi)), stroke);
      final rect = Rect.fromLTRB(
        cx - boxW / 2,
        mapY(q3),
        cx + boxW / 2,
        mapY(q1),
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
      canvas.drawLine(
        Offset(cx - boxW / 2, mapY(med)),
        Offset(cx + boxW / 2, mapY(med)),
        stroke..strokeWidth = 3,
      );
      _drawText(
        canvas,
        entries[i].key,
        Offset(cx - boxW / 2, plot.bottom + 4),
        maxWidth: math.max(24, colW - 4),
      );
    }
  }

  void _paintViolin(Canvas canvas, Size size) {
    final groups = _groupedValues();
    final entries = groups.entries.take(6).toList();
    if (entries.isEmpty) return;
    final all = entries.expand((e) => e.value).toList();
    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 34);
    _drawAxes(canvas, plot);

    double mapY(double v) => plot.bottom - ((v - minV) / span) * plot.height;
    final colW = plot.width / entries.length;
    for (var i = 0; i < entries.length; i++) {
      final vals = entries[i].value;
      final (lo, q1, med, q3, hi) = _fiveNum(vals);
      final cx = plot.left + colW * (i + 0.5);
      final halfW = math.min(24.0, colW * 0.36);
      final c = palette.seriesAt(i);
      const steps = 12;
      final path = Path();
      for (var s = 0; s <= steps; s++) {
        final t = s / steps;
        final v = lo + (hi - lo) * t;
        final w = halfW * math.sin(t * math.pi).clamp(0.15, 1.0);
        final y = mapY(v);
        if (s == 0) {
          path.moveTo(cx + w, y);
        } else {
          path.lineTo(cx + w, y);
        }
      }
      for (var s = steps; s >= 0; s--) {
        final t = s / steps;
        final v = lo + (hi - lo) * t;
        final w = halfW * math.sin(t * math.pi).clamp(0.15, 1.0);
        path.lineTo(cx - w, mapY(v));
      }
      path.close();
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.35));
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        Offset(cx, mapY(q1)),
        Offset(cx, mapY(q3)),
        Paint()
          ..color = palette.textPrimary
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        Offset(cx, mapY(med)),
        3,
        Paint()..color = palette.canvas,
      );
      _drawText(
        canvas,
        entries[i].key,
        Offset(cx - halfW, plot.bottom + 4),
        maxWidth: math.max(24, colW - 4),
      );
    }
  }

  List<double> _kde(List<double> vals, int steps) {
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final bw = span * 0.18;
    final out = <double>[];
    for (var i = 0; i < steps; i++) {
      final x = minV + span * (i / (steps - 1));
      var sum = 0.0;
      for (final v in vals) {
        final z = (x - v) / bw;
        sum += math.exp(-0.5 * z * z);
      }
      out.add(sum);
    }
    final peak = out.reduce(math.max);
    if (peak <= 0) return out;
    return [for (final d in out) d / peak];
  }

  void _paintDensity(Canvas canvas, Size size, List<double> vals) {
    final plot = Rect.fromLTWH(28, 14, size.width - 40, size.height - 34);
    _drawAxes(canvas, plot);
    const steps = 32;
    final dens = _kde(vals, steps);
    final line = Path();
    final area = Path()..moveTo(plot.left, plot.bottom);
    for (var i = 0; i < steps; i++) {
      final x = plot.left + (i / (steps - 1)) * plot.width;
      final y = plot.bottom - dens[i] * (plot.height - 6);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
      area.lineTo(x, y);
    }
    area
      ..lineTo(plot.right, plot.bottom)
      ..close();
    final c = palette.seriesAt(0);
    canvas.drawPath(area, Paint()..color = c.withValues(alpha: 0.25));
    canvas.drawPath(
      line,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintRidgeline(Canvas canvas, Size size) {
    final groups = _groupedValues();
    final entries = groups.entries.take(6).toList();
    if (entries.isEmpty) return;
    final rowH = (size.height - 20) / entries.length;
    const steps = 24;
    for (var i = 0; i < entries.length; i++) {
      final base = 16 + (i + 1) * rowH;
      final dens = _kde(entries[i].value, steps);
      final c = palette.seriesAt(i);
      final path = Path()..moveTo(80, base);
      final w = math.max(40.0, size.width - 96);
      for (var s = 0; s < steps; s++) {
        final x = 80 + (s / (steps - 1)) * w;
        final y = base - dens[s] * rowH * 1.15;
        path.lineTo(x, y);
      }
      path
        ..lineTo(80 + w, base)
        ..close();
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.35));
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _drawText(canvas, entries[i].key, Offset(8, base - 12), maxWidth: 68);
    }
  }

  void _paintStrip(Canvas canvas, Size size) {
    final groups = _groupedValues();
    final entries = groups.entries.take(8).toList();
    if (entries.isEmpty) return;
    final all = entries.expand((e) => e.value).toList();
    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 34);
    _drawAxes(canvas, plot);

    final colW = plot.width / entries.length;
    for (var i = 0; i < entries.length; i++) {
      final cx = plot.left + colW * (i + 0.5);
      final c = palette.seriesAt(i);
      final dot = Paint()..color = c.withValues(alpha: 0.8);
      for (var j = 0; j < entries[i].value.length; j++) {
        final v = entries[i].value[j];
        final jitter = ((j % 5) - 2) * math.min(4.0, colW * 0.08);
        final y = plot.bottom - ((v - minV) / span) * (plot.height - 8);
        canvas.drawCircle(Offset(cx + jitter, y), 3.5, dot);
      }
      _drawText(
        canvas,
        entries[i].key,
        Offset(cx - colW * 0.4, plot.bottom + 4),
        maxWidth: math.max(24, colW - 4),
      );
    }
  }

  void _paintEcdf(Canvas canvas, Size size, List<double> vals) {
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 32);
    _drawAxes(canvas, plot);
    final sorted = [...vals]..sort();
    final minV = sorted.first;
    final maxV = sorted.last;
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final path = Path()..moveTo(plot.left, plot.bottom);
    for (var i = 0; i < sorted.length; i++) {
      final x = plot.left + ((sorted[i] - minV) / span) * plot.width;
      final prevY = plot.bottom - (i / sorted.length) * plot.height;
      final nextY = plot.bottom - ((i + 1) / sorted.length) * plot.height;
      path
        ..lineTo(x, prevY)
        ..lineTo(x, nextY);
    }
    path.lineTo(plot.right, plot.top);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.seriesAt(0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, '0%', Offset(6, plot.bottom - 10), maxWidth: 28);
    _drawText(canvas, '100%', Offset(4, plot.top), maxWidth: 32);
  }

  /// Inverse standard normal CDF (Acklam's rational approximation).
  double _normalQuantile(double p) {
    const a = [
      -3.969683028665376e+01,
      2.209460984245205e+02,
      -2.759285104469687e+02,
      1.383577518672690e+02,
      -3.066479806614716e+01,
      2.506628277459239e+00,
    ];
    const b = [
      -5.447609879822406e+01,
      1.615858368580409e+02,
      -1.556989798598866e+02,
      6.680131188771972e+01,
      -1.328068155288572e+01,
    ];
    const c = [
      -7.784894002430293e-03,
      -3.223964580411365e-01,
      -2.400758277161838e+00,
      -2.549732539343734e+00,
      4.374664141464968e+00,
      2.938163982698783e+00,
    ];
    const d = [
      7.784695709041462e-03,
      3.224671290700398e-01,
      2.445134137142996e+00,
      3.754408661907416e+00,
    ];
    const pLow = 0.02425;
    const pHigh = 1 - pLow;
    if (p < pLow) {
      final q = math.sqrt(-2 * math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    if (p <= pHigh) {
      final q = p - 0.5;
      final r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
              a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }
    final q = math.sqrt(-2 * math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }

  void _paintQqPlot(Canvas canvas, Size size, List<double> vals) {
    final plot = Rect.fromLTWH(36, 12, size.width - 48, size.height - 32);
    _drawAxes(canvas, plot);
    canvas.drawLine(
      plot.bottomLeft,
      plot.topRight,
      Paint()
        ..color = palette.textMuted.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    final sorted = [...vals]..sort();
    final minV = sorted.first;
    final maxV = sorted.last;
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final zVals = [
      for (var i = 0; i < sorted.length; i++)
        _normalQuantile((i + 0.5) / sorted.length),
    ];
    final minZ = zVals.first;
    final maxZ = zVals.last;
    final zSpan = (maxZ - minZ).abs() < 1e-9 ? 1.0 : maxZ - minZ;
    final dot = Paint()..color = palette.seriesAt(0);
    for (var i = 0; i < sorted.length; i++) {
      final x = plot.left + ((zVals[i] - minZ) / zSpan) * plot.width;
      final y = plot.bottom - ((sorted[i] - minV) / span) * plot.height;
      canvas.drawCircle(Offset(x, y), 3.5, dot);
    }
  }

  void _paintPopulationPyramid(Canvas canvas, Size size) {
    final subset = rows.take(10).toList();
    final leftVals = <double>[];
    final rightVals = <double>[];
    for (final r in subset) {
      final a = (r[value.name] is num)
          ? (r[value.name] as num).toDouble().abs()
          : 0.0;
      final b = (secondValue != null && r[secondValue!.name] is num)
          ? (r[secondValue!.name] as num).toDouble().abs()
          : a * 0.85;
      leftVals.add(a);
      rightVals.add(b);
    }
    final maxV = math.max(
      leftVals.reduce(math.max),
      rightVals.reduce(math.max),
    );
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    const labelW = 64.0;
    final cx = labelW + (size.width - labelW - 12) / 2;
    final halfW = (size.width - labelW - 20) / 2;
    final rowH = (size.height - 16) / subset.length;
    final leftPaint = Paint()..color = palette.seriesAt(0);
    final rightPaint = Paint()..color = palette.seriesAt(1);

    for (var i = 0; i < subset.length; i++) {
      final y = 8 + i * rowH;
      final bh = math.max(4.0, rowH * 0.65);
      final lw = (leftVals[i] / safeMax) * halfW;
      final rw = (rightVals[i] / safeMax) * halfW;
      canvas.drawRect(Rect.fromLTWH(cx - lw, y, lw, bh), leftPaint);
      canvas.drawRect(Rect.fromLTWH(cx + 2, y, rw, bh), rightPaint);
      _drawText(
        canvas,
        ChartParts.xLabel(
          subset[i][label.name],
          label,
          language: numberLanguage,
        ),
        Offset(4, y),
        maxWidth: labelW - 6,
      );
    }
  }

  void _paintRaincloud(Canvas canvas, Size size) {
    final groups = _groupedValues();
    final entries = groups.entries.take(5).toList();
    if (entries.isEmpty) return;
    final all = entries.expand((e) => e.value).toList();
    final minV = all.reduce(math.min);
    final maxV = all.reduce(math.max);
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : maxV - minV;
    final plot = Rect.fromLTWH(76, 12, size.width - 88, size.height - 24);
    final rowH = plot.height / entries.length;

    for (var i = 0; i < entries.length; i++) {
      final base = plot.top + (i + 0.65) * rowH;
      final c = palette.seriesAt(i);
      final dens = _kde(entries[i].value, 20);
      final cloud = Path()..moveTo(plot.left, base);
      for (var s = 0; s < dens.length; s++) {
        final x = plot.left + (s / (dens.length - 1)) * plot.width;
        final y = base - dens[s] * rowH * 0.45;
        cloud.lineTo(x, y);
      }
      cloud
        ..lineTo(plot.right, base)
        ..close();
      canvas.drawPath(cloud, Paint()..color = c.withValues(alpha: 0.3));
      final dot = Paint()..color = c;
      for (var j = 0; j < entries[i].value.length; j++) {
        final x =
            plot.left + ((entries[i].value[j] - minV) / span) * plot.width;
        final y = base + 5 + (j % 3) * 3.0;
        canvas.drawCircle(Offset(x, y), 2.5, dot);
      }
      _drawText(canvas, entries[i].key, Offset(4, base - 10), maxWidth: 68);
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter old) =>
      old.visual != visual ||
      old.rows != rows ||
      old.palette != palette ||
      old.numberLanguage != numberLanguage;
}
