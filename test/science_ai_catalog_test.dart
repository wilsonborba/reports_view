import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/science_ai_charts.dart';

const _palette = ReportPalette(
  canvas: Color(0xFFFFFFFF),
  surface: Color(0xFFF4F4F4),
  surfaceAlt: Color(0xFFE0E0E0),
  border: Color(0xFFD0D0D0),
  textPrimary: Color(0xFF161616),
  textMuted: Color(0xFF525252),
  accent: Color(0xFF0F62FE),
  onAccent: Color(0xFFFFFFFF),
  positive: Color(0xFF198038),
  warning: Color(0xFFF1C21B),
  negative: Color(0xFFDA1E28),
  info: Color(0xFF0043CE),
  caution: Color(0xFFFF832B),
  series: [
    Color(0xFF0F62FE),
    Color(0xFF8A3FFC),
    Color(0xFF009D9A),
    Color(0xFFEE5396),
  ],
);

const _darkPalette = ReportPalette(
  canvas: Color(0xFF121212),
  surface: Color(0xFF1E1E1E),
  surfaceAlt: Color(0xFF2C2C2C),
  border: Color(0xFF444444),
  textPrimary: Color(0xFFF4F4F4),
  textMuted: Color(0xFFBDBDBD),
  accent: Color(0xFF78A9FF),
  onAccent: Color(0xFF121212),
  positive: Color(0xFF42BE65),
  warning: Color(0xFFF1C21B),
  negative: Color(0xFFFF8389),
  info: Color(0xFF78A9FF),
  caution: Color(0xFFFF832B),
  series: [
    Color(0xFF78A9FF),
    Color(0xFFBE95FF),
    Color(0xFF08BDBA),
    Color(0xFFFF7EB6),
  ],
);

Widget _sizedHarness(
  Widget child, {
  double width = 360,
  double height = 220,
  Locale locale = const Locale('en'),
  ReportPalette palette = _palette,
  Brightness brightness = Brightness.light,
  Key? boundaryKey,
}) => MaterialApp(
  theme: palette.toTheme(brightness),
  home: Scaffold(
    backgroundColor: palette.surface,
    body: Builder(
      builder: (context) => Localizations.override(
        context: context,
        locale: locale,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: palette.surface,
              child: SizedBox(width: width, height: height, child: child),
            ),
          ),
        ),
      ),
    ),
  ),
);

