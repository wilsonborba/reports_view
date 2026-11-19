import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

DatasetPage _samplePage({
  String datasetId = 'sample',
  required List<FieldInfo> fields,
  required List<Map<String, dynamic>> rows,
}) {
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: datasetId,
      title: 'Sample',
      description: '',
      equation: null,
      fields: fields,
      filters: const [],
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

const _testPalette = ReportPalette(
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
    Color(0xFF007D79),
    Color(0xFFEE5396),
    Color(0xFFFF832B),
    Color(0xFF198038),
    Color(0xFF0043CE),
    Color(0xFFFA4D56),
  ],
  other: Color(0xFF8D8D8D),
  highlight: Color(0xFF0F62FE),
);

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [_testPalette]),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 600, height: 320, child: child),
      ),
    ),
  );
}

void main() {
  test('ReportsLinkBuilder builds report and card URIs from caller baseUri', () {
    final builder = ReportsLinkBuilder(Uri.parse('https://reports.example.com/v1'));
    expect(
      builder.reportUri(project: 'proj', report: 'rep', lang: 'en').toString(),
      'https://reports.example.com/v1/projects/proj/reports/rep?lang=en',
    );
    expect(
      builder.cardUri(project: 'proj', report: 'rep', cardId: 'card').toString(),
      'https://reports.example.com/v1/menu/proj/rep/card',
    );
  });

  testWidgets('VisualChooser renders bar, donut, kpi, and table without layout errors', (tester) async {
    final page = _samplePage(
      fields: const [
        FieldInfo(name: 'category', label: 'Category', type: 'string', role: 'dimension'),
        FieldInfo(name: 'value', label: 'Value', type: 'integer', role: 'measure'),
      ],
      rows: const [
        {'category': 'Alpha', 'value': 10},
        {'category': 'Beta', 'value': 25},
        {'category': 'Gamma', 'value': 15},
      ],
    );

    for (final visual in [Visual.bar, Visual.donut, Visual.table]) {
      await tester.pumpWidget(_host(VisualChooser.build(page, Slot('sample', visual: visual))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
