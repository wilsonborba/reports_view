import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/chart_strings.dart';
import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Computed ROC and PR curves with AUCs from scores and binary labels.
/// [rocAuc] is null whenever both positive and negative classes are not present;
/// [prAuc] is null whenever no positive samples exist.
class RocPrResult {
  final List<Offset> rocPoints;
  final List<Offset> prPoints;
  final double? rocAuc;
  final double? prAuc;

  const RocPrResult({
    required this.rocPoints,
    required this.prPoints,
    required this.rocAuc,
    required this.prAuc,
  });

  bool get hasRoc => rocAuc != null && rocPoints.length >= 2;
  bool get hasPr => prAuc != null && prPoints.length >= 2;
}

/// Computed confusion matrix from sample-level actual vs predicted classes.
class ConfusionMatrixData {
  final List<String> labels;
  final List<List<int>> counts;
  final int total;

  const ConfusionMatrixData({
    required this.labels,
    required this.counts,
    required this.total,
  });
}

/// Two-sided Wright map layout sharing a single logit scale across persons and items.
class WrightMapData {
  final double minLogit;
  final double maxLogit;
  final List<({double midLogit, int count})> personBins;
  final List<({String label, double difficulty})> items;

  const WrightMapData({
    required this.minLogit,
    required this.maxLogit,
    required this.personBins,
    required this.items,
  });
}

/// Computed 2PL IRT curve points for a single item (`b` difficulty, `a` discrimination).
class IrtCurve {
  final String label;
  final double difficulty;
  final double discrimination;
  final List<Offset> points;

