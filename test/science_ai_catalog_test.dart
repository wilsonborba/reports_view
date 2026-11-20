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

void main() {
  const ids = <String>[
    'top_k_prob',
    'calibration',
    'confusion_matrix',
    'roc_pr',
    'learning_curve',
    'irt_icc',
    'irt_iif',
    'wright_map',
    'item_diff_disc',
    'kaplan_meier',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'science_ai_ds',
      title: 'Science AI Assessment Fixture',
      description: 'Items 105 to 114 fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'item', label: 'Item', type: 'string', role: 'dimension'),
        FieldInfo(name: 'v1', label: 'Primary', type: 'float', role: 'measure', unit: 'u'),
        FieldInfo(name: 'v2', label: 'Secondary', type: 'float', role: 'measure', unit: 'u'),
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
      {'item': 'T1', 'v1': 0.88, 'v2': 0.91},
      {'item': 'T2', 'v1': 0.72, 'v2': 0.68},
      {'item': 'T3', 'v1': 0.54, 'v2': 0.49},
      {'item': 'T4', 'v1': 0.31, 'v2': 0.35},
      {'item': 'T5', 'v1': 0.14, 'v2': 0.18},
      {'item': 'T6', 'v1': 0.06, 'v2': 0.09},
    ],
    offset: 0,
    limit: 6,
    totalRows: 6,
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
            minCount: 1,
            maxCount: 1,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: 2,
            acceptedTypes: ['float'],
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
}
