import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<ByteData> _font(String file) async => ByteData.sublistView(
  Uint8List.fromList(await File('test/fonts/$file').readAsBytes()),
);

/// Loads real Ubuntu Sans, Ubuntu Sans Mono, and IBM Plex Sans Thai fonts
/// so EN, pt-BR, and TH glyphs render clearly in golden images.
Future<void> _loadReportsFonts() async {
  await (FontLoader(ReportPalette.font)
        ..addFont(_font('UbuntuSans-Variable.ttf'))
        ..addFont(_font('UbuntuSans-Italic-Variable.ttf')))
      .load();
  await (FontLoader(ReportPalette.thaiFont)
        ..addFont(_font('IBMPlexSansThai-Regular.ttf'))
        ..addFont(_font('IBMPlexSansThai-SemiBold.ttf')))
      .load();
  await (FontLoader(ReportPalette.monoFont)
        ..addFont(_font('UbuntuSansMono-Variable.ttf')))
      .load();
}

String _localizedCategory(String lang, int index) {
  return switch (lang) {
    'pt-BR' => [
      'Ação Principal',
      'Produção Regional',
      'Educação Básica',
      'Saúde Pública',
      'Gestão Financeira',
      'Serviços Digitais',
      'Relatório Anual',
      'Meta Mensal',
    ][index % 8],
    'th' => [
      'หมวดหมู่หลัก ก',
      'การประเมินผลรวม',
      'ข้อมูลเชิงสถิติ',
      'ประสิทธิภาพระบบ',
      'สัดส่วนผู้ใช้งาน',
      'แนวโน้มรายเดือน',
      'เกณฑ์มาตรฐานกลาง',
      'สรุปรายงานประจำปี',
    ][index % 8],
    _ => [
      'Core Alpha',
      'Regional Output',
      'Primary Service',
      'System Metrics',
      'User Cohort',
      'Monthly Trend',
      'Baseline Target',
      'Annual Summary',
    ][index % 8],
  };
}

String _localizedTitle(String lang, String id) {
  return switch (lang) {
    'pt-BR' => 'Gráfico $id (pt-BR)',
    'th' => 'แผนภูมิ $id (ภาษาไทย)',
    _ => 'Chart $id (EN)',
  };
}