  const IrtCurve({
    required this.label,
    required this.difficulty,
    required this.discrimination,
    required this.points,
  });
}

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
  static const int maxItems = 64;

  const ScienceAiChart({
    super.key,
    required this.page,
    required this.visual,
    required this.dimension,
    required this.measures,
    this.height = 240,
  });

  /// Parses a binary outcome cleanly, returning null for missing/invalid data
  /// (`null` is never treated as `0`/`false`, per C8).
  static bool? binaryOutcome(dynamic raw, FieldInfo field) {
    if (raw == null) {
      return field.missingMeans == 'zero' ? false : null;
    }
    if (raw is bool) return raw;
    final val = measureValue(raw, field);
    if (val == null || !val.isFinite) return null;
    return val >= 0.5;
  }

  /// Extracts paired numeric scores/times and binary outcomes, omitting rows
  /// with missing values rather than converting `null` to `0.0` (C8).
  static List<({double value, bool outcome, String label})>
  extractPairedBinarySamples(
    List<Map<String, dynamic>> rows,
    FieldInfo? dimension,
    FieldInfo primary,
    FieldInfo? secondary,
  ) {
    final samples = <({double value, bool outcome, String label})>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final val = measureValue(r[primary.name], primary);
      if (val == null || !val.isFinite) continue;
      bool? outcome;
      if (secondary != null) {
        outcome = binaryOutcome(r[secondary.name], secondary);
      } else if (r.containsKey('label')) {
        outcome = binaryOutcome(r['label'], primary);
      } else if (r.containsKey('actual')) {
        outcome = binaryOutcome(r['actual'], primary);
      } else if (r.containsKey('event')) {
        outcome = binaryOutcome(r['event'], primary);
      }
      if (outcome == null) continue;
      final lbl = dimension != null
          ? ChartParts.xLabel(r[dimension.name], dimension)
          : '${i + 1}';
      samples.add((value: val, outcome: outcome, label: lbl));
    }
    return samples;
  }

  /// Normalizes class weights into descending top-k probabilities summing to 1.0.
  /// Omits missing (`null`) entries rather than fabricating `0.0`, while keeping
  /// explicit real zero entries (C8).
  static List<({String label, double prob})> computeTopK(
    List<Map<String, dynamic>> rows,
    FieldInfo? dimension,
    FieldInfo primary,
  ) {
    final entries = <(String, double)>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final raw = measureValue(r[primary.name], primary);
      if (raw == null || !raw.isFinite) continue;
      final lbl = dimension != null
          ? ChartParts.xLabel(r[dimension.name], dimension)
          : '${i + 1}';
      entries.add((lbl, raw.abs()));
    }
    if (entries.isEmpty) return const [];
    final rawSum = entries.fold<double>(0.0, (a, e) => a + e.$2);
    final out = [
      for (final (lbl, val) in entries)
        (label: lbl, prob: rawSum > 0.0 ? val / rawSum : 0.0),
    ]..sort((a, b) => b.prob.compareTo(a.prob));
    return out;
  }

  /// Computes observed event frequency per predicted probability bin.
  static List<({double meanPred, double obsFreq, int count})>
  computeCalibration(List<double> probs, List<bool> outcomes, {int bins = 5}) {
    final n = math.min(probs.length, outcomes.length);
    if (n == 0 || bins < 1) return const [];
    final predSums = List<double>.filled(bins, 0.0);
    final obsSums = List<int>.filled(bins, 0);
    final counts = List<int>.filled(bins, 0);
    for (var i = 0; i < n; i++) {
      final p = probs[i].clamp(0.0, 1.0);
      final b = (p * bins).floor().clamp(0, bins - 1);
      predSums[b] += p;
      obsSums[b] += outcomes[i] ? 1 : 0;
      counts[b] += 1;
    }
    final out = <({double meanPred, double obsFreq, int count})>[];
    for (var b = 0; b < bins; b++) {
      if (counts[b] == 0) continue;
      out.add((
        meanPred: predSums[b] / counts[b],
        obsFreq: obsSums[b] / counts[b],
        count: counts[b],
      ));
    }
    return out;
  }

  /// Computes monotonic ROC `(fpr, tpr)` from `(0,0)` to `(1,1)` when both classes
  /// are present, PR `(recall, precision)` when positives exist, and trapezoidal AUCs.
  /// Leaves ROC/PR empty with `null` AUC when undefined rather than inventing numbers.
  static RocPrResult computeRocPr(List<double> scores, List<bool> labels) {
    final limit = math.min(scores.length, labels.length);
    final pairs = [
      for (var i = 0; i < limit; i++)
        if (scores[i].isFinite) (score: scores[i], pos: labels[i]),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final n = pairs.length;
    final totalPos = pairs.where((e) => e.pos).length;
    final totalNeg = n - totalPos;
    if (n == 0 || totalPos == 0) {
      return const RocPrResult(
        rocPoints: [],
        prPoints: [],
        rocAuc: null,
        prAuc: null,
      );
    }

    if (totalNeg == 0) {
      // All positives: PR is valid (precision stays 1.0 across recall [0..1]);
      // FPR is undefined without negatives, so ROC and rocAuc remain unavailable.
      final pr = <Offset>[const Offset(0, 1)];
      var tp = 0;
      var idx = 0;
      while (idx < pairs.length) {
        final threshold = pairs[idx].score;
        while (idx < pairs.length &&
            (pairs[idx].score - threshold).abs() < 1e-12) {
          tp++;
          idx++;
        }
        pr.add(Offset(tp / totalPos, 1.0));
      }
      var prAuc = 0.0;
      for (var i = 1; i < pr.length; i++) {
        final dx = pr[i].dx - pr[i - 1].dx;
        final avgP = (pr[i].dy + pr[i - 1].dy) * 0.5;
        prAuc += dx * avgP;
      }
      return RocPrResult(
        rocPoints: const [],
        prPoints: pr,
        rocAuc: null,
        prAuc: prAuc.clamp(0.0, 1.0),
      );
    }

    final roc = <Offset>[const Offset(0, 0)];
    final pr = <Offset>[const Offset(0, 1)];
    var tp = 0;
    var fp = 0;
    var idx = 0;
    while (idx < pairs.length) {
      final threshold = pairs[idx].score;
      while (idx < pairs.length &&
          (pairs[idx].score - threshold).abs() < 1e-12) {
        if (pairs[idx].pos) {
          tp++;
        } else {
          fp++;
        }
        idx++;
      }
      final fpr = fp / totalNeg;
      final tpr = tp / totalPos;
      final precision = tp / (tp + fp);
      roc.add(Offset(fpr, tpr));
      pr.add(Offset(tpr, precision));
    }
    if (roc.last != const Offset(1, 1)) {
      roc.add(const Offset(1, 1));
    }

    var rocAuc = 0.0;
    for (var i = 1; i < roc.length; i++) {
      final dx = roc[i].dx - roc[i - 1].dx;
      final avgY = (roc[i].dy + roc[i - 1].dy) * 0.5;
      rocAuc += dx * avgY;
    }

    var prAuc = 0.0;
    for (var i = 1; i < pr.length; i++) {
      final dx = pr[i].dx - pr[i - 1].dx;
      final avgP = (pr[i].dy + pr[i - 1].dy) * 0.5;
      prAuc += dx * avgP;
    }

    return RocPrResult(
      rocPoints: roc,
      prPoints: pr,
      rocAuc: rocAuc.clamp(0.0, 1.0),
      prAuc: prAuc.clamp(0.0, 1.0),
    );
  }

  /// Tallies a sample-level confusion matrix from predicted and actual labels so cells
  /// sum strictly to the sample count.
  static ConfusionMatrixData computeConfusionMatrix(
    List<Map<String, dynamic>> rows,
    FieldInfo? dimension,
    FieldInfo primary,
    FieldInfo? secondary, {
    String? numberLanguage,
  }) {
    final samples = <(String actual, String predicted)>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.containsKey('actual') && r.containsKey('predicted')) {
        if (r['actual'] == null || r['predicted'] == null) continue;
        samples.add(('${r['actual']}', '${r['predicted']}'));
      } else if (secondary != null) {
        final rawPred = r[primary.name];
        final rawAct = r[secondary.name];
        if ((rawPred == null && primary.missingMeans != 'zero') ||
            (rawAct == null && secondary.missingMeans != 'zero')) {
          continue;
        }
        final pred = valueText(rawPred, primary, language: numberLanguage);
        final act = valueText(rawAct, secondary, language: numberLanguage);
        samples.add((act, pred));
      } else if (dimension != null) {
        final rawPred = r[primary.name];
        if (r[dimension.name] == null ||
            (rawPred == null && primary.missingMeans != 'zero')) {
          continue;
        }
        final act = ChartParts.xLabel(
          r[dimension.name],
          dimension,
          language: numberLanguage,
        );
        final pred = valueText(rawPred, primary, language: numberLanguage);
        samples.add((act, pred));
      }
    }

    if (samples.isEmpty) {
      return const ConfusionMatrixData(labels: [], counts: [], total: 0);
    }

    final labelSet = <String>{
      for (final (a, p) in samples) ...[a, p],
    }.toList()..sort();
    final idxOf = <String, int>{
      for (var i = 0; i < labelSet.length; i++) labelSet[i]: i,
    };
    final k = labelSet.length;
    final mat = List.generate(k, (_) => List<int>.filled(k, 0));
    for (final (act, pred) in samples) {
      mat[idxOf[act]!][idxOf[pred]!] += 1;
    }
    return ConfusionMatrixData(
      labels: labelSet,
      counts: mat,
      total: samples.length,
    );
  }

  /// Computes 2PL IRT probability (`infoCurve == false`) or Fisher information
  /// (`infoCurve == true`: `I(theta) = a^2 * P(theta) * (1 - P(theta))`) curves directly from
  /// item difficulty `b` and discrimination `a`.
  static List<IrtCurve> computeIrtCurves(
    List<double> difficulties,
    List<double>? discriminations,
    List<String> itemLabels, {
    required bool infoCurve,
    double thetaMin = -3.0,
    double thetaMax = 3.0,
    int steps = 60,
  }) {
    final count = difficulties.length;
    final curves = <IrtCurve>[];
    final thetaSpan = math.max(1e-6, thetaMax - thetaMin);
    for (var idx = 0; idx < count; idx++) {
      final b = difficulties[idx];
      final a = discriminations != null && idx < discriminations.length
          ? discriminations[idx].clamp(0.1, 4.0)
          : 1.0;
      final pts = <Offset>[];
      for (var s = 0; s <= steps; s++) {
        final theta = thetaMin + (s / steps) * thetaSpan;
        final p = 1.0 / (1.0 + math.exp(-a * (theta - b)));
        final y = infoCurve ? (a * a * p * (1.0 - p)) : p;
        pts.add(Offset(theta, y));
      }
      curves.add(
        IrtCurve(
          label: idx < itemLabels.length ? itemLabels[idx] : 'I${idx + 1}',
          difficulty: b,
          discrimination: a,
          points: pts,
        ),
      );
    }
    return curves;
  }

  /// Builds a two-sided Wright map sharing one vertical logit scale between person abilities
  /// (binned histogram on the left) and item difficulties (markers/labels on the right).
  static WrightMapData computeWrightMap(
    List<double> personAbilities,
    List<double> itemDifficulties,
    List<String> itemLabels, {
    int binCount = 10,
  }) {
    final all = [...personAbilities, ...itemDifficulties];
    final rawMin = all.isEmpty ? -3.0 : all.reduce(math.min);
    final rawMax = all.isEmpty ? 3.0 : all.reduce(math.max);
    final minLogit = math.min(-3.0, (rawMin * 2).floorToDouble() / 2);
    final maxLogit = math.max(3.0, (rawMax * 2).ceilToDouble() / 2);
    final span = math.max(1e-6, maxLogit - minLogit);
    final binCounts = List<int>.filled(binCount, 0);
    for (final theta in personAbilities) {
      final idx = (((theta - minLogit) / span) * binCount).floor().clamp(
        0,
        binCount - 1,
      );
      binCounts[idx] += 1;
    }
    final step = span / binCount;
    final bins = [
      for (var i = 0; i < binCount; i++)
        (midLogit: minLogit + (i + 0.5) * step, count: binCounts[i]),
    ];
    final items = [
      for (var i = 0; i < itemDifficulties.length; i++)
        (
          label: i < itemLabels.length ? itemLabels[i] : 'I${i + 1}',
          difficulty: itemDifficulties[i],
        ),
    ];
    return WrightMapData(
      minLogit: minLogit,
      maxLogit: maxLogit,
      personBins: bins,
      items: items,
    );
  }

  /// Computes the Kaplan-Meier product-limit survival step function `S(t)` from
  /// observed times and binary event indicators (`true = event, false = censored`).
  static List<({double time, double survival, bool censored})>
  computeKaplanMeier(List<double> times, List<bool> events) {
    final n = math.min(times.length, events.length);
    if (n == 0) return const [(time: 0.0, survival: 1.0, censored: false)];
    final obs = [
      for (var i = 0; i < n; i++)
        (t: math.max(0.0, times[i]), event: events[i]),
    ]..sort((a, b) => a.t.compareTo(b.t));

    final steps = <({double time, double survival, bool censored})>[
      (time: 0.0, survival: 1.0, censored: false),
    ];
    var atRisk = n;
    var s = 1.0;
    var i = 0;
    while (i < obs.length) {
      final t = obs[i].t;
      var d = 0;
      var c = 0;
      while (i < obs.length && (obs[i].t - t).abs() < 1e-12) {
        if (obs[i].event) {
          d++;
        } else {
          c++;
        }
        i++;
      }
      if (d > 0 && atRisk > 0) {
        s *= (1.0 - d / atRisk);
      }
      steps.add((time: t, survival: s.clamp(0.0, 1.0), censored: c > 0));
      atRisk -= (d + c);
    }
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberLanguage = numberLanguageFor(context);
    if (page.rows.isEmpty || measures.isEmpty) return const SizedBox.shrink();
    final primary = measures.first;
    final secondary = measures.length > 1 ? measures[1] : null;
    final subset = page.rows.take(maxItems).toList();
    String summary;
    if (visual == Visual.rocPr) {
      final paired = extractPairedBinarySamples(
        subset,
        dimension,
        primary,
        secondary,
      );
      final res = computeRocPr(
        [for (final s in paired) s.value],
        [for (final s in paired) s.outcome],
      );
      if (res.hasRoc) {
        summary =
            'rocPr: ROC AUC ${numberText(res.rocAuc!, 2, language: numberLanguage)} | PR AUC ${numberText(res.prAuc!, 2, language: numberLanguage)} (${paired.length}/${subset.length})';
      } else if (res.hasPr) {
        summary =
            'rocPr: ${context.tr('roc_single_class_summary')} | PR AUC ${numberText(res.prAuc!, 2, language: numberLanguage)} (${paired.length}/${subset.length})';
      } else {
        summary =
            'rocPr: ${context.tr('roc_pr_unavailable_summary')} (${paired.length}/${subset.length})';
      }
    } else {
      summary = '${visual.name}: ${primary.label} (${subset.length})';
    }
    final chartStrings = _ScienceChartStrings.fromContext(context);
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _ScienceAiPainter(
              visual: visual,
              rows: subset,
              dimension: dimension,
              primary: primary,
              secondary: secondary,
              palette: p,
              strings: chartStrings,
              numberLanguage: numberLanguage,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScienceChartStrings {
  final String Function(String pr) rocSingleClassBanner;
  final String rocPrMissingData;
  final String rocPrSingleClass;
  final String noValidProbabilitySamples;
  final String calibrationUnavailable;
  final String confusionMatrixUnavailable;
  final String noValidLearningCurveSamples;
  final String noValidIrtItemParameters;
  final String noValidWrightMapLogits;
  final String noValidItemDifficultyPairs;
  final String kaplanMeierUnavailable;
  final String localeTag;

  const _ScienceChartStrings({
    required this.rocSingleClassBanner,
    required this.rocPrMissingData,
    required this.rocPrSingleClass,
    required this.noValidProbabilitySamples,
    required this.calibrationUnavailable,
    required this.confusionMatrixUnavailable,
    required this.noValidLearningCurveSamples,
    required this.noValidIrtItemParameters,
    required this.noValidWrightMapLogits,
    required this.noValidItemDifficultyPairs,
    required this.kaplanMeierUnavailable,
    required this.localeTag,
  });

  factory _ScienceChartStrings.fromContext(BuildContext context) {
    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en';
    return _ScienceChartStrings(
      rocSingleClassBanner: (pr) =>
          context.tr('roc_single_class_banner', {'pr': pr}),
      rocPrMissingData: context.tr('roc_pr_missing_data'),
      rocPrSingleClass: context.tr('roc_pr_single_class'),
      noValidProbabilitySamples: context.tr('no_valid_probability_samples'),
      calibrationUnavailable: context.tr('calibration_unavailable'),
      confusionMatrixUnavailable: context.tr('confusion_matrix_unavailable'),
      noValidLearningCurveSamples: context.tr(
        'no_valid_learning_curve_samples',
      ),
      noValidIrtItemParameters: context.tr('no_valid_irt_item_parameters'),
      noValidWrightMapLogits: context.tr('no_valid_wright_map_logits'),
      noValidItemDifficultyPairs: context.tr('no_valid_item_difficulty_pairs'),
      kaplanMeierUnavailable: context.tr('kaplan_meier_unavailable'),
      localeTag: locale,
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
  final _ScienceChartStrings strings;
  final String numberLanguage;

  const _ScienceAiPainter({
    required this.visual,
    required this.rows,
    required this.dimension,
    required this.primary,
    required this.secondary,
    required this.palette,
    required this.strings,
    required this.numberLanguage,
  });

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 110,
    double fontSize = 9.5,
    Color? color,
    bool center = false,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
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
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final offset = center ? pos - Offset(tp.width / 2, tp.height / 2) : pos;
    tp.paint(canvas, offset);
  }

  List<double> _validValues(FieldInfo f) => rows
      .map((r) => measureValue(r[f.name], f))
      .whereType<double>()
      .where((v) => v.isFinite)
      .toList();

  String _label(int i) => dimension != null
      ? ChartParts.xLabel(rows[i][dimension!.name], dimension!)
      : '${i + 1}';

  void _paintUnavailable(Canvas canvas, Size size, String message) {
    _drawText(
      canvas,
      message,
      Offset(size.width / 2, size.height / 2),
      maxWidth: math.max(80.0, size.width - 24),
      fontSize: 10.5,
      color: palette.textMuted,
      center: true,
      maxLines: 2,
      textAlign: TextAlign.center,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 24 || size.height <= 24 || rows.isEmpty) return;
    switch (visual) {
      case Visual.topKProb:
        _paintTopK(canvas, size);
      case Visual.calibration:
        _paintCalibration(canvas, size);
      case Visual.confusionMatrix:
        _paintConfusionMatrix(canvas, size);
      case Visual.rocPr:
        _paintRocPr(canvas, size);
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
    final top = ScienceAiChart.computeTopK(
      rows,
      dimension,
      primary,
    ).take(6).toList();
    if (top.isEmpty) {
      _paintUnavailable(canvas, size, strings.noValidProbabilitySamples);
      return;
    }
    final leftW = math.min(115.0, size.width * 0.34);
    const rightPad = 50.0;
    final barMaxW = math.max(20.0, size.width - leftW - rightPad);
    final rowH = (size.height - 16) / top.length;
    final maxP = top.map((e) => e.prob).fold<double>(1e-6, math.max);

    for (var i = 0; i < top.length; i++) {
      final y = 8 + i * rowH;
      final cy = y + rowH / 2;
      _drawText(canvas, top[i].label, Offset(6, cy - 6), maxWidth: leftW - 10);
      final bw = (top[i].prob / maxP).clamp(0.04, 1.0) * barMaxW;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(leftW, cy - 7, bw, 14),
          const Radius.circular(3),
        ),
        Paint()
          ..color = palette
              .seriesAt(i == 0 ? 0 : 1)
              .withValues(alpha: i == 0 ? 0.95 : 0.65),
      );
      _drawText(
        canvas,
        '${numberText(top[i].prob * 100, 1, language: numberLanguage)}%',
        Offset(leftW + bw + 6, cy - 6),
        maxWidth: 42,
        color: palette.textMuted,
      );
    }
  }

  void _paintCalibration(Canvas canvas, Size size) {
    final samples = ScienceAiChart.extractPairedBinarySamples(
      rows,
      dimension,
      primary,
      secondary,
    );
    if (samples.isEmpty) {
      _paintUnavailable(canvas, size, strings.calibrationUnavailable);
      return;
    }
    final plot = Rect.fromLTWH(38, 18, size.width - 54, size.height - 42);
    _paintAxes(canvas, plot);
    canvas.drawLine(
      plot.bottomLeft,
      plot.topRight,
      Paint()
        ..color = palette.textMuted.withValues(alpha: 0.45)
        ..strokeWidth = 1.0,
    );
    final bins = ScienceAiChart.computeCalibration(
      [for (final s in samples) s.value],
      [for (final s in samples) s.outcome],
    );
    final pts = [
      for (final b in bins)
        Offset(
          plot.left + b.meanPred.clamp(0.0, 1.0) * plot.width,
          plot.bottom - b.obsFreq.clamp(0.0, 1.0) * plot.height,
        ),
    ];
    if (pts.length >= 2) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
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
      canvas.drawCircle(pt, 4.0, Paint()..color = palette.accent);
    }
    _drawText(
      canvas,
      numberText(0, 1, language: numberLanguage),
      Offset(6, plot.bottom - 6),
      maxWidth: 28,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(1, 1, language: numberLanguage),
      Offset(6, plot.top - 4),
      maxWidth: 28,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      'Predicted vs Observed',
      Offset(plot.left, plot.bottom + 6),
      maxWidth: 160,
      fontSize: 9,
      color: palette.textMuted,
    );
  }

  void _paintRocPr(Canvas canvas, Size size) {
    final samples = ScienceAiChart.extractPairedBinarySamples(
      rows,
      dimension,
      primary,
      secondary,
    );
    final res = ScienceAiChart.computeRocPr(
      [for (final s in samples) s.value],
      [for (final s in samples) s.outcome],
    );
    if (!res.hasRoc && !res.hasPr) {
      _paintUnavailable(
        canvas,
        size,
        samples.isEmpty ? strings.rocPrMissingData : strings.rocPrSingleClass,
      );
      return;
    }
    final plot = Rect.fromLTWH(38, 22, size.width - 54, size.height - 46);
    _paintAxes(canvas, plot);
    Offset toPx(Offset norm) => Offset(
      plot.left + norm.dx.clamp(0.0, 1.0) * plot.width,
      plot.bottom - norm.dy.clamp(0.0, 1.0) * plot.height,
    );

    if (res.hasRoc) {
      canvas.drawLine(
        plot.bottomLeft,
        plot.topRight,
        Paint()
          ..color = palette.textMuted.withValues(alpha: 0.4)
          ..strokeWidth = 1.0,
      );
      final rocPath = Path()
        ..moveTo(toPx(res.rocPoints.first).dx, toPx(res.rocPoints.first).dy);
      for (var i = 1; i < res.rocPoints.length; i++) {
        final p = toPx(res.rocPoints[i]);
        rocPath.lineTo(p.dx, p.dy);
      }
      final fill = Path.from(rocPath)
        ..lineTo(plot.right, plot.bottom)
        ..lineTo(plot.left, plot.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = palette.accent.withValues(alpha: 0.14),
      );
      canvas.drawPath(
        rocPath,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    if (res.hasPr) {
      final prPath = Path()
        ..moveTo(toPx(res.prPoints.first).dx, toPx(res.prPoints.first).dy);
      for (var i = 1; i < res.prPoints.length; i++) {
        final p = toPx(res.prPoints[i]);
        prPath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        prPath,
        Paint()
          ..color = palette.seriesAt(1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    _drawText(
      canvas,
      numberText(0, 1, language: numberLanguage),
      Offset(6, plot.bottom - 6),
      maxWidth: 28,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(1, 1, language: numberLanguage),
      Offset(6, plot.top - 4),
      maxWidth: 28,
      color: palette.textMuted,
    );
    final headerText = res.hasRoc
        ? 'ROC AUC ${numberText(res.rocAuc!, 2, language: numberLanguage)} | PR AUC ${numberText(res.prAuc!, 2, language: numberLanguage)}'
        : strings.rocSingleClassBanner(
            numberText(res.prAuc!, 2, language: numberLanguage),
          );
    _drawText(
      canvas,
      headerText,
      Offset(plot.left, 4),
      maxWidth: plot.width,
      fontSize: 9.5,
      color: palette.textPrimary,
    );
    _drawText(
      canvas,
      res.hasRoc ? 'FPR / Recall' : 'Recall',
      Offset(plot.left + plot.width * 0.38, plot.bottom + 6),
      maxWidth: 110,
      fontSize: 9,
      color: palette.textMuted,
    );
  }

  void _paintConfusionMatrix(Canvas canvas, Size size) {
    final cm = ScienceAiChart.computeConfusionMatrix(
      rows,
      dimension,
      primary,
      secondary,
      numberLanguage: numberLanguage,
    );
    if (cm.total == 0 || cm.labels.isEmpty) {
      _paintUnavailable(canvas, size, strings.confusionMatrixUnavailable);
      return;
    }
    final n = math.max(1, cm.labels.length);
    final plot = Rect.fromLTWH(52, 22, size.width - 68, size.height - 38);
    final cellW = plot.width / n;
    final cellH = plot.height / n;
    var maxV = 1;
    for (final row in cm.counts) {
      for (final v in row) {
        if (v > maxV) maxV = v;
      }
    }

    _drawText(
      canvas,
      'Predicted',
      Offset(plot.center.dx - 24, 4),
      maxWidth: 80,
      fontSize: 9,
      color: palette.textMuted,
    );
    for (var c = 0; c < n; c++) {
      _drawText(
        canvas,
        cm.labels[c],
        Offset(plot.left + (c + 0.5) * cellW, plot.top - 8),
        maxWidth: cellW,
        fontSize: 8.5,
        center: true,
        color: palette.textMuted,
      );
    }
    for (var r = 0; r < n; r++) {
      _drawText(
        canvas,
        cm.labels[r],
        Offset(6, plot.top + (r + 0.5) * cellH - 6),
        maxWidth: 42,
        fontSize: 8.5,
        color: palette.textMuted,
      );
      for (var c = 0; c < n; c++) {
        final val = cm.counts[r][c];
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
          '$val',
          rect.center,
          maxWidth: cellW - 8,
          center: true,
        );
      }
    }
  }

  void _paintLearningCurve(Canvas canvas, Size size) {
    final seriesList = [primary, ?secondary];
    final allVals = [for (final f in seriesList) ..._validValues(f)];
    if (allVals.isEmpty) {
      _paintUnavailable(canvas, size, strings.noValidLearningCurveSamples);
      return;
    }
    final plot = Rect.fromLTWH(38, 18, size.width - 54, size.height - 40);
    _paintAxes(canvas, plot);
    final minV = allVals.fold<double>(double.infinity, math.min);
    final maxV = allVals.fold<double>(-double.infinity, math.max);
    final span = math.max(1e-6, maxV - minV);

    for (var s = 0; s < seriesList.length; s++) {
      final f = seriesList[s];
      final path = Path();
      var segmentOpen = false;
      for (var i = 0; i < rows.length; i++) {
        final val = measureValue(rows[i][f.name], f);
        if (val == null || !val.isFinite) {
          segmentOpen = false;
          continue;
        }
        final x = rows.length == 1
            ? plot.center.dx
            : plot.left + (i / (rows.length - 1)) * plot.width;
        final y = plot.bottom - ((val - minV) / span) * plot.height;
        if (!segmentOpen) {
          path.moveTo(x, y);
          segmentOpen = true;
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
      _drawText(
        canvas,
        seriesList[s].label,
        Offset(plot.left + s * 86, 4),
        maxWidth: 82,
        fontSize: 9,
        color: palette.seriesAt(s),
      );
    }
    _drawText(
      canvas,
      numberText(minV, 2, language: numberLanguage),
      Offset(4, plot.bottom - 6),
      maxWidth: 32,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(maxV, 2, language: numberLanguage),
      Offset(4, plot.top - 4),
      maxWidth: 32,
      color: palette.textMuted,
    );
  }

  void _paintIrt(Canvas canvas, Size size, {required bool infoCurve}) {
    final diffs = <double>[];
    final discs = secondary != null ? <double>[] : null;
    final lbls = <String>[];
    for (var i = 0; i < rows.length && diffs.length < 5; i++) {
      final b = measureValue(rows[i][primary.name], primary);
      if (b == null || !b.isFinite) continue;
      if (secondary != null) {
        final a = measureValue(rows[i][secondary!.name], secondary!);
        if (a == null || !a.isFinite) continue;
        discs!.add(a);
      }
      diffs.add(b);
      lbls.add(_label(i));
    }
    if (diffs.isEmpty) {
      _paintUnavailable(canvas, size, strings.noValidIrtItemParameters);
      return;
    }
    final plot = Rect.fromLTWH(38, 18, size.width - 54, size.height - 40);
    _paintAxes(canvas, plot);
    final thetaMin = math.min(-3.0, diffs.reduce(math.min) - 1.5);
    final thetaMax = math.max(3.0, diffs.reduce(math.max) + 1.5);
    final thetaSpan = math.max(1e-6, thetaMax - thetaMin);
    final curves = ScienceAiChart.computeIrtCurves(
      diffs,
      discs,
      lbls,
      infoCurve: infoCurve,
      thetaMin: thetaMin,
      thetaMax: thetaMax,
    );
    final maxY = infoCurve
        ? curves
              .expand((c) => c.points)
              .map((pt) => pt.dy)
              .fold<double>(0.25, math.max)
        : 1.0;

    for (var idx = 0; idx < curves.length; idx++) {
      final pts = curves[idx].points;
      final path = Path();
      for (var s = 0; s < pts.length; s++) {
        final x = plot.left + ((pts[s].dx - thetaMin) / thetaSpan) * plot.width;
        final y =
            plot.bottom - (pts[s].dy / maxY).clamp(0.0, 1.0) * plot.height;
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
    _drawText(
      canvas,
      numberText(thetaMin, 0, language: numberLanguage),
      Offset(plot.left - 4, plot.bottom + 4),
      maxWidth: 32,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(thetaMax, 0, language: numberLanguage),
      Offset(plot.right - 20, plot.bottom + 4),
      maxWidth: 32,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(maxY, 1, language: numberLanguage),
      Offset(4, plot.top - 4),
      maxWidth: 30,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(0, 1, language: numberLanguage),
      Offset(4, plot.bottom - 6),
      maxWidth: 30,
      color: palette.textMuted,
    );
  }

  void _paintWrightMap(Canvas canvas, Size size) {
    final persons = _validValues(primary);
    final items = <double>[];
    final lbls = <String>[];
    final itemField = secondary ?? primary;
    for (var i = 0; i < rows.length; i++) {
      final b = measureValue(rows[i][itemField.name], itemField);
      if (b == null || !b.isFinite) continue;
      items.add(b);
      lbls.add(_label(i));
    }
    if (persons.isEmpty && items.isEmpty) {
      _paintUnavailable(canvas, size, strings.noValidWrightMapLogits);
      return;
    }
    final data = ScienceAiChart.computeWrightMap(persons, items, lbls);

    final cx = size.width * 0.48;
    const top = 24.0;
    final bottom = size.height - 20.0;
    final span = math.max(1e-6, data.maxLogit - data.minLogit);
    double yForLogit(double l) =>
        bottom - ((l - data.minLogit) / span).clamp(0.0, 1.0) * (bottom - top);

    _drawText(
      canvas,
      'Persons',
      Offset(12, 4),
      maxWidth: cx - 20,
      fontSize: 9.5,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      'Logit',
      Offset(cx - 12, 4),
      maxWidth: 36,
      fontSize: 9.5,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      'Items',
      Offset(cx + 18, 4),
      maxWidth: size.width - cx - 24,
      fontSize: 9.5,
      color: palette.textMuted,
    );

    canvas.drawLine(
      Offset(cx, top),
      Offset(cx, bottom),
      Paint()
        ..color = palette.border
        ..strokeWidth = 1.4,
    );

    final maxBinCount = data.personBins
        .map((b) => b.count)
        .fold<int>(1, math.max);
    final barH = math.max(6.0, ((bottom - top) / data.personBins.length) - 3.0);
    final maxLeftW = math.max(24.0, cx - 28.0);
    for (final bin in data.personBins) {
      if (bin.count == 0) continue;
      final y = yForLogit(bin.midLogit);
      final bw = (bin.count / maxBinCount) * maxLeftW;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 6 - bw, y - barH / 2, bw, barH),
          const Radius.circular(2),
        ),
        Paint()..color = palette.accent.withValues(alpha: 0.7),
      );
    }

    for (var i = 0; i < data.items.length; i++) {
      final item = data.items[i];
      final y = yForLogit(item.difficulty);
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx + 10, y),
        Paint()
          ..color = palette.seriesAt(i)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        Offset(cx + 12, y),
        3.2,
        Paint()..color = palette.seriesAt(i),
      );
      _drawText(
        canvas,
        '${item.label} (${numberText(item.difficulty, 1, language: numberLanguage)})',
        Offset(cx + 18, y - 6),
        maxWidth: math.max(40.0, size.width - cx - 22),
      );
    }
  }

  void _paintDiffDiscScatter(Canvas canvas, Size size) {
    final pts = <({double v1, double v2, String label})>[];
    for (var i = 0; i < rows.length; i++) {
      final b = measureValue(rows[i][primary.name], primary);
      if (b == null || !b.isFinite) continue;
      var a = 1.0;
      if (secondary != null) {
        final rawA = measureValue(rows[i][secondary!.name], secondary!);
        if (rawA == null || !rawA.isFinite) continue;
        a = rawA;
      }
      pts.add((v1: b, v2: a, label: _label(i)));
    }
    if (pts.isEmpty) {
      _paintUnavailable(canvas, size, strings.noValidItemDifficultyPairs);
      return;
    }
    final plot = Rect.fromLTWH(38, 18, size.width - 54, size.height - 40);
    _paintAxes(canvas, plot);
    final min1 = math.min(-2.5, [for (final p in pts) p.v1].reduce(math.min));
    final max1 = math.max(2.5, [for (final p in pts) p.v1].reduce(math.max));
    final span1 = math.max(1e-6, max1 - min1);
    final min2 = math.min(0.0, [for (final p in pts) p.v2].reduce(math.min));
    final span2 = math.max(
      1e-6,
      math.max(2.5, [for (final p in pts) p.v2].reduce(math.max)) - min2,
    );

    final zeroX = plot.left + ((0.0 - min1) / span1) * (plot.width - 16) + 8;
    canvas.drawLine(
      Offset(zeroX, plot.top),
      Offset(zeroX, plot.bottom),
      Paint()..color = palette.border.withValues(alpha: 0.65),
    );
    canvas.drawLine(
      Offset(plot.left, plot.center.dy),
      Offset(plot.right, plot.center.dy),
      Paint()..color = palette.border.withValues(alpha: 0.65),
    );

    for (var i = 0; i < pts.length; i++) {
      final x =
          plot.left + ((pts[i].v1 - min1) / span1) * (plot.width - 16) + 8;
      final y =
          plot.bottom - ((pts[i].v2 - min2) / span2) * (plot.height - 16) - 8;
      canvas.drawCircle(
        Offset(x, y),
        4.8,
        Paint()..color = palette.seriesAt(i),
      );
      _drawText(
        canvas,
        pts[i].label,
        Offset(x + 6, y - 6),
        maxWidth: 68,
        fontSize: 8.5,
      );
    }
    _drawText(
      canvas,
      'b=${numberText(min1, 1, language: numberLanguage)}',
      Offset(plot.left, plot.bottom + 4),
      maxWidth: 44,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      'b=${numberText(max1, 1, language: numberLanguage)}',
      Offset(plot.right - 40, plot.bottom + 4),
      maxWidth: 44,
      color: palette.textMuted,
    );
  }

  void _paintKaplanMeier(Canvas canvas, Size size) {
    final samples = ScienceAiChart.extractPairedBinarySamples(
      rows,
      dimension,
      primary,
      secondary,
    );
    if (samples.isEmpty) {
      _paintUnavailable(canvas, size, strings.kaplanMeierUnavailable);
      return;
    }
    final plot = Rect.fromLTWH(38, 18, size.width - 54, size.height - 40);
    _paintAxes(canvas, plot);
    final curve = ScienceAiChart.computeKaplanMeier(
      [for (final s in samples) s.value],
      [for (final s in samples) s.outcome],
    );
    final maxT = curve.map((c) => c.time).fold<double>(1e-6, math.max);

    final path = Path();
    Offset? prev;
    for (final step in curve) {
      final x = plot.left + (step.time / maxT).clamp(0.0, 1.0) * plot.width;
      final y = plot.bottom - step.survival.clamp(0.0, 1.0) * plot.height;
      if (prev == null) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, prev.dy);
        path.lineTo(x, y);
      }
      if (step.censored) {
        canvas.drawLine(
          Offset(x, y - 3.5),
          Offset(x, y + 3.5),
          Paint()
            ..color = palette.seriesAt(1)
            ..strokeWidth = 1.6,
        );
      }
      prev = Offset(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    _drawText(
      canvas,
      numberText(1, 1, language: numberLanguage),
      Offset(6, plot.top - 4),
      maxWidth: 28,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      numberText(0, 1, language: numberLanguage),
      Offset(6, plot.bottom - 6),
      maxWidth: 28,
      color: palette.textMuted,
    );
    _drawText(
      canvas,
      't=${numberText(maxT, 0, language: numberLanguage)}',
      Offset(plot.right - 36, plot.bottom + 4),
      maxWidth: 40,
      color: palette.textMuted,
    );
  }

  @override
  bool shouldRepaint(covariant _ScienceAiPainter old) =>
      old.visual != visual ||
      old.rows != rows ||
      old.palette != palette ||
      old.numberLanguage != numberLanguage ||
      old.strings.localeTag != strings.localeTag;
}
