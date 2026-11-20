import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/sets_charts.dart';

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
  const setIds = <String>['venn', 'euler', 'upset'];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'sets_ds',
      title: 'Sets Fixture',
      description: 'Venn, Euler, and UpSet fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'sets', label: 'Sets', type: 'string', role: 'dimension'),
        FieldInfo(name: 'cnt', label: 'Count', type: 'integer', role: 'measure', unit: 'items'),
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
      {'sets': 'Alpha', 'cnt': 40},
      {'sets': 'Beta', 'cnt': 30},
      {'sets': 'Gamma', 'cnt': 20},
      {'sets': 'Alpha & Beta', 'cnt': 12},
      {'sets': 'Beta & Gamma', 'cnt': 8},
    ],
    offset: 0,
    limit: 5,
    totalRows: 5,
  );

  for (final id in setIds) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
      final tpl = VisualTemplate(
        templateId: id,
        version: 1,
        kind: 'diagram',
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
            maxCount: 1,
            acceptedTypes: ['integer'],
          ),
        ],
      );
      final binding = CardVisualBinding(
        template: id,
        version: 1,
        mapping: const {
          'category': ['sets'],
          'value': ['cnt'],
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
                child: VisualChooser.buildTemplate(
                  page: page,
                  template: tpl,
                  binding: binding,
                  title: id,
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

  test('sets size limit D7 caps distinct sets at maxSets (5)', () {
    final manyRows = [
      for (var i = 0; i < 10; i++) {'sets': 'S$i', 'cnt': 10 + i},
    ];
    final intersections = SetsCatalogChart.extractIntersections(
      manyRows,
      const FieldInfo(name: 'sets', label: 'Sets', type: 'string', role: 'dimension'),
      const FieldInfo(name: 'cnt', label: 'Count', type: 'integer', role: 'measure'),
    );
    final totals = SetsCatalogChart.computeSetTotals(intersections);
    expect(totals.length, SetsCatalogChart.maxSets);
  });
}
