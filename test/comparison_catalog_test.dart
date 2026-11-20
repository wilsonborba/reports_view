import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const comparisonCatalogIds = <String>[
    'vertical_bar',
    'horizontal_bar',
    'ranking_bar',
    'grouped_bar',
    'stacked_bar',
    'stacked_bar_100',
    'diverging_bar',
    'floating_bar',
    'lollipop',
    'dot_plot',
    'dumbbell',
    'slope',
    'bullet',
    'utilization_bar',
    'pictogram',
    'radial_bar',
    'circular_bar',
    'radar',
    'parallel_coordinates',
    'marimekko',
    'waterfall',
    'pareto',
    'small_multiples',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'cmp_ds',
      title: 'Comparison Fixture',
      description: 'Comparison catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'category',
          label: 'Category',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'series',
          label: 'Series',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'actual',
          label: 'Actual',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'target',
          label: 'Target',
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
    rows: const [
      {'category': 'Alpha', 'series': 'S1', 'actual': 80, 'target': 70},
      {'category': 'Beta', 'series': 'S2', 'actual': 45, 'target': 60},
      {'category': 'Gamma', 'series': 'S1', 'actual': -20, 'target': 30},
    ],
    offset: 0,
    limit: 50,
    totalRows: 3,
  );

  test('every comparison catalog item (1 to 23) maps to a concrete Visual', () {
    expect(comparisonCatalogIds.length, 23);
    for (final id in comparisonCatalogIds) {
      expect(VisualChooser.visualFromName(id), isNot(Visual.auto), reason: id);
    }
  });

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
    series: [Color(0xFF0F62FE), Color(0xFF8A3FFC), Color(0xFF009D9A)],
    other: Color(0xFF8D8D8D),
    highlight: Color(0xFF0F62FE),
  );

  for (final locale in const [Locale('en'), Locale('pt', 'BR'), Locale('th')]) {
    testWidgets(
      'renders all 23 comparison templates in ${locale.toLanguageTag()}',
      (tester) async {
        for (final id in comparisonCatalogIds) {
          final needsTwoDims = id == 'stacked_bar';
          final needsTwoMeasures = const {
            'grouped_bar',
            'stacked_bar_100',
            'floating_bar',
            'dumbbell',
            'slope',
            'bullet',
            'radar',
            'parallel_coordinates',
            'marimekko',
            'small_multiples',
          }.contains(id);

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
                minCount: 1,
                maxCount: 2,
                acceptedTypes: ['string'],
              ),
              TemplateSlot(
                slotName: 'value',
                role: 'measure',
                minCount: needsTwoMeasures ? 2 : 1,
                maxCount: 4,
                acceptedTypes: const ['integer', 'float'],
              ),
            ],
          );

          final binding = CardVisualBinding(
            template: id,
            version: 1,
            mapping: {
              'category': needsTwoDims
                  ? const ['category', 'series']
                  : const ['category'],
              'value': needsTwoMeasures
                  ? const ['actual', 'target']
                  : const ['actual'],
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
      },
    );
  }
}
