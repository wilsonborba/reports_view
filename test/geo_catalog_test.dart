import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/geo_charts.dart';

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
  const geoIds = <String>[
    'map',
    'bubble_map',
    'choropleth',
    'geo_heatmap',
    'flow_map',
    'hex_tile_map',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'geo_ds',
      title: 'Geographic Fixture',
      description: 'Geographic catalog items 93 to 98 fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'region', label: 'Region', type: 'string', role: 'dimension'),
        FieldInfo(name: 'lat', label: 'Lat', type: 'latitude', role: 'dimension'),
        FieldInfo(name: 'lon', label: 'Lon', type: 'longitude', role: 'dimension'),
        FieldInfo(name: 'val', label: 'Total', type: 'integer', role: 'measure', unit: 'pts'),
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
      {'region': 'BKK', 'lat': 13.75, 'lon': 100.50, 'val': 120},
      {'region': 'CNX', 'lat': 18.79, 'lon': 98.98, 'val': 65},
      {'region': 'HKT', 'lat': 7.88, 'lon': 98.39, 'val': 48},
      {'region': 'SP', 'lat': -23.55, 'lon': -46.63, 'val': 95},
      {'region': 'RJ', 'lat': -22.91, 'lon': -43.17, 'val': 52},
    ],
    offset: 0,
    limit: 5,
    totalRows: 5,
  );

  for (final id in geoIds) {
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
          'category': ['region'],
          'value': ['val'],
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

  test('geo size limit caps regions at maxRegions (24)', () {
    final manyRows = [
      for (var i = 0; i < 40; i++)
        {'region': 'R$i', 'lat': 10.0 + i, 'lon': 20.0 + i, 'val': 10 + i},
    ];
    final manyPage = DatasetPage(
      descriptor: page.descriptor,
      rows: manyRows,
      offset: 0,
      limit: 40,
      totalRows: 40,
    );
    final pts = GeoCatalogChart.extractPoints(
      manyPage,
      page.descriptor.fields.first,
      page.descriptor.fields.last,
    );
    expect(pts.length, GeoCatalogChart.maxRegions);
  });
}
