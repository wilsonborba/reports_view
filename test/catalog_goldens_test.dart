import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

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

DatasetPage _makePage(String id, String dimName, String dimType, int count) {
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: id,
      title: '$id Fixture',
      description: 'Catalog golden fixture',
      equation: null,
      fields: [
        FieldInfo(
          name: dimName,
          label: 'Category',
          type: dimType,
          role: 'dimension',
        ),
        const FieldInfo(
          name: 'v1',
          label: 'Primary',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        const FieldInfo(
          name: 'v2',
          label: 'Secondary',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
      meta: const DatasetMeta(
        source: 'Test fixture',
        sourceUrl: 'https://reports.asodya.com',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        timezone: 'UTC',
        freshnessMode: 'daily',
        expectedRefreshMinutes: 60,
        updatedAt: 1700000000,
        tier: 'public',
      ),
    ),
    rows: [
      for (var i = 0; i < count; i++)
        {
          dimName: dimType == 'date'
              ? '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}'
              : 'Item ${i + 1}',
          'v1': 20 + (i * 17) % 80,
          'v2': 15 + (i * 11) % 60,
        },
    ],
    offset: 0,
    limit: count,
    totalRows: count,
  );
}

Future<void> _pumpAndGolden(
  WidgetTester tester, {
  required String group,
  required String id,
  required DatasetPage page,
  required String dimSlot,
  required String dimType,
  required String dimField,
  required bool twoMeasures,
}) async {
  for (final locale in const [
    Locale('en'),
    Locale('pt', 'BR'),
    Locale('th'),
  ]) {
    final tag = locale.toLanguageTag();
    final tpl = VisualTemplate(
      templateId: id,
      version: 1,
      kind: 'chart',
      visual: id,
      title: '$id ($tag)',
      slots: [
        TemplateSlot(
          slotName: dimSlot,
          role: 'dimension',
          minCount: 1,
          maxCount: 1,
          acceptedTypes: [dimType],
        ),
        TemplateSlot(
          slotName: 'value',
          role: 'measure',
          minCount: twoMeasures ? 2 : 1,
          maxCount: twoMeasures ? 2 : 1,
          acceptedTypes: const ['integer', 'float'],
        ),
      ],
    );
    final binding = CardVisualBinding(
      template: id,
      version: 1,
      mapping: {
        dimSlot: [dimField],
        'value': twoMeasures ? ['v1', 'v2'] : ['v1'],
      },
    );
    final key = UniqueKey();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: ThemeData.light().copyWith(extensions: const [_palette]),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 480,
              height: 360,
              child: SingleChildScrollView(
                child: VisualChooser.buildTemplate(
                  page: page,
                  template: tpl,
                  binding: binding,
                  title: '$id ($tag)',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/$group/${id}_$tag.png'),
    );
  }
}

void main() {
  const comparisonIds = [
    'vertical_bar', 'horizontal_bar', 'ranking_bar', 'grouped_bar',
    'stacked_bar', 'stacked_bar_100', 'diverging_bar', 'floating_bar',
    'lollipop', 'dot_plot', 'dumbbell', 'slope', 'bullet', 'utilization_bar',
    'pictogram', 'radial_bar', 'circular_bar', 'radar',
    'parallel_coordinates', 'marimekko', 'waterfall', 'pareto',
    'small_multiples',
  ];
  const twoMeasureComparison = {
    'grouped_bar', 'stacked_bar', 'stacked_bar_100', 'diverging_bar',
    'floating_bar', 'dumbbell', 'slope', 'bullet', 'utilization_bar',
    'parallel_coordinates', 'marimekko',
  };

  const timeIds = [
    'line', 'step_line', 'area', 'stacked_area', 'stacked_area_100',
    'streamgraph', 'sparkline', 'bump_chart', 'candlestick', 'range_band',
    'combo', 'annotated_line', 'timeline', 'gantt', 'calendar_heatmap',
    'horizon', 'control_chart', 'burndown', 'cycle_plot', 'curve',
  ];
  const twoMeasureTime = {
    'stacked_area', 'stacked_area_100', 'streamgraph', 'candlestick',
    'range_band', 'combo', 'gantt',
  };

  const partWholeIds = [
    'donut', 'pie', 'gauge', 'meter', 'treemap', 'sunburst', 'icicle',
    'circle_packing', 'waffle', 'nightingale_rose', 'funnel',
  ];

  const distIds = [
    'histogram', 'box_plot', 'violin', 'density', 'ridgeline', 'strip',
    'ecdf', 'qq_plot', 'population_pyramid', 'raincloud',
  ];

  final cmpPage = _makePage('cmp', 'cat', 'string', 6);
  final timePage = _makePage('time', 'day', 'date', 8);
  final pwPage = _makePage('pw', 'part', 'string', 5);
  final distPage = _makePage('dist', 'cohort', 'string', 8);

  for (final id in comparisonIds) {
    testWidgets('golden comparison/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'comparison',
        id: id,
        page: cmpPage,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cat',
        twoMeasures: twoMeasureComparison.contains(id),
      );
    });
  }

  for (final id in timeIds) {
    testWidgets('golden time/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'time',
        id: id,
        page: timePage,
        dimSlot: 'time',
        dimType: 'date',
        dimField: 'day',
        twoMeasures: twoMeasureTime.contains(id),
      );
    });
  }

  for (final id in partWholeIds) {
    testWidgets('golden part_whole/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'part_whole',
        id: id,
        page: pwPage,
        dimSlot: 'part',
        dimType: 'string',
        dimField: 'part',
        twoMeasures: false,
      );
    });
  }

  for (final id in distIds) {
    testWidgets('golden distribution/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'distribution',
        id: id,
        page: distPage,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cohort',
        twoMeasures: false,
      );
    });
  }

  testWidgets('size limits measurement across 10, 50, 200, 500 rows', (
    tester,
  ) async {
    for (final n in [10, 50, 200, 500]) {
      final p = _makePage('bench_$n', 'cat', 'string', n);
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: const [_palette]),
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 360,
              child: Column(
                children: [
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.treemap),
                    ),
                  ),
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.streamgraph),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      sw.stop();
      // ignore: avoid_print
      print('SIZE_LIMIT_ROWS=$n RENDER_MS=${sw.elapsedMilliseconds}');
      expect(tester.takeException(), isNull);
    }
  });
}
