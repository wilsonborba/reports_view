import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/indicator_table_charts.dart';

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

DatasetPage _indicatorPage(String id) {
  final (fields, rows) = switch (id) {
    'kpi' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Segment',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Throughput',
          type: 'integer',
          role: 'measure',
          unit: 'ops',
        ),
        FieldInfo(
          name: 'v2',
          label: 'Availability',
          type: 'percent',
          role: 'measure',
          unit: '%',
        ),
      ],
      const [
        {'item': 'Core Alpha', 'v1': 12480, 'v2': 94.6},
        {'item': 'Edge Beta', 'v1': 8420, 'v2': 99.1},
      ],
    ),
    'kpi_sparkline' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Day',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Daily Active Users',
          type: 'integer',
          role: 'measure',
          unit: 'users',
        ),
      ],
      const [
        {'item': 'D1', 'v1': 1120},
        {'item': 'D2', 'v1': 1185},
        {'item': 'D3', 'v1': 1210},
        {'item': 'D4', 'v1': 1265},
        {'item': 'D5', 'v1': 1340},
      ],
    ),
    'status_scorecard' => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Metric',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Score',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'v2',
          label: 'Target',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      const [
        {'item': 'API Uptime', 'v1': 99, 'v2': 98},
        {'item': 'Cache Hit', 'v1': 84, 'v2': 80},
        {'item': 'Error Budget', 'v1': 32, 'v2': 90},
        {'item': 'Sync SLA', 'v1': 71, 'v2': 75},
      ],
    ),
    _ => (
      const [
        FieldInfo(
          name: 'item',
          label: 'Topic',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: 'Mentions',
          type: 'integer',
          role: 'measure',
          unit: 'hits',
        ),
        FieldInfo(
          name: 'v2',
          label: 'Share',
          type: 'integer',
          role: 'measure',
          unit: '%',
        ),
      ],
      const [
        {'item': 'Machine Learning', 'v1': 95, 'v2': 40},
        {'item': 'Rust Async', 'v1': 82, 'v2': 32},
        {'item': 'Flutter Web', 'v1': 68, 'v2': 28},
        {'item': 'PostgreSQL', 'v1': 54, 'v2': 20},
      ],
    ),
  };

  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'indicator_$id',
      title: 'Indicators ($id)',
      description: 'Items 99 to 104 realistic fixture',
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
    'kpi',
    'kpi_sparkline',
    'table',
    'heat_table',
    'status_scorecard',
    'word_cloud',
  ];

  for (final id in ids) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
      final page = _indicatorPage(id);
      final maxM = id == 'kpi_sparkline' ? 1 : 2;
      final tpl = VisualTemplate(
        templateId: id,
        version: 1,
        kind: 'chart',
        visual: id,
        title: id,
        slots: [
          const TemplateSlot(
            slotName: 'category',
            role: 'dimension',
            minCount: 0,
            maxCount: 1,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: maxM,
            acceptedTypes: const ['integer', 'float', 'percent'],
          ),
        ],
      );
      final binding = CardVisualBinding(
        template: id,
        version: 1,
        mapping: {
          'category': const ['item'],
          'value': maxM == 1 ? const ['v1'] : const ['v1', 'v2'],
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

  testWidgets(
    'kpi displays numeric measure values, never category text as tile headline',
    (tester) async {
      final page = _indicatorPage('kpi');
      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 260,
              child: VisualChooser.build(
                page,
                const Slot('s', visual: Visual.kpi),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Core Alpha'), findsNothing);
      expect(find.textContaining('12,480'), findsOneWidget);
      expect(find.textContaining('94.6%'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 260,
              child: KpiTiles(page: page, rowIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('8,420'), findsOneWidget);
      expect(find.textContaining('99.1%'), findsOneWidget);
    },
  );

  testWidgets(
    'kpi_sparkline and status_scorecard display exact latest and row measure values',
    (tester) async {
      final sparkPage = _indicatorPage('kpi_sparkline');
      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 260,
              child: VisualChooser.build(
                sparkPage,
                const Slot('s', visual: Visual.kpiSparkline),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1,340'), findsOneWidget);

      final scorePage = _indicatorPage('status_scorecard');
      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 300,
              child: VisualChooser.build(
                scorePage,
                const Slot('s', visual: Visual.statusScorecard),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('API Uptime'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
    },
  );

  testWidgets('KPI sparkline delta uses the host locale decimal separator', (
    tester,
  ) async {
    final page = _indicatorPage('kpi_sparkline');
    await tester.pumpWidget(
      MaterialApp(
        theme: _palette.toTheme(Brightness.light),
        home: Scaffold(
          body: Localizations(
            locale: const Locale('pt', 'BR'),
            delegates: const [DefaultWidgetsLocalizations.delegate],
            child: SizedBox(
              width: 440,
              height: 180,
              child: IndicatorTableChart(
                page: page,
                visual: Visual.kpiSparkline,
                dimension: page.descriptor.fields.first,
                measures: [page.descriptor.fields.last],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+5,9%'), findsOneWidget);
    expect(find.text('+5.9%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('word_cloud layout places non-overlapping words ordered by weight', () {
    final page = _indicatorPage('word_cloud');
    final placed = IndicatorTableChart.layoutWords(
      const Size(420, 240),
      page.rows,
      page.descriptor.fields[0],
      page.descriptor.fields[1],
      _palette,
    );
    expect(placed.length, 4);
    expect(placed.first.text, 'Machine Learning');
    expect(placed.first.fontSize, greaterThan(placed.last.fontSize));
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        expect(
          placed[i].rect.overlaps(placed[j].rect),
          isFalse,
          reason: 'Words ${placed[i].text} and ${placed[j].text} overlapped',
        );
      }
    }
  });
}
