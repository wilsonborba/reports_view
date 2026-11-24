import 'package:flutter/material.dart';
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

  test('semantic: top_k_prob sorts descending and sums to 1.0', () {
    final page = _makeSciencePage('top_k_prob');
    final top = ScienceAiChart.computeTopK(
      page.rows,
      page.descriptor.fields[0],
      page.descriptor.fields[1],
    );
    expect(top.first.label, 'Class A');
    expect(top.first.prob, greaterThan(top.last.prob));
    final total = top.fold<double>(0.0, (a, b) => a + b.prob);
    expect(total, closeTo(1.0, 1e-6));
  });

  test(
    'semantic: roc_pr starts at (0,0), is monotonic to (1,1), computes AUC & PR',
    () {
      final res = ScienceAiChart.computeRocPr(
        const [0.95, 0.85, 0.72, 0.65, 0.50, 0.30, 0.20, 0.10],
        const [true, true, false, true, false, false, true, false],
      );
      expect(res.rocPoints.first, const Offset(0, 0));
      expect(res.rocPoints.last, const Offset(1, 1));
      for (var i = 1; i < res.rocPoints.length; i++) {
        expect(
          res.rocPoints[i].dx,
          greaterThanOrEqualTo(res.rocPoints[i - 1].dx),
        );
        expect(
          res.rocPoints[i].dy,
          greaterThanOrEqualTo(res.rocPoints[i - 1].dy),
        );
      }
      expect(res.rocAuc, greaterThan(0.5));
      expect(res.prAuc, greaterThan(0.0));
    },
  );

  test(
    'semantic: calibration computes binned observed frequency without dropping on calibrated predictions',
    () {
      final bins = ScienceAiChart.computeCalibration(
        const [0.1, 0.12, 0.35, 0.38, 0.65, 0.68, 0.90, 0.95],
        const [false, false, false, true, true, false, true, true],
        bins: 4,
      );
      expect(bins.length, 4);
      expect(bins.last.meanPred, greaterThan(0.8));
      expect(bins.last.obsFreq, 1.0);
      expect(bins.first.obsFreq, 0.0);
    },
  );

  test(
    'semantic: confusion_matrix computes predicted vs actual and cells sum to sample count',
    () {
      final page = _makeSciencePage('confusion_matrix');
      final cm = ScienceAiChart.computeConfusionMatrix(
        page.rows,
        page.descriptor.fields[0],
        page.descriptor.fields[1],
        page.descriptor.fields[2],
      );
      final cellSum = cm.counts
          .expand((row) => row)
          .fold<int>(0, (a, b) => a + b);
      expect(cm.total, page.rows.length);
      expect(cellSum, page.rows.length);
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
    'semantic: irt_icc passes through P(b)=0.5 monotonically from item b and a',
    () {
      final curves = ScienceAiChart.computeIrtCurves(
        const [-1.0, 1.0],
        const [1.0, 2.0],
        const ['Easy', 'Hard'],
        infoCurve: false,
        steps: 60,
      );
      // theta=1.0 is index (1.0 - (-3.0)) / 6.0 * 60 = 40
      expect(curves[1].points[40].dx, closeTo(1.0, 1e-6));
      expect(curves[1].points[40].dy, closeTo(0.5, 1e-6));
      for (var i = 1; i < curves[0].points.length; i++) {
        expect(curves[0].points[i].dy, greaterThan(curves[0].points[i - 1].dy));
      }
    },
  );

  test('semantic: irt_iif peak scales as a^2 / 4 at theta == b', () {
    final curves = ScienceAiChart.computeIrtCurves(
      const [0.0, 0.0],
      const [1.0, 2.0],
      const ['LowA', 'HighA'],
      infoCurve: true,
      steps: 60,
    );
    // theta=0.0 is step 30: max info = a^2 * 0.25 -> 0.25 vs 1.0
    expect(curves[0].points[30].dy, closeTo(0.25, 1e-6));
    expect(curves[1].points[30].dy, closeTo(1.0, 1e-6));
  });

  test(
    'semantic: wright_map places persons on left bins and items on same logit scale',
    () {
      final persons = const [-1.8, -0.9, -0.2, 0.5, 1.2, 1.9];
      final items = const [-1.5, 0.0, 1.4];
      final wm = ScienceAiChart.computeWrightMap(persons, items, const [
        'Q1',
        'Q2',
        'Q3',
      ]);
      final totalPersons = wm.personBins.fold<int>(0, (a, b) => a + b.count);
      expect(totalPersons, persons.length);
      expect(wm.items.length, items.length);
      expect(wm.minLogit, lessThanOrEqualTo(-3.0));
      expect(wm.maxLogit, greaterThanOrEqualTo(3.0));
    },
  );

  test(
    'semantic: item_diff_disc distinguishes item b and a directly from row measures',
    () {
      final page = _makeSciencePage('item_diff_disc');
      expect((page.rows[0]['v1'] as num).toDouble(), lessThan(0));
      expect((page.rows[2]['v2'] as num).toDouble(), greaterThan(2.0));
    },
  );

  test(
    'semantic: kaplan_meier starts at 1.0, is non-increasing, and marks censored observations',
    () {
      final km = ScienceAiChart.computeKaplanMeier(
        const [2, 4, 6, 9, 12],
        const [true, false, true, false, true],
      );
      expect(km.first.time, 0.0);
      expect(km.first.survival, 1.0);
      expect(km[2].censored, isTrue);
      expect(km[2].survival, km[1].survival); // censoring does not drop S(t)
      for (var i = 1; i < km.length; i++) {
        expect(km[i].survival, lessThanOrEqualTo(km[i - 1].survival));
        expect(km[i].survival, greaterThanOrEqualTo(0.0));
      }
    },
  );
}
