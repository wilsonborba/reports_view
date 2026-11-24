import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/diagram_charts.dart';
import 'package:reports_view/src/charts/geo_charts.dart';
import 'package:reports_view/src/charts/relation_charts.dart';
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

DatasetPage _dataset(String id, String dimName, String dimType, bool variantB) {
  final isCoordGeo =
      id.startsWith('bubble_map') ||
      id.startsWith('geo_heatmap') ||
      id.startsWith('flow_map');
  final isIsoGeo = id.startsWith('choropleth') || id.startsWith('hex_tile_map');
  const isoCodes = [
    'TH-10',
    'TH-50',
    'TH-83',
    'TH-40',
    'BR-SP',
    'BR-RJ',
    'BR-MG',
    'BR-BA',
  ];
  const coords = [
    (13.75, 100.50),
    (18.79, 98.98),
    (7.88, 98.39),
    (16.43, 102.82),
    (-23.55, -46.63),
    (-22.91, -43.17),
    (-19.92, -43.94),
    (-12.97, -38.51),
  ];
  final isScienceProb = id.startsWith('roc_pr') || id.startsWith('calibration');
  final isIrt = id.startsWith('irt_') || id.startsWith('item_diff_disc');
  final rows = [
    for (var i = 0; i < 8; i++)
      {
        dimName: dimType == 'date'
            ? '2026-01-${(i + 1).toString().padLeft(2, '0')}'
            : (isIsoGeo
                  ? isoCodes[i]
                  : (dimName == 'group' ? 'G${(i % 2) + 1}' : 'Cat ${i + 1}')),
        if (dimName != 'group') 'group': 'G${(i % 2) + 1}',
        if (isCoordGeo) 'lat': coords[i].$1,
        if (isCoordGeo) 'lon': coords[i].$2,
        'v1': isScienceProb
            ? (variantB ? (0.95 - i * 0.11) : (0.12 + i * 0.11))
            : isIrt
            ? (variantB ? (-1.5 + i * 0.45) : (1.5 - i * 0.4))
            : (variantB ? (10 + i * i * 3) : (10 + i * 10)),
        'v2': isScienceProb
            ? (variantB ? (i < 5 ? 1 : 0) : (i >= 4 ? 1 : 0))
            : isIrt
            ? (variantB ? (0.8 + i * 0.2) : (2.2 - i * 0.15))
            : (variantB ? (40 + (i % 3) * 25 - i * 2) : (85 - i * 8)),
        'v3': variantB ? (15 + (i % 2) * 40 + i * 3) : (60 - (i % 4) * 12),
      },
  ];
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: id,
      title: id,
      description: 'Data sensitivity fixture',
      equation: null,
      fields: [
        FieldInfo(
          name: dimName,
          label: 'Dim',
          type: dimType,
          role: 'dimension',
        ),
        if (isCoordGeo)
          const FieldInfo(
            name: 'lat',
            label: 'Lat',
            type: 'latitude',
            role: 'dimension',
          ),
        if (isCoordGeo)
          const FieldInfo(
            name: 'lon',
            label: 'Lon',
            type: 'longitude',
            role: 'dimension',
          ),
        if (dimName != 'group')
          const FieldInfo(
            name: 'group',
            label: 'Group',
            type: 'string',
            role: 'dimension',
          ),
        FieldInfo(
          name: 'v1',
          label: 'V1',
          type: isScienceProb ? 'float' : 'integer',
          role: 'measure',
          unit: isScienceProb ? 'p' : 'pts',
        ),
        const FieldInfo(
          name: 'v2',
          label: 'V2',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        const FieldInfo(
          name: 'v3',
          label: 'V3',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
      meta: const DatasetMeta(
        source: 'Fixture',
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
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

Future<List<int>> _capturePng(
  WidgetTester tester, {
  required String id,
  required DatasetPage page,
  required String dimSlot,
  required String dimType,
  required String dimField,
  required int dimCount,
  required int measureCount,
}) async {
  final tpl = VisualTemplate(
    templateId: id,
    version: 1,
    kind: 'chart',
    visual: id,
    title: id,
    slots: [
      TemplateSlot(
        slotName: dimSlot,
        role: 'dimension',
        minCount: dimCount,
        maxCount: dimCount,
        acceptedTypes: [dimType],
      ),
      TemplateSlot(
        slotName: 'value',
        role: 'measure',
        minCount: measureCount,
        maxCount: measureCount,
        acceptedTypes: const ['integer', 'float'],
      ),
    ],
  );
  final binding = CardVisualBinding(
    template: id,
    version: 1,
    mapping: {
      dimSlot: dimCount == 2 ? [dimField, 'group'] : [dimField],
      'value': measureCount == 3
          ? ['v1', 'v2', 'v3']
          : (measureCount == 2 ? ['v1', 'v2'] : ['v1']),
    },
  );
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: _palette.toTheme(Brightness.light),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: SizedBox(
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
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 1.0);
    return img.toByteData(format: ui.ImageByteFormat.png);
  });
  return bytes!.buffer.asUint8List();
}

void main() {
  const comparisonIds = [
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
  const twoMeasureComparison = {
    'grouped_bar',
    'stacked_bar',
    'stacked_bar_100',
    'diverging_bar',
    'floating_bar',
    'dumbbell',
    'slope',
    'bullet',
    'utilization_bar',
    'parallel_coordinates',
    'marimekko',
  };
  const timeIds = [
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
  const twoMeasureTime = {
    'stacked_area',
    'stacked_area_100',
    'streamgraph',
    'candlestick',
    'range_band',
    'combo',
    'gantt',
  };
  const partWholeIds = [
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
  const distIds = [
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
  const relationIds = [
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
  const diagramIds = [
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
  const setsIds = ['venn', 'euler', 'upset'];
  const geoIds = [
    'bubble_map',
    'choropleth',
    'geo_heatmap',
    'flow_map',
    'hex_tile_map',
  ];
  const indicatorIds = [
    'kpi_sparkline',
    'heat_table',
    'status_scorecard',
    'word_cloud',
  ];
  const scienceIds = [
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

  final specs = <(String, String, String, String, int, int)>[
    for (final id in comparisonIds)
      (
        id,
        'category',
        'string',
        'cat',
        id == 'stacked_bar' ? 2 : 1,
        twoMeasureComparison.contains(id) ? 2 : 1,
      ),
    for (final id in timeIds)
      (id, 'time', 'date', 'day', 1, twoMeasureTime.contains(id) ? 2 : 1),
    for (final id in partWholeIds) (id, 'part', 'string', 'part', 1, 1),
    for (final id in distIds)
      (id, 'category', 'string', id == 'ridgeline' ? 'group' : 'cohort', 1, 1),
    for (final id in relationIds)
      (id, 'category', 'string', 'item', 1, id == 'ternary' ? 3 : 2),
    for (final id in diagramIds)
      (id, 'category', 'string', 'item', id == 'sankey' ? 2 : 1, 1),
    for (final id in setsIds) (id, 'category', 'string', 'item', 1, 1),
    for (final id in geoIds) (id, 'category', 'string', 'item', 1, 1),
    for (final id in indicatorIds) (id, 'category', 'string', 'item', 1, 1),
    for (final id in scienceIds)
      (id, 'category', 'string', 'item', 1, id == 'top_k_prob' ? 1 : 2),
  ];

  for (final (id, dimSlot, dimType, dimField, dCount, mCount) in specs) {
    testWidgets('data sensitivity: $id changes output when rows change', (
      tester,
    ) async {
      final pA = _dataset('${id}_a', dimField, dimType, false);
      final pB = _dataset('${id}_b', dimField, dimType, true);
      final bytesA = await _capturePng(
        tester,
        id: id,
        page: pA,
        dimSlot: dimSlot,
        dimType: dimType,
        dimField: dimField,
        dimCount: dCount,
        measureCount: mCount,
      );
      final bytesB = await _capturePng(
        tester,
        id: id,
        page: pB,
        dimSlot: dimSlot,
        dimType: dimType,
        dimField: dimField,
        dimCount: dCount,
        measureCount: mCount,
      );
      expect(
        bytesA,
        isNot(equals(bytesB)),
        reason: '$id produced identical pixels for two different datasets',
      );
    });
  }

  test(
    'semantic: correlation_matrix computes exact Pearson r (1.0 and -1.0)',
    () {
      final rows = [
        {'v1': 1.0, 'v2': 2.0, 'v3': -2.0},
        {'v1': 2.0, 'v2': 4.0, 'v3': -4.0},
        {'v1': 3.0, 'v2': 6.0, 'v3': -6.0},
        {'v1': 4.0, 'v2': 8.0, 'v3': -8.0},
      ];
      final m = RelationCatalogChart.computeCorrelationMatrix(rows, [
        'v1',
        'v2',
        'v3',
      ]);
      expect(m[0][1], closeTo(1.0, 1e-6));
      expect(m[0][2], closeTo(-1.0, 1e-6));
    },
  );

  test('semantic: hexbin counts sum to total points', () {
    final pts = [(0.1, 0.1), (0.15, 0.12), (0.8, 0.9), (0.5, 0.5), (0.9, 0.2)];
    final bins = RelationCatalogChart.computeHexbinCounts(
      pts,
      cols: 6,
      rows: 4,
    );
    final sum = bins.values.fold<int>(0, (a, b) => a + b);
    expect(sum, pts.length);
  });

  test('semantic: contour_2d peak lies in the densest cluster', () {
    final pts = [
      (0.8, 0.8),
      (0.82, 0.79),
      (0.79, 0.81),
      (0.81, 0.82),
      (0.1, 0.1),
    ];
    final peak = RelationCatalogChart.computeDensityPeak(pts, grid: 16);
    expect(peak.$1, greaterThan(0.65));
    expect(peak.$2, greaterThan(0.65));
  });

  test('semantic: splom cell (r, c) maps row to scaled (x_c, y_r)', () {
    final rows = [
      {'v1': 0.0, 'v2': 10.0, 'v3': 100.0},
      {'v1': 50.0, 'v2': 20.0, 'v3': 200.0},
      {'v1': 100.0, 'v2': 30.0, 'v3': 300.0},
    ];
    final pts = RelationCatalogChart.computeSplomCellPoints(rows, 'v2', 'v1');
    expect(pts.first.$1, closeTo(0.0, 1e-6));
    expect(pts.first.$2, closeTo(0.0, 1e-6));
    expect(pts.last.$1, closeTo(1.0, 1e-6));
    expect(pts.last.$2, closeTo(1.0, 1e-6));
  });

  test('semantic: ternary with two measures does not repeat corner labels', () {
    const a = FieldInfo(
      name: 'v1',
      label: 'V1',
      type: 'integer',
      role: 'measure',
    );
    const b = FieldInfo(
      name: 'v2',
      label: 'V2',
      type: 'integer',
      role: 'measure',
    );
    const c = FieldInfo(
      name: 'v3',
      label: 'V3',
      type: 'integer',
      role: 'measure',
    );
    final two = RelationCatalogChart.ternaryCornerLabels(a, b, null);
    expect(two.toSet().length, 3);
    expect(two, ['V1', 'V2', 'Other']);
    final dup = RelationCatalogChart.ternaryCornerLabels(a, b, b);
    expect(dup.toSet().length, 3);
    expect(dup, ['V1', 'V2', 'Other']);
    final three = RelationCatalogChart.ternaryCornerLabels(a, b, c);
    expect(three, ['V1', 'V2', 'V3']);
  });

  test(
    'semantic: diagram adjacency matrix, layered DAG, and network positions',
    () {
      const edges = [
        DiagramEdge(source: 'A', target: 'B', group: 'G1', value: 10),
        DiagramEdge(source: 'B', target: 'C', group: 'G1', value: 5),
        DiagramEdge(source: 'A', target: 'C', group: 'G2', value: 3),
      ];
      final nodes = DiagramCatalogChart.collectNodes(edges);
      expect(nodes, ['A', 'B', 'C']);

      final mat = DiagramCatalogChart.computeAdjacencyMatrix(nodes, edges);
      expect(mat[0][1], 10);
      expect(mat[1][2], 5);
      expect(mat[0][2], 3);
      expect(mat[2][0], 0);

      final layers = DiagramCatalogChart.computeLayeredOrder(nodes, edges);
      expect(layers['A'], 0);
      expect(layers['B'], greaterThan(layers['A']!));
      expect(layers['C'], greaterThan(layers['B']!));

      // Branch + merge DAG: leaf D must sit deeper than both parents B and C.
      const branchEdges = [
        DiagramEdge(source: 'Start', target: 'B', group: 'L1', value: 10),
        DiagramEdge(source: 'Start', target: 'C', group: 'L1', value: 10),
        DiagramEdge(source: 'B', target: 'Merge', group: 'L2', value: 5),
        DiagramEdge(source: 'C', target: 'Merge', group: 'L2', value: 5),
        DiagramEdge(source: 'Merge', target: 'End', group: 'L3', value: 10),
      ];
      final bNodes = DiagramCatalogChart.collectNodes(branchEdges);
      final bLayers = DiagramCatalogChart.computeLayeredOrder(
        bNodes,
        branchEdges,
      );
      expect(bLayers['Merge']!, greaterThan(bLayers['B']!));
      expect(bLayers['Merge']!, greaterThan(bLayers['C']!));
      expect(bLayers['End']!, greaterThan(bLayers['Merge']!));

      final netPos = DiagramCatalogChart.computeNetworkPositions(nodes, edges);
      expect(netPos.keys, containsAll(['A', 'B', 'C']));
      for (final p in netPos.values) {
        expect(p.dx, inInclusiveRange(0.0, 1.0));
        expect(p.dy, inInclusiveRange(0.0, 1.0));
      }
    },
  );

  test('semantic: sets intersection parsing and totals', () {
    final intersections = SetsCatalogChart.extractIntersections(
      const [
        {'s': 'A', 'v': 10},
        {'s': 'A & B', 'v': 5},
        {'s': 'B', 'v': 20},
      ],
      const FieldInfo(
        name: 's',
        label: 'Sets',
        type: 'string',
        role: 'dimension',
      ),
      const FieldInfo(
        name: 'v',
        label: 'Count',
        type: 'integer',
        role: 'measure',
      ),
    );
    final totals = SetsCatalogChart.computeSetTotals(intersections);
    expect(totals['A'], 15);
    expect(totals['B'], 25);
  });

  test('semantic: geo projection and heatmap grid binning', () {
    const pts = [
      GeoPointDatum(label: 'SW', lat: -10, lon: -20, value: 10),
      GeoPointDatum(label: 'NE', lat: 10, lon: 20, value: 40),
    ];
    final norm = GeoCatalogChart.projectPoints(pts);
    expect(norm[0].dx, closeTo(0.0, 1e-6));
    expect(norm[0].dy, closeTo(1.0, 1e-6));
    expect(norm[1].dx, closeTo(1.0, 1e-6));
    expect(norm[1].dy, closeTo(0.0, 1e-6));

    final grid = GeoCatalogChart.computeGeoHeatmapGrid(pts, grid: 4);
    expect(grid[3][0], 10);
    expect(grid[0][3], 40);
  });
}