DatasetPage _makePage(
  String id,
  String dimName,
  String dimType,
  int count, {
  String lang = 'en',
}) {
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: id,
      title: _localizedTitle(lang, id),
      description: 'Catalog golden fixture',
      equation: null,
      fields: [
        FieldInfo(
          name: dimName,
          label: switch (lang) {
            'pt-BR' => 'Categoria',
            'th' => 'หมวดหมู่',
            _ => 'Category',
          },
          type: dimType,
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: switch (lang) {
            'pt-BR' => 'Principal',
            'th' => 'ค่าหลัก',
            _ => 'Primary',
          },
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'v2',
          label: switch (lang) {
            'pt-BR' => 'Secundário',
            'th' => 'ค่ารอง',
            _ => 'Secondary',
          },
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
    rows: [
      for (var i = 0; i < count; i++)
        {
          dimName: dimType == 'date'
              ? '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}'
              : _localizedCategory(lang, i),
          'v1': 20 + (i * 17) % 80,
          'v2': 15 + (i * 11) % 60,
        },
    ],
    offset: 0,
    limit: count,
    totalRows: count,
  );
}

Future<void> _pumpAndGolden(
  WidgetTester tester, {
  required String group,
  required String id,
  required String dimSlot,
  required String dimType,
  required String dimField,
  required int count,
  required bool twoMeasures,
}) async {
  for (final locale in const [
    Locale('en'),
    Locale('pt', 'BR'),
    Locale('th'),
  ]) {
    final tag = locale.toLanguageTag();
    final page = _makePage('${group}_$id', dimField, dimType, count, lang: tag);
    final tpl = VisualTemplate(
      templateId: id,
      version: 1,
      kind: 'chart',
      visual: id,
      title: _localizedTitle(tag, id),
      slots: [
        TemplateSlot(
          slotName: dimSlot,
          role: 'dimension',
          minCount: 1,
          maxCount: 1,
          acceptedTypes: [dimType],
        ),
        TemplateSlot(
          slotName: 'value',
          role: 'measure',
          minCount: twoMeasures ? 2 : 1,
          maxCount: twoMeasures ? 2 : 1,
          acceptedTypes: const ['integer', 'float'],
        ),
      ],
    );
    final binding = CardVisualBinding(
      template: id,
      version: 1,
      mapping: {
        dimSlot: [dimField],
        'value': twoMeasures ? ['v1', 'v2'] : ['v1'],
      },
    );
    final key = UniqueKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: _palette.toTheme(Brightness.light),
        home: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale,
            child: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 480,
                  height: 360,
                  child: SingleChildScrollView(
                    child: VisualChooser.buildTemplate(
                      page: page,
                      template: tpl,
                      binding: binding,
                      title: _localizedTitle(tag, id),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/$group/${id}_$tag.png'),
    );
  }
}

void main() {
  setUpAll(_loadReportsFonts);

  const comparisonIds = [
    'vertical_bar', 'horizontal_bar', 'ranking_bar', 'grouped_bar',
    'stacked_bar', 'stacked_bar_100', 'diverging_bar', 'floating_bar',
    'lollipop', 'dot_plot', 'dumbbell', 'slope', 'bullet', 'utilization_bar',
    'pictogram', 'radial_bar', 'circular_bar', 'radar',
    'parallel_coordinates', 'marimekko', 'waterfall', 'pareto',
    'small_multiples',
  ];
  const twoMeasureComparison = {
    'grouped_bar', 'stacked_bar', 'stacked_bar_100', 'diverging_bar',
    'floating_bar', 'dumbbell', 'slope', 'bullet', 'utilization_bar',
    'parallel_coordinates', 'marimekko',
  };

  const timeIds = [
    'line', 'step_line', 'area', 'stacked_area', 'stacked_area_100',
    'streamgraph', 'sparkline', 'bump_chart', 'candlestick', 'range_band',
    'combo', 'annotated_line', 'timeline', 'gantt', 'calendar_heatmap',
    'horizon', 'control_chart', 'burndown', 'cycle_plot', 'curve',
  ];
  const twoMeasureTime = {
    'stacked_area', 'stacked_area_100', 'streamgraph', 'candlestick',
    'range_band', 'combo', 'gantt',
  };

  const partWholeIds = [
    'donut', 'pie', 'gauge', 'meter', 'treemap', 'sunburst', 'icicle',
    'circle_packing', 'waffle', 'nightingale_rose', 'funnel',
  ];

  const distIds = [
    'histogram', 'box_plot', 'violin', 'density', 'ridgeline', 'strip',
    'ecdf', 'qq_plot', 'population_pyramid', 'raincloud',
  ];

  for (final id in comparisonIds) {
    testWidgets('golden comparison/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'comparison',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cat',
        count: 6,
        twoMeasures: twoMeasureComparison.contains(id),
      );
    });
  }

  for (final id in timeIds) {
    testWidgets('golden time/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'time',
        id: id,
        dimSlot: 'time',
        dimType: 'date',
        dimField: 'day',
        count: 8,
        twoMeasures: twoMeasureTime.contains(id),
      );
    });
  }

  for (final id in partWholeIds) {
    testWidgets('golden part_whole/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'part_whole',
        id: id,
        dimSlot: 'part',
        dimType: 'string',
        dimField: 'part',
        count: 5,
        twoMeasures: false,
      );
    });
  }

  for (final id in distIds) {
    testWidgets('golden distribution/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'distribution',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cohort',
        count: 8,
        twoMeasures: false,
      );
    });
  }

  testWidgets('size limits measurement across 10, 50, 200, 500 rows', (
    tester,
  ) async {
    for (final n in [10, 50, 200, 500]) {
      final p = _makePage('bench_$n', 'cat', 'string', n);
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 360,
              child: Column(
                children: [
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.treemap),
                    ),
                  ),
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.streamgraph),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      sw.stop();
      // ignore: avoid_print
      print('SIZE_LIMIT_ROWS=$n RENDER_MS=${sw.elapsedMilliseconds}');
      expect(tester.takeException(), isNull);
    }
  });
}
