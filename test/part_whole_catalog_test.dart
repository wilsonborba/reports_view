import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const partWholeCatalogIds = <String>[
    'donut',
    'pie',
    'gauge',
    'meter',
    'treemap',
    'sunburst',
    'icicle',
    'circle_packing',
    'waffle',
    'nightingale_rose',
    'funnel',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'pw_ds',
      title: 'Part-of-Whole Fixture',
      description: 'Part of a whole catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'part',
          label: 'Part',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'count',
          label: 'Count',
          type: 'integer',
          role: 'measure',
          unit: 'items',
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
      {'part': 'Core', 'count': 50},
      {'part': 'Docs', 'count': 30},
      {'part': 'Tests', 'count': 20},
    ],
    offset: 0,
    limit: 50,
    totalRows: 3,
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
    'every part-of-whole catalog item (44 to 54) maps to a concrete Visual',
    () {
      expect(partWholeCatalogIds.length, 11);
      for (final id in partWholeCatalogIds) {
        expect(
          VisualChooser.visualFromName(id),
          isNot(Visual.auto),
          reason: id,
        );
      }
    },
  );

  for (final locale in const [Locale('en'), Locale('pt', 'BR'), Locale('th')]) {
    testWidgets(
      'renders all 11 part-of-whole templates in ${locale.toLanguageTag()}',
      (tester) async {
        for (final id in partWholeCatalogIds) {
          final tpl = VisualTemplate(
            templateId: id,
            version: 1,
            kind: 'chart',
            visual: id,
            title: id,
            slots: const [
              TemplateSlot(
                slotName: 'part',
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
              'part': ['part'],
              'value': ['count'],
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
