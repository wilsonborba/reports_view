import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'bar_charts.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Renders comparison catalog chart types (catalog items 3, 4, 6 to 23) using
/// [ReportPalette] tokens, zero baselines for bar/length comparisons, and
/// accessible [Semantics] summaries (reports#55, C1 to C23).
class ComparisonCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo dimension;
  final List<FieldInfo> measures;
  final FieldInfo? seriesField;
  final double height;

  const ComparisonCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.dimension,
    required this.measures,
    this.seriesField,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberLanguage = numberLanguageFor(context);
    final rows = page.rows;
    if (rows.isEmpty || measures.isEmpty) {
      return const SizedBox.shrink();
    }

    final primary = measures.first;
    final labels = [
      for (final r in rows)
        ChartParts.xLabel(
          r[dimension.name],
          dimension,
          language: numberLanguage,
        ),
    ];
    final summary =
        '${visual.name}: ${labels.take(4).join(', ')} (${rows.length})';

    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: switch (visual) {
          Visual.rankingBar => _buildRanking(context, p),
          Visual.groupedBar => _buildGroupedOrStacked100(p, percent100: false),
          Visual.stackedBar100 => _buildGroupedOrStacked100(
            p,
            percent100: true,
          ),
          Visual.divergingBar => _buildDiverging(p, numberLanguage),
          Visual.floatingBar => _buildRangeComparison(
            p,
            mode: _RangeMode.floating,
            numberLanguage: numberLanguage,
          ),
          Visual.lollipop => _buildLollipopOrDot(p, isLollipop: true),
          Visual.dotPlot => _buildLollipopOrDot(p, isLollipop: false),
          Visual.dumbbell => _buildRangeComparison(
            p,
            mode: _RangeMode.dumbbell,
            numberLanguage: numberLanguage,
          ),
          Visual.slope => _buildSlope(p),
          Visual.bullet => _buildBullet(p),
          Visual.utilizationBar => _buildUtilization(p, numberLanguage),
          Visual.pictogram => _buildPictogram(p),
          Visual.radialBar => _buildRadial(
            p,
            circular: false,
            numberLanguage: numberLanguage,
          ),
          Visual.circularBar => _buildRadial(
            p,
            circular: true,
            numberLanguage: numberLanguage,
          ),
          Visual.radar => _buildRadar(p),
          Visual.parallelCoordinates => _buildParallel(p),
          Visual.marimekko => _buildMarimekko(p),
          Visual.waterfall => _buildWaterfall(p),
          Visual.pareto => _buildPareto(p),
          Visual.smallMultiples => _buildSmallMultiples(p),
          _ => VerticalBarChart(
            page: page,
            x: dimension,
            measure: primary,
            height: height,
          ),
        },
      ),
    );
  }

  double _val(Map<String, dynamic> row, FieldInfo f) =>
      measureValue(row[f.name], f) ?? 0.0;

  double _maxPositive(List<FieldInfo> fs) {
    var m = 1e-9;
    for (final r in page.rows) {
      for (final f in fs) {
        final v = _val(r, f).abs();
        if (v > m) m = v;
      }
    }
    return m;
  }

  Widget _rowLegend(ReportPalette p, List<FieldInfo> fs) {
    if (fs.length <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < fs.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, color: p.seriesAt(i)),
              const SizedBox(width: 4),
              Text(
                fs[i].label,
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRanking(BuildContext context, ReportPalette p) {
    final primary = measures.first;
    final sorted = [...page.rows]
      ..sort((a, b) => _val(b, primary).compareTo(_val(a, primary)));
    final sortedPage = DatasetPage(
      descriptor: page.descriptor,
      rows: sorted,
      offset: page.offset,
      limit: page.limit,
      totalRows: page.totalRows,
    );
    return SingleChildScrollView(
      child: RankingBars(
        page: sortedPage,
        label: dimension,
        measure: primary,
        maxItems: null,
      ),
    );
  }

  Widget _buildGroupedOrStacked100(
    ReportPalette p, {
    required bool percent100,
  }) {
    final maxVal = percent100 ? 100.0 : _maxPositive(measures);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowLegend(p, measures),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final r in page.rows)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: percent100
                              ? _stacked100Column(p, r)
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var i = 0; i < measures.length; i++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.bottomCenter,
                                            heightFactor:
                                                (_val(
                                                          r,
                                                          measures[i],
                                                        ).clamp(0.0, maxVal) /
                                                        maxVal)
                                                    .clamp(0.02, 1.0),
                                            child: Container(
                                              color: p.seriesAt(i),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ChartParts.xLabel(r[dimension.name], dimension),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: p.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stacked100Column(ReportPalette p, Map<String, dynamic> r) {
    final vals = [for (final m in measures) math.max(0.0, _val(r, m))];
    final sum = vals.fold<double>(0.0, (a, b) => a + b);
    if (sum <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < measures.length; i++)
          if (vals[i] > 0)
            Expanded(
              flex: math.max(1, ((vals[i] / sum) * 1000).round()),
              child: Container(color: p.seriesAt(i)),
            ),
      ],
    );
  }

  Widget _buildDiverging(ReportPalette p, String numberLanguage) {
    final primary = measures.first;
    final maxAbs = _maxPositive([primary]);
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final v = _val(r, primary);
        final frac = (v.abs() / maxAbs).clamp(0.0, 1.0);
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                ChartParts.xLabel(r[dimension.name], dimension),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final half = c.maxWidth / 2;
                  final w = half * frac;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: c.maxWidth, height: 18),
                      Positioned(
                        left: half,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: p.border),
                      ),
                      Positioned(
                        left: v >= 0 ? half : half - w,
                        width: math.max(2, w),
                        height: 14,
                        child: Container(
                          color: v >= 0 ? p.positive : p.negative,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(
                valueText(r[primary.name], primary, language: numberLanguage),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRangeComparison(
    ReportPalette p, {
    required _RangeMode mode,
    required String numberLanguage,
  }) {
    final f1 = measures[0];
    final f2 = measures.length > 1 ? measures[1] : measures[0];
    final maxVal = _maxPositive([f1, f2]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rowLegend(p, [f1, if (measures.length > 1) f2]),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: page.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = page.rows[i];
              final v1 = math.max(0.0, _val(r, f1));
              final v2 = math.max(0.0, _val(r, f2));
              final lo = math.min(v1, v2) / maxVal;
              final hi = math.max(v1, v2) / maxVal;
              return Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      ChartParts.xLabel(r[dimension.name], dimension),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final left = c.maxWidth * lo;
                        final right = c.maxWidth * hi;
                        return SizedBox(
                          height: 18,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(height: 2, color: p.border),
                              Positioned(
                                left: left,
                                width: math.max(4, right - left),
                                height: mode == _RangeMode.floating ? 12 : 3,
                                child: Container(color: p.seriesAt(0)),
                              ),
                              if (mode == _RangeMode.dumbbell) ...[
                                Positioned(
                                  left: math.max(
                                    0,
                                    c.maxWidth * (v1 / maxVal) - 5,
                                  ),
                                  child: _dot(10, p.seriesAt(0)),
                                ),
                                Positioned(
                                  left: math.max(
                                    0,
                                    c.maxWidth * (v2 / maxVal) - 5,
                                  ),
                                  child: _dot(10, p.seriesAt(1)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLollipopOrDot(ReportPalette p, {required bool isLollipop}) {
    final primary = measures.first;
    final maxVal = _maxPositive([primary]);
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final frac = (math.max(0.0, _val(r, primary)) / maxVal).clamp(0.0, 1.0);
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                ChartParts.xLabel(r[dimension.name], dimension),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) {
                  final x = (c.maxWidth - 12) * frac;
                  return SizedBox(
                    height: 16,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(height: 1, color: p.border),
                        if (isLollipop)
                          Positioned(
                            left: 0,
                            width: math.max(2, x),
                            height: 3,
                            child: Container(color: p.seriesAt(0)),
                          ),
                        Positioned(left: x, child: _dot(10, p.seriesAt(0))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueText(r[primary.name], primary, language: numberLanguage),
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        );
      },
    );
  }

  Widget _dot(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _buildSlope(ReportPalette p) {
    final f1 = measures[0];
    final f2 = measures.length > 1 ? measures[1] : measures[0];
    final maxVal = _maxPositive([f1, f2]);
    return CustomPaint(
      painter: _SlopePainter(
        rows: page.rows,
        dimension: dimension,
        first: f1,
        second: f2,
        maxVal: maxVal,
        palette: p,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildBullet(ReportPalette p) {
    final actual = measures[0];
    final target = measures.length > 1 ? measures[1] : measures[0];
    final maxVal = _maxPositive([actual, target]);
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final aFrac = (math.max(0.0, _val(r, actual)) / maxVal).clamp(0.0, 1.0);
        final tFrac = (math.max(0.0, _val(r, target)) / maxVal).clamp(0.0, 1.0);
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                ChartParts.xLabel(r[dimension.name], dimension),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        width: c.maxWidth,
                        height: 18,
                        color: p.surfaceAlt,
                      ),
                      Container(
                        width: c.maxWidth * aFrac,
                        height: 8,
                        color: p.seriesAt(0),
                      ),
                      Positioned(
                        left: (c.maxWidth - 3) * tFrac,
                        child: Container(
                          width: 3,
                          height: 18,
                          color: p.textPrimary,
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

  Widget _buildUtilization(ReportPalette p, String numberLanguage) {
    final primary = measures.first;
    final maxVal = primary.type == 'percent' ? 100.0 : _maxPositive([primary]);
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final frac = (math.max(0.0, _val(r, primary)) / maxVal).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ChartParts.xLabel(
                    r[dimension.name],
                    dimension,
                    language: numberLanguage,
                  ),
                  style: TextStyle(fontSize: 12, color: p.textPrimary),
                ),
                Text(
                  valueText(r[primary.name], primary, language: numberLanguage),
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 10,
                backgroundColor: p.surfaceAlt,
                color: p.seriesAt(i % ReportPalette.slots),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPictogram(ReportPalette p) {
    final primary = measures.first;
    final maxVal = _maxPositive([primary]);
    return ListView.separated(
      itemCount: page.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = page.rows[i];
        final count = ((math.max(0.0, _val(r, primary)) / maxVal) * 10)
            .round()
            .clamp(0, 10);
        return Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                ChartParts.xLabel(r[dimension.name], dimension),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.textPrimary),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 4,
                children: [
                  for (var k = 0; k < 10; k++)
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: k < count ? p.seriesAt(0) : p.surfaceAlt,
                    ),
                ],
              ),
            ),
            Text(
              valueText(r[primary.name], primary, language: numberLanguage),
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRadial(
    ReportPalette p, {
    required bool circular,
    required String numberLanguage,
  }) {
    final primary = measures.first;
    final maxVal = _maxPositive([primary]);
    return CustomPaint(
      painter: _RadialPainter(
        rows: page.rows,
        measure: primary,
        maxVal: maxVal,
        palette: p,
        circular: circular,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildRadar(ReportPalette p) {
    final maxVal = _maxPositive(measures);
    return CustomPaint(
      painter: _RadarPainter(
        rows: page.rows,
        dimension: dimension,
        measures: measures,
        maxVal: maxVal,
        palette: p,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildParallel(ReportPalette p) {
    final maxVal = _maxPositive(measures);
    return CustomPaint(
      painter: _ParallelPainter(
        rows: page.rows,
        measures: measures,
        maxVal: maxVal,
        palette: p,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildMarimekko(ReportPalette p) {
    final primary = measures.first;
    final widthField = measures.length > 1 ? measures[1] : primary;
    final totalW = page.rows.fold<double>(
      0.0,
      (a, r) => a + math.max(1.0, _val(r, widthField)),
    );
    final maxH = _maxPositive([primary]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < page.rows.length; i++)
          Expanded(
            flex: math.max(
              1,
              ((math.max(1.0, _val(page.rows[i], widthField)) / totalW) * 1000)
                  .round(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor:
                          (math.max(0.0, _val(page.rows[i], primary)) / maxH)
                              .clamp(0.05, 1.0),
                      child: Container(
                        color: p.seriesAt(i % ReportPalette.slots),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ChartParts.xLabel(page.rows[i][dimension.name], dimension),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: p.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaterfall(ReportPalette p) {
    final primary = measures.first;
    var running = 0.0;
    var minY = 0.0;
    var maxY = 0.0;
    final steps = <(double start, double end, double delta)>[];
    for (final r in page.rows) {
      final d = _val(r, primary);
      final next = running + d;
      steps.add((running, next, d));
      minY = math.min(minY, math.min(running, next));
      maxY = math.max(maxY, math.max(running, next));
      running = next;
    }
    final span = math.max(1e-9, maxY - minY);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < page.rows.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final lo =
                            (math.min(steps[i].$1, steps[i].$2) - minY) / span;
                        final hi =
                            (math.max(steps[i].$1, steps[i].$2) - minY) / span;
                        final bottom = c.maxHeight * lo;
                        final h = math.max(3.0, c.maxHeight * (hi - lo));
                        return Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: bottom,
                              height: h,
                              child: Container(
                                color: steps[i].$3 >= 0
                                    ? p.positive
                                    : p.negative,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ChartParts.xLabel(page.rows[i][dimension.name], dimension),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: p.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPareto(ReportPalette p) {
    final primary = measures.first;
    final sorted = [...page.rows]
      ..sort((a, b) => _val(b, primary).compareTo(_val(a, primary)));
    final total = sorted.fold<double>(
      0.0,
      (a, r) => a + math.max(0.0, _val(r, primary)),
    );
    final maxBar = _maxPositive([primary]);
    return CustomPaint(
      painter: _ParetoPainter(
        rows: sorted,
        dimension: dimension,
        measure: primary,
        total: total > 0 ? total : 1.0,
        maxBar: maxBar,
        palette: p,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildSmallMultiples(ReportPalette p) {
    final items = measures.take(4).toList();
    return GridView.count(
      crossAxisCount: items.length > 1 ? 2 : 1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.8,
      children: [
        for (var i = 0; i < items.length; i++)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                items[i].label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              Expanded(
                child: VerticalBarChart(
                  page: page,
                  x: dimension,
                  measure: items[i],
                  color: p.seriesAt(i),
                  height: 90,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

enum _RangeMode { floating, dumbbell }

class _SlopePainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo dimension;
  final FieldInfo first;
  final FieldInfo second;
  final double maxVal;
  final ReportPalette palette;

  _SlopePainter({
    required this.rows,
    required this.dimension,
    required this.first,
    required this.second,
    required this.maxVal,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 24.0;
    const padY = 16.0;
    final h = math.max(1.0, size.height - padY * 2);
    for (var i = 0; i < rows.length; i++) {
      final v1 = (measureValue(rows[i][first.name], first) ?? 0.0).clamp(
        0.0,
        maxVal,
      );
      final v2 = (measureValue(rows[i][second.name], second) ?? 0.0).clamp(
        0.0,
        maxVal,
      );
      final y1 = size.height - padY - (v1 / maxVal) * h;
      final y2 = size.height - padY - (v2 / maxVal) * h;
      final paint = Paint()
        ..color = palette.seriesAt(i % ReportPalette.slots)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(padX, y1), Offset(size.width - padX, y2), paint);
      canvas.drawCircle(Offset(padX, y1), 3.5, paint);
      canvas.drawCircle(Offset(size.width - padX, y2), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SlopePainter old) => old.rows != rows;
}

class _RadialPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo measure;
  final double maxVal;
  final ReportPalette palette;
  final bool circular;

  _RadialPainter({
    required this.rows,
    required this.measure,
    required this.maxVal,
    required this.palette,
    required this.circular,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.44;
    if (circular) {
      final step = (2 * math.pi) / math.max(1, rows.length);
      final innerR = maxR * 0.3;
      for (var i = 0; i < rows.length; i++) {
        final v = math.max(
          0.0,
          measureValue(rows[i][measure.name], measure) ?? 0.0,
        );
        final angle = -math.pi / 2 + i * step;
        final outer = innerR + (v / maxVal) * (maxR - innerR);
        final p = Paint()
          ..color = palette.seriesAt(i % ReportPalette.slots)
          ..strokeWidth = math.max(
            4.0,
            (2 * math.pi * innerR / math.max(1, rows.length)) * 0.7,
          )
          ..strokeCap = StrokeCap.butt;
        canvas.drawLine(
          center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR),
          center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
          p,
        );
      }
    } else {
      final ringGap = maxR / math.max(1, rows.length + 1);
      for (var i = 0; i < rows.length; i++) {
        final v = math.max(
          0.0,
          measureValue(rows[i][measure.name], measure) ?? 0.0,
        );
        final r = ringGap * (i + 1);
        final sweep = (v / maxVal).clamp(0.0, 1.0) * 1.75 * math.pi;
        final paint = Paint()
          ..color = palette.seriesAt(i % ReportPalette.slots)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(4.0, ringGap * 0.65);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          sweep,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadialPainter old) => old.rows != rows;
}

class _RadarPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo dimension;
  final List<FieldInfo> measures;
  final double maxVal;
  final ReportPalette palette;

  _RadarPainter({
    required this.rows,
    required this.dimension,
    required this.measures,
    required this.maxVal,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(3, rows.length);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final gridPaint = Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.5, gridPaint);

    for (var mIdx = 0; mIdx < measures.length; mIdx++) {
      final m = measures[mIdx];
      final path = Path();
      for (var i = 0; i < rows.length; i++) {
        final v =
            math.max(0.0, measureValue(rows[i][m.name], m) ?? 0.0) / maxVal;
        final angle = -math.pi / 2 + (2 * math.pi * i / n);
        final pt =
            center +
            Offset(math.cos(angle) * radius * v, math.sin(angle) * radius * v);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      final c = palette.seriesAt(mIdx);
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.22));
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.rows != rows;
}

class _ParallelPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final List<FieldInfo> measures;
  final double maxVal;
  final ReportPalette palette;

  _ParallelPainter({
    required this.rows,
    required this.measures,
    required this.maxVal,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 20.0;
    const padY = 16.0;
    final axisCount = math.max(2, measures.length);
    final stepX = (size.width - padX * 2) / (axisCount - 1);
    final h = math.max(1.0, size.height - padY * 2);
    for (var a = 0; a < axisCount; a++) {
      final x = padX + a * stepX;
      canvas.drawLine(
        Offset(x, padY),
        Offset(x, size.height - padY),
        Paint()..color = palette.border,
      );
    }
    for (var i = 0; i < rows.length; i++) {
      final path = Path();
      for (var a = 0; a < measures.length; a++) {
        final v =
            math.max(
              0.0,
              measureValue(rows[i][measures[a].name], measures[a]) ?? 0.0,
            ) /
            maxVal;
        final x = padX + a * stepX;
        final y = size.height - padY - v * h;
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.seriesAt(i % ReportPalette.slots)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParallelPainter old) => old.rows != rows;
}

class _ParetoPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final FieldInfo dimension;
  final FieldInfo measure;
  final double total;
  final double maxBar;
  final ReportPalette palette;

  _ParetoPainter({
    required this.rows,
    required this.dimension,
    required this.measure,
    required this.total,
    required this.maxBar,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty) return;
    const padY = 16.0;
    final h = math.max(1.0, size.height - padY * 2);
    final slotW = size.width / rows.length;
    final linePath = Path();
    var cum = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final v = math.max(
        0.0,
        measureValue(rows[i][measure.name], measure) ?? 0.0,
      );
      cum += v;
      final barH = (v / maxBar) * h;
      final xCenter = slotW * (i + 0.5);
      final barW = slotW * 0.55;
      canvas.drawRect(
        Rect.fromLTWH(
          xCenter - barW / 2,
          size.height - padY - barH,
          barW,
          barH,
        ),
        Paint()..color = palette.seriesAt(0),
      );
      final cumY = size.height - padY - (cum / total).clamp(0.0, 1.0) * h;
      if (i == 0) {
        linePath.moveTo(xCenter, cumY);
      } else {
        linePath.lineTo(xCenter, cumY);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = palette.highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _ParetoPainter old) => old.rows != rows;
}
