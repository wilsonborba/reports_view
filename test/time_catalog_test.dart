import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const timeCatalogIds = <String>[
    'line',
    'step_line',
    'area',
    'stacked_area',
    'stacked_area_100',
    'streamgraph',
    'sparkline',
    'bump_chart',
    'candlestick',
    'range_band',
    'combo',
    'annotated_line',
    'timeline',
    'gantt',
    'calendar_heatmap',
    'horizon',
    'control_chart',
    'burndown',
    'cycle_plot',
    'curve',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'time_ds',
      title: 'Time Series Fixture',
      description: 'Change over time catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'day', label: 'Day', type: 'date', role: 'dimension'),
        FieldInfo(
          name: 'primary',
          label: 'Primary',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'secondary',
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
        periodEnd: '2026-01-04',
        timezone: 'UTC',
        freshnessMode: 'daily',
        expectedRefreshMinutes: 60,
        updatedAt: 1700000000,
        tier: 'public',
      ),
    ),
    rows: const [
      {'day': '2026-01-01', 'primary': 20, 'secondary': 30},
      {'day': '2026-01-02', 'primary': 45, 'secondary': 55},
      {'day': '2026-01-03', 'primary': 35, 'secondary': 50},
      {'day': '2026-01-04', 'primary': 60, 'secondary': 75},
    ],
    offset: 0,
    limit: 50,
    totalRows: 4,
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
    series: [Color(0xFF0F62FE), Color(0xFF8A3FFC), Color(0xFF009D9A)],
    other: Color(0xFF8D8D8D),
    highlight: Color(0xFF0F62FE),
  );

  test(
    'every change-over-time catalog item (24 to 43) maps to a concrete Visual',
    () {
      expect(timeCatalogIds.length, 20);
      for (final id in timeCatalogIds) {
        expect(
          VisualChooser.visualFromName(id),
          isNot(Visual.auto),
          reason: id,
        );
      }
    },
  );

  for (final locale in const [Locale('en'), Locale('pt', 'BR'), Locale('th')]) {
    testWidgets('renders all 20 time templates in ${locale.toLanguageTag()}', (
      tester,
    ) async {
      for (final id in timeCatalogIds) {
        final needsTwo = const {
          'stacked_area',
          'stacked_area_100',
          'streamgraph',
          'candlestick',
          'range_band',
          'combo',
        }.contains(id);
        final tpl = VisualTemplate(
          templateId: id,
          version: 1,
          kind: 'chart',
          visual: id,
          title: id,
          slots: [
            const TemplateSlot(
              slotName: 'time',
              role: 'dimension',
              minCount: 1,
              maxCount: 1,
              acceptedTypes: ['date', 'datetime', 'integer', 'float'],
            ),
            TemplateSlot(
              slotName: 'value',
              role: 'measure',
              minCount: needsTwo ? 2 : 1,
              maxCount: 4,
              acceptedTypes: const ['integer', 'float'],
            ),
          ],
        );
        final binding = CardVisualBinding(
          template: id,
          version: 1,
          mapping: {
            'time': const ['day'],
            'value': needsTwo
                ? const ['primary', 'secondary']
                : const ['primary'],
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
