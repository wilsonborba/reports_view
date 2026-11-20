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

  test('semantic: intersections, Euler disjointness, and non-overlapping labels', () {
    final rows = const [
      {'sets': 'Core', 'cnt': 42},
      {'sets': 'Cloud', 'cnt': 35},
      {'sets': 'Edge', 'cnt': 28},
      {'sets': 'Mobile', 'cnt': 18},
      {'sets': 'Core & Cloud', 'cnt': 22},
      {'sets': 'Cloud & Edge', 'cnt': 14},
      {'sets': 'Core & Cloud & Mobile', 'cnt': 8},
    ];
    final intersections = SetsCatalogChart.extractIntersections(
      rows,
      const FieldInfo(name: 'sets', label: 'Sets', type: 'string', role: 'dimension'),
      const FieldInfo(name: 'cnt', label: 'Count', type: 'integer', role: 'measure'),
    );
    final totals = SetsCatalogChart.computeSetTotals(intersections);

    // Pairwise intersection sizes
    expect(SetsCatalogChart.pairwiseOverlap(intersections, 'Core', 'Cloud'), 30);
    expect(SetsCatalogChart.pairwiseOverlap(intersections, 'Cloud', 'Edge'), 14);
    expect(SetsCatalogChart.pairwiseOverlap(intersections, 'Core', 'Edge'), 0);

    // UpSet prioritizes multi-set intersection columns
    final upCols = SetsCatalogChart.computeUpSetColumns(intersections);
    expect(upCols.first.sets.length, greaterThanOrEqualTo(2));
    expect(upCols.where((c) => c.sets.length >= 2).length, 3);

    // Euler vs Venn: Euler separates non-intersecting Core & Edge, and scales radii by count
    const sz = Size(440, 260);
    final euler = SetsCatalogChart.layoutCircles(
      sz,
      intersections,
      totals,
      _palette,
      euler: true,
    );
    final venn = SetsCatalogChart.layoutCircles(
      sz,
      intersections,
      totals,
      _palette,
      euler: false,
    );
    expect(euler.length, 3);
    expect(venn.length, 3);

    // Core (0) and Cloud (1) intersect; Core (0) and Edge (2) do NOT intersect in Euler
    final dCoreCloud = (euler[0].center - euler[1].center).distance;
    final dCoreEdge = (euler[0].center - euler[2].center).distance;
    expect(dCoreCloud, lessThan(euler[0].radius + euler[1].radius));
    expect(dCoreEdge, greaterThan(euler[0].radius + euler[2].radius));
    expect(euler[0].radius, greaterThan(euler[2].radius));

    // All label boxes in both Venn and Euler must be strictly non-overlapping
    for (final circles in [venn, euler]) {
      for (var i = 0; i < circles.length; i++) {
        for (var j = i + 1; j < circles.length; j++) {
          expect(
            circles[i].labelRect.overlaps(circles[j].labelRect),
            isFalse,
            reason: 'Labels ${circles[i].name} and ${circles[j].name} overlapped',
          );
        }
      }
    }
  });
}