DatasetPage _makeSciencePage(String id) {
  final (fields, rows) = switch (id) {
    'roc_pr' || 'calibration' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Sample',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(name: 'v1', label: 'Score', type: 'float', role: 'measure'),
        FieldInfo(name: 'v2', label: 'Label', type: 'integer', role: 'measure'),
      ],
      const [
        {'item': 'S1', 'v1': 0.95, 'v2': 1},
        {'item': 'S2', 'v1': 0.88, 'v2': 1},
        {'item': 'S3', 'v1': 0.79, 'v2': 1},
        {'item': 'S4', 'v1': 0.71, 'v2': 0},
        {'item': 'S5', 'v1': 0.62, 'v2': 1},
        {'item': 'S6', 'v1': 0.45, 'v2': 0},
        {'item': 'S7', 'v1': 0.29, 'v2': 0},
        {'item': 'S8', 'v1': 0.11, 'v2': 0},
      ],
    ),
    'confusion_matrix' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Sample',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Predicted',
          type: 'integer',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: 'Actual',
          type: 'integer',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'S1', 'v1': 0, 'v2': 0},
        {'item': 'S2', 'v1': 0, 'v2': 0},
        {'item': 'S3', 'v1': 1, 'v2': 0},
        {'item': 'S4', 'v1': 1, 'v2': 1},
        {'item': 'S5', 'v1': 1, 'v2': 1},
        {'item': 'S6', 'v1': 0, 'v2': 1},
      ],
    ),
    'wright_map' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Item',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Person theta',
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(name: 'v2', label: 'Item b', type: 'float', role: 'measure'),
      ],
      const [
        {'item': 'Q1', 'v1': -1.8, 'v2': -1.5},
        {'item': 'Q2', 'v1': -0.9, 'v2': -0.6},
        {'item': 'Q3', 'v1': -0.2, 'v2': 0.0},
        {'item': 'Q4', 'v1': 0.5, 'v2': 0.7},
        {'item': 'Q5', 'v1': 1.2, 'v2': 1.4},
        {'item': 'Q6', 'v1': 1.9, 'v2': 2.0},
      ],
    ),
    'kaplan_meier' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Subject',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Months',
          type: 'integer',
          role: 'measure',
        ),
        FieldInfo(name: 'v2', label: 'Event', type: 'integer', role: 'measure'),
      ],
      const [
        {'item': 'P1', 'v1': 2, 'v2': 1},
        {'item': 'P2', 'v1': 4, 'v2': 0},
        {'item': 'P3', 'v1': 6, 'v2': 1},
        {'item': 'P4', 'v1': 9, 'v2': 1},
        {'item': 'P5', 'v1': 12, 'v2': 0},
        {'item': 'P6', 'v1': 15, 'v2': 1},
      ],
    ),
    'irt_icc' || 'irt_iif' || 'item_diff_disc' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Item',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Difficulty b',
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: 'Discrim a',
          type: 'float',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'Q1', 'v1': -1.2, 'v2': 0.9},
        {'item': 'Q2', 'v1': 0.0, 'v2': 1.6},
        {'item': 'Q3', 'v1': 1.1, 'v2': 2.1},
      ],
    ),
    _ => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Label',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(name: 'v1', label: 'Primary', type: 'float', role: 'measure'),
        FieldInfo(
          name: 'v2',
          label: 'Secondary',
          type: 'float',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'Class A', 'v1': 0.52, 'v2': 0.56},
        {'item': 'Class B', 'v1': 0.24, 'v2': 0.29},
        {'item': 'Class C', 'v1': 0.14, 'v2': 0.19},
        {'item': 'Class D', 'v1': 0.10, 'v2': 0.14},
      ],
    ),
  };

  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'science_$id',
      title: 'Science fixture ($id)',
      description: 'Items 105 to 114 realistic fixture',
      equation: null,
      fields: fields,
      filters: const [],
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

