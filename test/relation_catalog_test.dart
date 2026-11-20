import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const relationCatalogIds = <String>[
    'scatter',
    'bubble',
    'heatmap',
    'correlation_matrix',
    'hexbin',
    'contour_2d',
    'splom',
    'quadrant',
    'ternary',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'rel_ds',
      title: 'Relation Fixture',
      description: 'Relation and correlation catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'item',
          label: 'Item',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'x',
          label: 'Duration',
          type: 'float',
          role: 'measure',
          unit: 's',
        ),
        FieldInfo(
          name: 'y',
          label: 'Score',
          type: 'float',
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
      {'item': 'A', 'x': 10.0, 'y': 42.0},
      {'item': 'B', 'x': 22.0, 'y': 68.0},
      {'item': 'C', 'x': 35.0, 'y': 55.0},
      {'item': 'D', 'x': 48.0, 'y': 84.0},
      {'item': 'E', 'x': 60.0, 'y': 91.0},
    ],
    offset: 0,
    limit: 50,
    totalRows: 5,
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

  for (final id in relationCatalogIds) {
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
              minCount: 2,
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
            'value': ['x', 'y'],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: palette.toTheme(Brightness.light),
            home: Builder(
              builder: (context) => Localizations.override(
                context: context,
                locale: locale,
                child: Scaffold(
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
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(ChartFrame), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.textContaining('Invalid'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
