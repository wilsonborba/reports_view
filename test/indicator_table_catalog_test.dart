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

void main() {
  const ids = <String>[
    'kpi',
    'kpi_sparkline',
    'table',
    'heat_table',
    'status_scorecard',
    'word_cloud',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'indicator_ds',
      title: 'Indicators and Tables Fixture',
      description: 'Items 99 to 104 fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'item', label: 'Item', type: 'string', role: 'dimension'),
        FieldInfo(name: 'v1', label: 'Score', type: 'integer', role: 'measure', unit: 'pts'),
        FieldInfo(name: 'v2', label: 'Target', type: 'integer', role: 'measure', unit: 'pts'),
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
    rows: const [
      {'item': 'Alpha', 'v1': 84, 'v2': 90},
      {'item': 'Beta', 'v1': 56, 'v2': 70},
      {'item': 'Gamma', 'v1': 28, 'v2': 45},
      {'item': 'Delta', 'v1': 92, 'v2': 88},
    ],
    offset: 0,
    limit: 4,
    totalRows: 4,
  );

  for (final id in ids) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
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
            minCount: 0,
            maxCount: 1,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: 2,
            acceptedTypes: ['integer'],
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
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$id ($locale) threw');
      }
    });
  }

  test('word_cloud layout places non-overlapping words ordered by weight', () {
    final placed = IndicatorTableChart.layoutWords(
      const Size(420, 240),
      page.rows,
      page.descriptor.fields[0],
      page.descriptor.fields[1],
      _palette,
    );
    expect(placed.length, 4);
    expect(placed.first.text, 'Delta');
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