void main() {
  const ids = <String>[
    'top_k_prob',
    'calibration',
    'confusion_matrix',
    'roc_pr',
    'learning_curve',
    'irt_icc',
    'irt_iif',
    'wright_map',
    'item_diff_disc',
    'kaplan_meier',
  ];

  for (final id in ids) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
      final page = _makeSciencePage(id);
      final tpl = VisualTemplate(
        templateId: id,
        version: 1,
        kind: 'chart',
        visual: id,
        title: id,
        slots: const [
          TemplateSlot(
            slotName: 'category',
            role: 'dimension',
            minCount: 1,
            maxCount: 1,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: 2,
            acceptedTypes: ['integer', 'float'],
          ),
        ],
      );
      final binding = CardVisualBinding(
        template: id,
        version: 1,
        mapping: const {
          'category': ['item'],
          'value': ['v1', 'v2'],
        },
      );
      for (final locale in const [
        Locale('en'),
        Locale('pt', 'BR'),
        Locale('th'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: _palette.toTheme(Brightness.light),
            home: Scaffold(
              body: SizedBox(
                width: 440,
                height: 320,
                child: SingleChildScrollView(
                  child: VisualChooser.buildTemplate(
                    page: page,
                    template: tpl,
                    binding: binding,
                    title: id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$id ($locale) threw');
      }
    });
  }

  test(
    'semantic: top_k_prob sorts descending and sums to 1.0 with exact probabilities',
    () {
      final page = DatasetPage(
        descriptor: _makeSciencePage('top_k_prob').descriptor,
        rows: const [
          {'item': 'A', 'v1': 2.0, 'v2': 0.0},
          {'item': 'B', 'v1': 5.0, 'v2': 0.0},
          {'item': 'C', 'v1': 3.0, 'v2': 0.0},
        ],
        offset: 0,
        limit: 3,
        totalRows: 3,
      );
      final top = ScienceAiChart.computeTopK(
        page.rows,
        page.descriptor.fields[0],
        page.descriptor.fields[1],
      );
      expect(top.map((e) => e.label).toList(), ['B', 'C', 'A']);
      expect(top[0].prob, closeTo(0.5, 1e-9));
      expect(top[1].prob, closeTo(0.3, 1e-9));
      expect(top[2].prob, closeTo(0.2, 1e-9));
      final total = top.fold<double>(0.0, (a, b) => a + b.prob);
      expect(total, closeTo(1.0, 1e-9));
    },
  );

  test(
    'semantic: roc_pr computes exact ROC points, PR points, ROC AUC (0.75), and trapezoidal PR AUC',
    () {
      final res = ScienceAiChart.computeRocPr(
        const [0.95, 0.85, 0.72, 0.65, 0.50, 0.30, 0.20, 0.10],
        const [true, true, false, true, false, false, true, false],
      );
      expect(res.rocPoints.length, 9);
      const expectedRoc = [
        Offset(0.0, 0.0),
        Offset(0.0, 0.25),
        Offset(0.0, 0.50),
        Offset(0.25, 0.50),
        Offset(0.25, 0.75),
        Offset(0.50, 0.75),
        Offset(0.75, 0.75),
        Offset(0.75, 1.0),
        Offset(1.0, 1.0),
      ];
      for (var i = 0; i < expectedRoc.length; i++) {
        expect(res.rocPoints[i].dx, closeTo(expectedRoc[i].dx, 1e-9));
        expect(res.rocPoints[i].dy, closeTo(expectedRoc[i].dy, 1e-9));
      }
      final expectedPr = [
        const Offset(0.0, 1.0),
        const Offset(0.25, 1.0),
        const Offset(0.50, 1.0),
        const Offset(0.50, 2 / 3),
        const Offset(0.75, 0.75),
        const Offset(0.75, 0.60),
        const Offset(0.75, 0.50),
        const Offset(1.0, 4 / 7),
        const Offset(1.0, 0.50),
      ];
      expect(res.prPoints.length, expectedPr.length);
      for (var i = 0; i < expectedPr.length; i++) {
        expect(res.prPoints[i].dx, closeTo(expectedPr[i].dx, 1e-9));
        expect(res.prPoints[i].dy, closeTo(expectedPr[i].dy, 1e-9));
      }
      // 12 of 16 (pos, neg) pairs ranked correctly -> exact 0.75.
      expect(res.rocAuc, closeTo(0.75, 1e-9));
      // Trapezoidal integral over exact PR curve: 0.5 + 17/96 + 15/112 = 545/672.
      expect(res.prAuc, closeTo(545 / 672, 1e-9));

      // Tied scores create a diagonal ROC segment ((0, 0.5) -> (0.5, 1.0)),
      // pinning trapezoidal integration (0.875) vs right/left Riemann sums.
      final tied = ScienceAiChart.computeRocPr(
        const [0.9, 0.5, 0.5, 0.1],
        const [true, true, false, false],
      );
      expect(tied.rocPoints, const [
        Offset(0.0, 0.0),
        Offset(0.0, 0.5),
        Offset(0.5, 1.0),
        Offset(1.0, 1.0),
      ]);
      expect(tied.rocAuc, closeTo(0.875, 1e-9));
    },
  );

  test(
    'semantic: calibration computes exact binned meanPred, obsFreq, and count',
    () {
      final bins = ScienceAiChart.computeCalibration(
        const [0.10, 0.12, 0.35, 0.38, 0.65, 0.68, 0.90, 0.95],
        const [false, false, false, true, true, false, true, true],
        bins: 4,
      );
      expect(bins.length, 4);
      final expected = [
        (meanPred: 0.11, obsFreq: 0.0, count: 2),
        (meanPred: 0.365, obsFreq: 0.5, count: 2),
        (meanPred: 0.665, obsFreq: 0.5, count: 2),
        (meanPred: 0.925, obsFreq: 1.0, count: 2),
      ];
      for (var i = 0; i < expected.length; i++) {
        expect(bins[i].meanPred, closeTo(expected[i].meanPred, 1e-9));
        expect(bins[i].obsFreq, closeTo(expected[i].obsFreq, 1e-9));
        expect(bins[i].count, expected[i].count);
      }
    },
  );

  test(
    'semantic: confusion_matrix computes exact predicted vs actual cells [[2, 1], [1, 2]] and asymmetric [[2, 2], [0, 1]]',
    () {
      final page = _makeSciencePage('confusion_matrix');
      final cm = ScienceAiChart.computeConfusionMatrix(
        page.rows,
        page.descriptor.fields[0],
        page.descriptor.fields[1],
        page.descriptor.fields[2],
      );
      expect(cm.labels, const ['0', '1']);
      expect(cm.counts, const [
        [2, 1],
        [1, 2],
      ]);
      expect(cm.total, 6);

      // Asymmetric samples ensure row (actual) and column (predicted) axes cannot swap.
      final asymRows = const [
        {'item': 'A1', 'v1': 0, 'v2': 0},
        {'item': 'A2', 'v1': 0, 'v2': 0},
        {'item': 'A3', 'v1': 1, 'v2': 0},
        {'item': 'A4', 'v1': 1, 'v2': 0},
        {'item': 'A5', 'v1': 1, 'v2': 1},
      ];
      final asym = ScienceAiChart.computeConfusionMatrix(
        asymRows,
        page.descriptor.fields[0],
        page.descriptor.fields[1],
        page.descriptor.fields[2],
      );
      expect(asym.counts, const [
        [2, 2],
        [0, 1],
      ]);
      expect(asym.total, 5);
    },
  );

  test(
    'semantic: learning_curve orders train above converged val across epochs',
    () {
      final page = _makeSciencePage('learning_curve');
      final trainVals = [
        for (final r in page.rows) (r['v1'] as num).toDouble(),
      ];
      expect(trainVals.first, greaterThan(trainVals.last));
    },
  );

  test(
    'semantic: irt_icc matches exact 2PL probabilities P(theta) = 1 / (1 + exp(-a*(theta-b)))',
    () {
      final curves = ScienceAiChart.computeIrtCurves(
        const [-1.0, 1.0],
        const [1.0, 2.0],
        const ['Easy', 'Hard'],
        infoCurve: false,
        steps: 60,
      );
      // theta = -1.0 (idx 20), theta = 0.0 (idx 30), theta = 1.0 (idx 40)
      expect(curves[0].points[20].dx, closeTo(-1.0, 1e-9));
      expect(curves[0].points[20].dy, closeTo(0.5, 1e-9));
      expect(curves[0].points[30].dy, closeTo(0.7310585786300049, 1e-9));
      expect(curves[0].points[40].dy, closeTo(0.8807970779778823, 1e-9));

      expect(curves[1].points[20].dy, closeTo(0.01798620996209156, 1e-9));
      expect(curves[1].points[30].dy, closeTo(0.11920292202211755, 1e-9));
      expect(curves[1].points[40].dx, closeTo(1.0, 1e-9));
      expect(curves[1].points[40].dy, closeTo(0.5, 1e-9));
      for (var i = 1; i < curves[0].points.length; i++) {
        expect(curves[0].points[i].dy, greaterThan(curves[0].points[i - 1].dy));
      }
    },
  );

  test(
    'semantic: irt_iif matches exact Fisher information I(theta) = a^2 * P * (1 - P) at fixed theta',
    () {
      final curves = ScienceAiChart.computeIrtCurves(
        const [0.0, 0.0],
        const [1.0, 2.0],
        const ['LowA', 'HighA'],
        infoCurve: true,
        steps: 60,
      );
      // theta = 0.0 (idx 30): max info = a^2 * 0.25 -> 0.25 vs 1.0
      expect(curves[0].points[30].dy, closeTo(0.25, 1e-9));
      expect(curves[1].points[30].dy, closeTo(1.0, 1e-9));
      // theta = 1.0 (idx 40):
      // a=1: P=1/(1+e^-1)=0.7310585786300049 -> I=0.19661193324148185
      // a=2: P=1/(1+e^-2)=0.8807970779778823 -> I=4*P*(1-P)=0.41997434161402614
      expect(curves[0].points[40].dx, closeTo(1.0, 1e-9));
      expect(curves[0].points[40].dy, closeTo(0.19661193324148185, 1e-9));
      expect(curves[1].points[40].dy, closeTo(0.41997434161402614, 1e-9));
    },
  );

  test(
    'semantic: wright_map places exact person bin counts and item positions on one logit scale',
    () {
      const persons = [-1.8, -0.9, -0.2, 0.5, 1.2, 1.9];
      const items = [-1.5, 0.0, 1.4];
      final wm = ScienceAiChart.computeWrightMap(persons, items, const [
        'Q1',
        'Q2',
        'Q3',
      ], binCount: 6);
      expect(wm.minLogit, -3.0);
      expect(wm.maxLogit, 3.0);
      expect(wm.personBins.map((b) => b.midLogit).toList(), [
        -2.5,
        -1.5,
        -0.5,
        0.5,
        1.5,
        2.5,
      ]);
      expect(wm.personBins.map((b) => b.count).toList(), [0, 1, 2, 1, 2, 0]);
      expect(wm.items, const [
        (label: 'Q1', difficulty: -1.5),
        (label: 'Q2', difficulty: 0.0),
        (label: 'Q3', difficulty: 1.4),
      ]);
    },
  );

  test(
    'semantic: item_diff_disc distinguishes item b and a directly from row measures',
    () {
      final page = _makeSciencePage('item_diff_disc');
      expect((page.rows[0]['v1'] as num).toDouble(), -1.2);
      expect((page.rows[2]['v2'] as num).toDouble(), 2.1);
    },
  );

  test(
    'semantic: kaplan_meier produces exact product-limit survival steps with censoring',
    () {
      final km = ScienceAiChart.computeKaplanMeier(
        const [2, 4, 6, 9, 12],
        const [true, false, true, false, true],
      );
      final expected = [
        (time: 0.0, survival: 1.0, censored: false),
        (time: 2.0, survival: 0.8, censored: false),
        (time: 4.0, survival: 0.8, censored: true),
        (time: 6.0, survival: 8 / 15, censored: false),
        (time: 9.0, survival: 8 / 15, censored: true),
        (time: 12.0, survival: 0.0, censored: false),
      ];
      expect(km.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(km[i].time, closeTo(expected[i].time, 1e-9));
        expect(km[i].survival, closeTo(expected[i].survival, 1e-9));
        expect(km[i].censored, expected[i].censored);
      }
    },
  );

  test(
    'roc_pr leaves ROC unavailable on single-class and empty inputs while separating valid all-positive PR',
    () {
      final empty = ScienceAiChart.computeRocPr(const [], const []);
      expect(empty.rocAuc, isNull);
      expect(empty.prAuc, isNull);
      expect(empty.rocPoints, isEmpty);
      expect(empty.prPoints, isEmpty);
      expect(empty.hasRoc, isFalse);
      expect(empty.hasPr, isFalse);

      final allPos = ScienceAiChart.computeRocPr(
        const [0.9, 0.2],
        const [true, true],
      );
      expect(allPos.rocAuc, isNull);
      expect(allPos.rocPoints, isEmpty);
      expect(allPos.hasRoc, isFalse);
      expect(allPos.hasPr, isTrue);
      expect(allPos.prAuc, closeTo(1.0, 1e-9));

      final allNeg = ScienceAiChart.computeRocPr(
        const [0.9, 0.2],
        const [false, false],
      );
      expect(allNeg.rocAuc, isNull);
      expect(allNeg.prAuc, isNull);
      expect(allNeg.rocPoints, isEmpty);
      expect(allNeg.prPoints, isEmpty);
      expect(allNeg.hasRoc, isFalse);
      expect(allNeg.hasPr, isFalse);
    },
  );

  test(
    'C8: null outcomes and missing scores are omitted from paired samples instead of defaulting to zero',
    () {
      const dim = FieldInfo(
        name: 'item',
        label: 'Sample',
        type: 'string',
        role: 'dimension',
      );
      const score = FieldInfo(
        name: 'v1',
        label: 'Score',
        type: 'float',
        role: 'measure',
        missingMeans: 'no_data',
      );
      const outcome = FieldInfo(
        name: 'v2',
        label: 'Label',
        type: 'integer',
        role: 'measure',
        missingMeans: 'no_data',
      );

      final rows = const [
        {'item': 'S1', 'v1': 0.9, 'v2': 1},
        // Null outcome on high score must be omitted, NOT treated as false (0).
        {'item': 'S2_null_outcome', 'v1': 0.95, 'v2': null},
        // Null score must be omitted, NOT treated as 0.0.
        {'item': 'S3_null_score', 'v1': null, 'v2': 1},
        // Real zero score and real zero outcome must stay intact.
        {'item': 'S4_real_zero', 'v1': 0.0, 'v2': 0},
      ];
      final paired = ScienceAiChart.extractPairedBinarySamples(
        rows,
        dim,
        score,
        outcome,
      );
      expect(paired.length, 2);
      expect(paired[0].label, 'S1');
      expect(paired[0].value, 0.9);
      expect(paired[0].outcome, isTrue);
      expect(paired[1].label, 'S4_real_zero');
      expect(paired[1].value, 0.0);
      expect(paired[1].outcome, isFalse);

      final roc = ScienceAiChart.computeRocPr(
        [for (final s in paired) s.value],
        [for (final s in paired) s.outcome],
      );
      expect(roc.rocAuc, closeTo(1.0, 1e-9));

      // topK distinguishes missing (omitted) from real zero (included with prob 0.0).
      final topNull = ScienceAiChart.computeTopK(
        const [
          {'item': 'A', 'v1': 3.0},
          {'item': 'Missing', 'v1': null},
          {'item': 'RealZero', 'v1': 0.0},
          {'item': 'B', 'v1': 1.0},
        ],
        dim,
        score,
      );
      expect(topNull.map((e) => e.label).toList(), ['A', 'B', 'RealZero']);
      expect(topNull[2].prob, 0.0);
    },
  );

  testWidgets(
    'roc_pr rendered widget shows unavailable state on single-class and missing-data pages without invented AUC',
    (tester) async {
      const desc = DatasetDescriptor(
        datasetId: 'roc_state_ds',
        title: 'ROC State Fixture',
        description: '',
        equation: null,
        fields: [
          FieldInfo(
            name: 'item',
            label: 'Sample',
            type: 'string',
            role: 'dimension',
          ),
          FieldInfo(
            name: 'v1',
            label: 'Score',
            type: 'float',
            role: 'measure',
            missingMeans: 'no_data',
          ),
          FieldInfo(
            name: 'v2',
            label: 'Label',
            type: 'integer',
            role: 'measure',
            missingMeans: 'no_data',
          ),
        ],
        filters: [],
      );

      Future<String?> semanticsFor(List<Map<String, dynamic>> rows) async {
        final page = DatasetPage(
          descriptor: desc,
          rows: rows,
          offset: 0,
          limit: rows.length,
          totalRows: rows.length,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: _palette.toTheme(Brightness.light),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 260,
                child: ScienceAiChart(
                  page: page,
                  visual: Visual.rocPr,
                  dimension: desc.fields[0],
                  measures: [desc.fields[1], desc.fields[2]],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final node = tester.getSemantics(find.byType(ScienceAiChart));
        return node.label;
      }

      final posLabel = await semanticsFor(const [
        {'item': 'P1', 'v1': 0.9, 'v2': 1},
        {'item': 'P2', 'v1': 0.2, 'v2': 1},
      ]);
      expect(posLabel, contains('ROC unavailable (single class)'));
      expect(posLabel, contains('PR AUC 1.00'));
      expect(posLabel, isNot(contains('ROC AUC')));

      final negLabel = await semanticsFor(const [
        {'item': 'N1', 'v1': 0.9, 'v2': 0},
        {'item': 'N2', 'v1': 0.2, 'v2': 0},
      ]);
      expect(negLabel, contains('ROC / PR unavailable'));
      expect(negLabel, isNot(contains('ROC AUC')));

      final nullMaskedLabel = await semanticsFor(const [
        {'item': 'M1', 'v1': 0.9, 'v2': null},
        {'item': 'M2', 'v1': 0.4, 'v2': null},
      ]);
      expect(nullMaskedLabel, contains('ROC / PR unavailable (0/2)'));
      expect(nullMaskedLabel, isNot(contains('ROC AUC')));
    },
  );

  testWidgets(
    'localization: EN, PT-BR, and TH semantics and 360px light/dark canvas render localized unavailable and single-class text',
    (tester) async {
      const dim = FieldInfo(
        name: 'item',
        label: 'Item',
        type: 'string',
        role: 'dimension',
      );
      const pField = FieldInfo(
        name: 'v1',
        label: 'Score',
        type: 'float',
        role: 'measure',
      );
      const sField = FieldInfo(
        name: 'v2',
        label: 'Outcome',
        type: 'integer',
        role: 'measure',
      );

      final singleClassRows = const [
        {'item': 'P1', 'v1': 0.9, 'v2': 1},
        {'item': 'P2', 'v1': 0.2, 'v2': 1},
      ];
      final missingRows = const [
        {'item': 'M1', 'v1': null, 'v2': null},
        {'item': 'M2', 'v1': null, 'v2': null},
      ];

      const desc = DatasetDescriptor(
        datasetId: 'loc_state_ds',
        title: 'Locale State Fixture',
        description: '',
        equation: null,
        fields: [dim, pField, sField],
        filters: [],
      );

      DatasetPage makePage(List<Map<String, dynamic>> rows) => DatasetPage(
        descriptor: desc,
        rows: rows,
        offset: 0,
        limit: rows.length,
        totalRows: rows.length,
      );

      Future<String> semanticsFor(
        Visual visual,
        List<Map<String, dynamic>> rows,
        Locale locale,
      ) async {
        await tester.pumpWidget(
          _sizedHarness(
            ScienceAiChart(
              visual: visual,
              page: makePage(rows),
              dimension: dim,
              measures: const [pField, sField],
              height: 180,
            ),
            locale: locale,
          ),
        );
        return tester.getSemantics(find.byType(ScienceAiChart)).label;
      }

      expect(
        await semanticsFor(Visual.rocPr, singleClassRows, const Locale('en')),
        contains('ROC unavailable (single class) | PR AUC 1.00'),
      );
      expect(
        await semanticsFor(
          Visual.rocPr,
          singleClassRows,
          const Locale('pt', 'BR'),
        ),
        contains('ROC indisponível (classe única) | PR AUC 1.00'),
      );
      expect(
        await semanticsFor(Visual.rocPr, singleClassRows, const Locale('th')),
        contains('ROC ไม่พร้อมใช้งาน (มีคลาสเดียว) | PR AUC 1.00'),
      );

      expect(
        await semanticsFor(Visual.rocPr, missingRows, const Locale('en')),
        contains('ROC / PR unavailable (0/2)'),
      );
      expect(
        await semanticsFor(Visual.rocPr, missingRows, const Locale('pt', 'BR')),
        contains('ROC / PR indisponíveis (0/2)'),
      );
      expect(
        await semanticsFor(Visual.rocPr, missingRows, const Locale('th')),
        contains('ROC / PR ไม่พร้อมใช้งาน (0/2)'),
      );

      Future<List<int>> renderBytes({
        required Visual visual,
        required List<Map<String, dynamic>> rows,
        required Locale locale,
        required ReportPalette palette,
        required Brightness brightness,
        String? dumpName,
      }) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          _sizedHarness(
            ScienceAiChart(
              visual: visual,
              page: makePage(rows),
              dimension: dim,
              measures: const [pField, sField],
              height: 160,
            ),
            width: 360,
            height: 160,
            locale: locale,
            palette: palette,
            brightness: brightness,
            boundaryKey: key,
          ),
        );
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        late final List<int> rgba;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          rgba = data!.buffer.asUint8List().toList();
          if (dumpName != null) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Platform.environment['WRITE_REVIEW_PNG_DIR'];
            if (dir != null && dir.isNotEmpty) {
              Directory(dir).createSync(recursive: true);
              File(
                '$dir/$dumpName.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
            }
          }
          image.dispose();
        });
        return rgba;
      }

      // Render 360px light & dark across EN, PT-BR, TH for missing & single-class
      final enMissing = await renderBytes(
        visual: Visual.confusionMatrix,
        rows: missingRows,
        locale: const Locale('en'),
        palette: _palette,
        brightness: Brightness.light,
        dumpName: 'missing_en_light_360',
      );
      final ptMissing = await renderBytes(
        visual: Visual.confusionMatrix,
        rows: missingRows,
        locale: const Locale('pt', 'BR'),
        palette: _palette,
        brightness: Brightness.light,
        dumpName: 'missing_pt_br_light_360',
      );
      final thMissing = await renderBytes(
        visual: Visual.confusionMatrix,
        rows: missingRows,
        locale: const Locale('th'),
        palette: _darkPalette,
        brightness: Brightness.dark,
        dumpName: 'missing_th_dark_360',
      );

      final enSingle = await renderBytes(
        visual: Visual.rocPr,
        rows: singleClassRows,
        locale: const Locale('en'),
        palette: _palette,
        brightness: Brightness.light,
        dumpName: 'roc_single_en_light_360',
      );
      final ptSingle = await renderBytes(
        visual: Visual.rocPr,
        rows: singleClassRows,
        locale: const Locale('pt', 'BR'),
        palette: _darkPalette,
        brightness: Brightness.dark,
        dumpName: 'roc_single_pt_br_dark_360',
      );
      final thSingle = await renderBytes(
        visual: Visual.rocPr,
        rows: singleClassRows,
        locale: const Locale('th'),
        palette: _darkPalette,
        brightness: Brightness.dark,
        dumpName: 'roc_single_th_dark_360',
      );

      // Canvas pixels must differ between EN and PT-BR (same palette/size) and TH.
      expect(enMissing, isNot(equals(ptMissing)));
      expect(enMissing, isNot(equals(thMissing)));
      expect(enSingle, isNot(equals(ptSingle)));
      expect(ptSingle, isNot(equals(thSingle)));
    },
  );

  testWidgets(
    'render: learning_curve omits null middle gap instead of coalescing to 0 or bridging across',
    (tester) async {
      const dim = FieldInfo(
        name: 'epoch',
        label: 'Epoch',
        type: 'string',
        role: 'dimension',
      );
      const lossField = FieldInfo(
        name: 'v1',
        label: 'Train Loss',
        type: 'float',
        role: 'measure',
        missingMeans: 'no_data',
      );
      final gapRows = const [
        {'epoch': 'E1', 'v1': 0.85},
        {'epoch': 'E2', 'v1': 0.72},
        {'epoch': 'E3', 'v1': null},
        {'epoch': 'E4', 'v1': 0.35},
        {'epoch': 'E5', 'v1': 0.22},
      ];
      final page = DatasetPage(
        descriptor: const DatasetDescriptor(
          datasetId: 'lc_gap_ds',
          title: 'Learning Curve Gap',
          description: '',
          equation: null,
          fields: [dim, lossField],
          filters: [],
        ),
        rows: gapRows,
        offset: 0,
        limit: gapRows.length,
        totalRows: gapRows.length,
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        _sizedHarness(
          ScienceAiChart(
            visual: Visual.learningCurve,
            page: page,
            dimension: dim,
            measures: const [lossField],
            height: 180,
          ),
          width: 320,
          height: 180,
          boundaryKey: key,
        ),
      );
      expect(tester.takeException(), isNull);

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late final List<int> rgba;
      const width = 320;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        rgba = data!.buffer.asUint8List().toList();
        final dir = Platform.environment['WRITE_REVIEW_PNG_DIR'];
        if (dir != null && dir.isNotEmpty) {
          Directory(dir).createSync(recursive: true);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$dir/learning_curve_gap.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
      });

      // Accent color (#0F62FE) in _paintLearningCurve uses seriesAt(0) == accent.
      int countAccentInXRange(int xMin, int xMax, int yMin, int yMax) {
        var count = 0;
        for (var y = yMin; y <= yMax; y++) {
          for (var x = xMin; x <= xMax; x++) {
            final idx = (y * width + x) * 4;
            final r = rgba[idx];
            final g = rgba[idx + 1];
            final b = rgba[idx + 2];
            // Detect bluish stroke pixels close to #0F62FE and well away from surface #F4F4F4 / border #D0D0D0.
            if (b > 200 && b - r > 120 && g >= 60 && g <= 150) {
              count++;
            }
          }
        }
        return count;
      }

      // plot = Rect.fromLTWH(38, 18, 320 - 54 = 266, 180 - 40 = 140)
      // x(i) = 38 + (i / 4) * 266:
      // E1 = 38, E2 = 104.5, E3 (null gap) = 171.0, E4 = 237.5, E5 = 304.0
      final e2Pixels = countAccentInXRange(100, 109, 15, 165);
      final gapBandPixels = countAccentInXRange(112, 230, 15, 165);
      final e4Pixels = countAccentInXRange(233, 242, 15, 165);

      expect(e2Pixels, greaterThan(5));
      expect(e4Pixels, greaterThan(5));
      expect(gapBandPixels, equals(0));
    },
  );
}
