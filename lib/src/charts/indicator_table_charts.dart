import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Positioned word entry for [Visual.wordCloud].
class PlacedWord {
  final String text;
  final double weight;
  final Rect rect;
  final double fontSize;
  final Color color;

  const PlacedWord({
    required this.text,
    required this.weight,
    required this.rect,
    required this.fontSize,
    required this.color,
  });
}

/// Renders indicator and table catalog items 100, 102, 103, and 104
/// (`kpi_sparkline`, `heat_table`, `status_scorecard`, `word_cloud`)
/// from real [DatasetPage] rows using [ReportPalette] tokens and [Semantics].
class IndicatorTableChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo? dimension;
  final List<FieldInfo> measures;
  final double height;

  /// Maximum rows/words rendered in compact card mode to preserve legibility.
  static const int maxItems = 24;

  const IndicatorTableChart({
    super.key,
    required this.page,
    required this.visual,
    required this.dimension,
    required this.measures,
    this.height = 240,
  });

  /// Deterministic non-overlapping layout for [Visual.wordCloud] words.
  static List<PlacedWord> layoutWords(
    Size size,
    List<Map<String, dynamic>> rows,
    FieldInfo labelField,
    FieldInfo valueField,
    ReportPalette palette, {
    String? numberLanguage,
  }) {
    final entries = <(String, double)>[];
    for (final r in rows.take(maxItems)) {
      final w = ChartParts.xLabel(
        r[labelField.name],
        labelField,
        language: numberLanguage,
      ).trim();
      final v = (measureValue(r[valueField.name], valueField) ?? 0.0).abs();
      if (w.isNotEmpty) entries.add((w, v));
    }
    if (entries.isEmpty) return const [];
    entries.sort((a, b) => b.$2.compareTo(a.$2));
    final minV = entries.map((e) => e.$2).reduce(math.min);
    final maxV = entries.map((e) => e.$2).reduce(math.max);
    final span = math.max(1e-6, maxV - minV);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final placed = <PlacedWord>[];

    for (var i = 0; i < entries.length; i++) {
      final (word, val) = entries[i];
      final t = (val - minV) / span;
      final fs = 10.5 + t * 13.5;
      final color = palette.seriesAt(i);
      final tp = TextPainter(
        text: TextSpan(
          text: word,
          style: TextStyle(
            color: color,
            fontSize: fs,
            fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w500,
            fontFamily: ReportPalette.font,
            fontFamilyFallback: ReportPalette.fontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(60.0, size.width - 16));

      Rect? chosen;
      for (var step = 0; step < 360; step++) {
        final angle = step * 0.38;
        final radius = 6.5 * math.sqrt(step.toDouble());
        final x = cx + radius * 1.25 * math.cos(angle) - tp.width / 2;
        final y = cy + radius * 0.72 * math.sin(angle) - tp.height / 2;
        final candidate = Rect.fromLTWH(x, y, tp.width + 6, tp.height + 4);
        if (candidate.left < 4 ||
            candidate.top < 4 ||
            candidate.right > size.width - 4 ||
            candidate.bottom > size.height - 4) {
          continue;
        }
        final collides = placed.any((p) => p.rect.overlaps(candidate));
        if (!collides) {
          chosen = candidate;
          break;
        }
      }
      if (chosen != null) {
        placed.add(
          PlacedWord(
            text: word,
            weight: val,
            rect: chosen,
            fontSize: fs,
            color: color,
          ),
        );
      }
    }
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberLanguage = numberLanguageFor(context);
    if (page.rows.isEmpty || measures.isEmpty) return const SizedBox.shrink();
    final primary = measures.first;
    final summary = '${visual.name}: ${primary.label} (${page.rows.length})';
    return Semantics(
      label: summary,
      child: switch (visual) {
        Visual.kpiSparkline => _buildKpiSparkline(p, primary, numberLanguage),
        Visual.heatTable => _buildHeatTable(p, numberLanguage),
        Visual.statusScorecard => _buildScorecard(p, numberLanguage),
        Visual.wordCloud => _buildWordCloud(p, primary, numberLanguage),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildKpiSparkline(
    ReportPalette p,
    FieldInfo primary,
    String numberLanguage,
  ) {
    final vals = [
      for (final r in page.rows.take(maxItems))
        measureValue(r[primary.name], primary) ?? 0.0,
    ];
    final current = vals.isEmpty ? 0.0 : vals.last;
    final prev = vals.length >= 2 ? vals[vals.length - 2] : current;
    final delta = current - prev;
    final pct = prev.abs() > 1e-6 ? (delta / prev.abs()) * 100.0 : 0.0;
    final isUp = delta >= 0;
    final deltaColor = delta.abs() < 1e-6
        ? p.textMuted
        : (isUp ? p.positive : p.negative);
    final sign = delta > 0 ? '+' : '';
    final valStr = valueText(current, primary, language: numberLanguage);

    return Container(
      height: math.min(height, 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  labelWithUnit(primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 12,
                    fontFamily: ReportPalette.font,
                    fontFamilyFallback: ReportPalette.fontFallback,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: deltaColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$sign${numberText(pct, 1, language: numberLanguage)}%',
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: ReportPalette.font,
                    fontFamilyFallback: ReportPalette.fontFallback,
                  ),
                ),
              ),
            ],
          ),
          Text(
            valStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFamily: ReportPalette.font,
              fontFamilyFallback: ReportPalette.fontFallback,
            ),
          ),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(vals: vals, color: p.accent, fill: p.accent.withValues(alpha: 0.15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatTable(ReportPalette p, String numberLanguage) {
    final rows = page.rows.take(8).toList();
    final dim = dimension;
    final cols = measures.take(3).toList();
    final colMax = <String, double>{};
    for (final m in cols) {
      var mx = 1e-6;
      for (final r in rows) {
        mx = math.max(mx, (measureValue(r[m.name], m) ?? 0.0).abs());
      }
      colMax[m.name] = mx;
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                if (dim != null)
                  Expanded(
                    flex: 2,
                    child: Text(
                      dim.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: ReportPalette.font,
                        fontFamilyFallback: ReportPalette.fontFallback,
                      ),
                    ),
                  ),
                for (final m in cols)
                  Expanded(
                    flex: 2,
                    child: Text(
                      m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: ReportPalette.font,
                        fontFamilyFallback: ReportPalette.fontFallback,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border, width: 0.6)),
              ),
              child: Row(
                children: [
                  if (dim != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        ChartParts.xLabel(
                          rows[i][dim.name],
                          dim,
                          language: numberLanguage,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 11,
                          fontFamily: ReportPalette.font,
                          fontFamilyFallback: ReportPalette.fontFallback,
                        ),
                      ),
                    ),
                  for (final m in cols)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _HeatCell(
                          value: measureValue(rows[i][m.name], m) ?? 0.0,
                          maxVal: colMax[m.name] ?? 1.0,
                          formatted: valueText(
                            measureValue(rows[i][m.name], m) ?? 0.0,
                            m,
                            language: numberLanguage,
                          ),
                          palette: p,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScorecard(ReportPalette p, String numberLanguage) {
    final rows = page.rows.take(8).toList();
    final dim = dimension;
    final cols = measures.take(3).toList();
    final colMax = <String, double>{};
    for (final m in cols) {
      var mx = 1e-6;
      for (final r in rows) {
        mx = math.max(mx, (measureValue(r[m.name], m) ?? 0.0).abs());
      }
      colMax[m.name] = mx;
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                if (dim != null)
                  Expanded(
                    flex: 2,
                    child: Text(
                      dim.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: ReportPalette.font,
                        fontFamilyFallback: ReportPalette.fontFallback,
                      ),
                    ),
                  ),
                for (final m in cols)
                  Expanded(
                    child: Text(
                      m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: ReportPalette.font,
                        fontFamilyFallback: ReportPalette.fontFallback,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border, width: 0.6)),
              ),
              child: Row(
                children: [
                  if (dim != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        ChartParts.xLabel(
                          rows[i][dim.name],
                          dim,
                          language: numberLanguage,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 11,
                          fontFamily: ReportPalette.font,
                          fontFamilyFallback: ReportPalette.fontFallback,
                        ),
                      ),
                    ),
                  for (final m in cols)
                    Expanded(
                      child: Center(
                        child: _ScoreBadge(
                          ratio: ((measureValue(rows[i][m.name], m) ?? 0.0).abs() /
                                  (colMax[m.name] ?? 1.0))
                              .clamp(0.0, 1.0),
                          formatted: valueText(
                            measureValue(rows[i][m.name], m) ?? 0.0,
                            m,
                            language: numberLanguage,
                          ),
                          palette: p,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordCloud(
    ReportPalette p,
    FieldInfo primary,
    String numberLanguage,
  ) {
    final dim = dimension ?? primary;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _WordCloudPainter(
            words: layoutWords(
              Size(constraints.maxWidth, height),
              page.rows,
              dim,
              primary,
              p,
              numberLanguage: numberLanguage,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double value;
  final double maxVal;
  final String formatted;
  final ReportPalette palette;

  const _HeatCell({
    required this.value,
    required this.maxVal,
    required this.formatted,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value.abs() / maxVal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.06 + ratio * 0.24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              fontFamily: ReportPalette.font,
              fontFamilyFallback: ReportPalette.fontFallback,
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio.clamp(0.06, 1.0),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double ratio;
  final String formatted;
  final ReportPalette palette;

  const _ScoreBadge({
    required this.ratio,
    required this.formatted,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final color = ratio >= 0.67
        ? palette.positive
        : ratio >= 0.34
        ? palette.caution
        : palette.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        formatted,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: ReportPalette.font,
          fontFamilyFallback: ReportPalette.fontFallback,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> vals;
  final Color color;
  final Color fill;

  const _SparklinePainter({
    required this.vals,
    required this.color,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.isEmpty || size.width <= 4 || size.height <= 4) return;
    final minV = vals.reduce(math.min);
    final maxV = vals.reduce(math.max);
    final span = math.max(1e-6, maxV - minV);
    final pts = <Offset>[];
    for (var i = 0; i < vals.length; i++) {
      final x = vals.length == 1
          ? size.width / 2
          : (i / (vals.length - 1)) * size.width;
      final y = size.height - 4 - ((vals[i] - minV) / span) * (size.height - 8);
      pts.add(Offset(x, y));
    }
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, 3.5, Paint()..color = color);
      return;
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      line.lineTo(pts[i].dx, pts[i].dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 3.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.vals != vals || old.color != color;
}

class _WordCloudPainter extends CustomPainter {
  final List<PlacedWord> words;

  const _WordCloudPainter({required this.words});

  @override
  void paint(Canvas canvas, Size size) {
    for (final w in words) {
      final tp = TextPainter(
        text: TextSpan(
          text: w.text,
          style: TextStyle(
            color: w.color,
            fontSize: w.fontSize,
            fontWeight: w.fontSize > 16 ? FontWeight.w700 : FontWeight.w500,
            fontFamily: ReportPalette.font,
            fontFamilyFallback: ReportPalette.fontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      tp.paint(canvas, w.rect.topLeft + const Offset(3, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WordCloudPainter old) => old.words != words;
}
