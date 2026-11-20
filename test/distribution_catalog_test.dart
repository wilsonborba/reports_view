import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const distCatalogIds = <String>[
    'histogram',
    'box_plot',
    'violin',
    'density',
    'ridgeline',
    'strip',
    'ecdf',
    'qq_plot',
    'population_pyramid',
    'raincloud',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'dist_ds',
      title: 'Distribution Fixture',
      description: 'Distribution catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'cohort',
          label: 'Cohort',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'score',
          label: 'Score',
          type: 'float',
          role: 'measure',
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
    rows: const [
      {'cohort': 'A', 'score': 12.0},
      {'cohort': 'A', 'score': 18.0},
      {'cohort': 'A', 'score': 25.0},
      {'cohort': 'B', 'score': 30.0},
      {'cohort': 'B', 'score': 34.0},
      {'cohort': 'B', 'score': 41.0},
      {'cohort': 'C', 'score': 22.0},
      {'cohort': 'C', 'score': 27.0},
    ],
    offset: 0,
    limit: 50,
    totalRows: 8,
  );

  const palette = ReportPalette(
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

  for (final id in distCatalogIds) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
      for (final locale in const [
        Locale('en'),
        Locale('pt', 'BR'),
        Locale('th'),
      ]) {
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
              acceptedTypes: ['integer', 'float'],
            ),
          ],
        );
        final binding = CardVisualBinding(
          template: id,
          version: 1,
          mapping: const {
            'category': ['cohort'],
            'value': ['score'],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: ThemeData.light().copyWith(extensions: const [palette]),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
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
        expect(
          find.byType(ChartFrame),
          findsOneWidget,
          reason: '$id in ${locale.toLanguageTag()}',
        );
        expect(
          find.textContaining('Invalid'),
          findsNothing,
          reason: '$id in ${locale.toLanguageTag()}',
        );
      }
    });
  }
}
