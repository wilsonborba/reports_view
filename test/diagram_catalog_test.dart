import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/diagram_charts.dart';

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
  const diagramIds = <String>[
    'sankey',
    'alluvial',
    'chord',
    'arc_diagram',
    'flowchart',
    'layered_dag',
    'sequence_diagram',
    'state_diagram',
    'swimlane',
    'tree_org',
    'dendrogram',
    'mind_map',
    'network',
    'adjacency_matrix',
    'er_diagram',
    'architecture_diagram',
  ];

  final page = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'diag_ds',
      title: 'Diagram Fixture',
      description: 'Flow, process, and structure diagram fixture',
      equation: null,
      fields: const [
        FieldInfo(name: 'src', label: 'Source', type: 'string', role: 'dimension'),
        FieldInfo(name: 'dst', label: 'Target', type: 'string', role: 'dimension'),
        FieldInfo(name: 'grp', label: 'Group', type: 'string', role: 'dimension'),
        FieldInfo(name: 'val', label: 'Flow', type: 'float', role: 'measure', unit: 'req'),
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
      {'src': 'API', 'dst': 'Auth', 'grp': 'Edge', 'val': 120.0},
      {'src': 'API', 'dst': 'Store', 'grp': 'Edge', 'val': 85.0},
      {'src': 'Auth', 'dst': 'DB', 'grp': 'Core', 'val': 95.0},
      {'src': 'Store', 'dst': 'Cache', 'grp': 'Core', 'val': 60.0},
      {'src': 'Cache', 'dst': 'DB', 'grp': 'Data', 'val': 45.0},
      {'src': 'Worker', 'dst': 'DB', 'grp': 'Data', 'val': 30.0},
    ],
    offset: 0,
    limit: 6,
    totalRows: 6,
  );

  for (final id in diagramIds) {
    testWidgets('$id renders across EN, pt-BR, and TH', (tester) async {
      final tpl = VisualTemplate(
        templateId: id,
        version: 1,
        kind: 'diagram',
        visual: id,
        title: id,
        slots: const [
          TemplateSlot(
            slotName: 'source',
            role: 'dimension',
            minCount: 2,
            maxCount: 3,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: 1,
            acceptedTypes: ['float'],
          ),
        ],
      );
      final binding = CardVisualBinding(
        template: id,
        version: 1,
        mapping: const {
          'source': ['src', 'dst', 'grp'],
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

  test('diagram size limit D7 caps node count at maxNodes (12)', () {
    final manyRows = [
      for (var i = 0; i < 20; i++)
        {'src': 'N$i', 'dst': 'N${i + 1}', 'grp': 'G', 'val': 10.0 + i},
    ];
    final edges = DiagramCatalogChart.extractEdges(
      manyRows,
      const [
        FieldInfo(name: 'src', label: 'Source', type: 'string', role: 'dimension'),
        FieldInfo(name: 'dst', label: 'Target', type: 'string', role: 'dimension'),
      ],
      const FieldInfo(name: 'val', label: 'Flow', type: 'float', role: 'measure'),
    );
    final nodes = DiagramCatalogChart.collectNodes(edges);
    expect(nodes.length, DiagramCatalogChart.maxNodes);
  });
}
