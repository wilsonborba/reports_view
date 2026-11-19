import 'package:fl_chart/fl_chart.dart';
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

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(extensions: const [_palette]),
      home: Scaffold(body: Center(child: SizedBox(width: 600, height: 320, child: child))),
    );

void main() {
  test('measureValue respects missingMeans (no_data vs zero)', () {
    const noDataField = FieldInfo(
      name: 'latency',
      label: 'Latency',
      type: 'float',
      role: 'measure',
      missingMeans: 'no_data',
    );
    const zeroField = FieldInfo(
      name: 'events',
      label: 'Events',
      type: 'integer',
      role: 'measure',
      missingMeans: 'zero',
    );
    expect(measureValue(null, noDataField), isNull);
    expect(measureValue(0, noDataField), 0.0);
    expect(measureValue(-5.5, noDataField), -5.5);
    expect(measureValue(null, zeroField), 0.0);
    expect(measureValueWithUnit(null, noDataField), 'No data');
    expect(measureValueWithUnit(0, noDataField), '0');
  });

  testWidgets('C7, C8: line breaks at null (FlSpot.nullSpot) and bars render null, zero, and negative',
      (tester) async {
    final page = DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'metrics',
        title: 'Metrics',
        description: '',
        equation: null,
        fields: [
          FieldInfo(name: 'day', label: 'Day', type: 'date', role: 'dimension'),
          FieldInfo(name: 'delta', label: 'Delta', type: 'float', role: 'measure', missingMeans: 'no_data'),
        ],
        filters: [],
      ),
      rows: const [
        {'day': '2026-11-01', 'delta': 10},
        {'day': '2026-11-02', 'delta': null},
        {'day': '2026-11-03', 'delta': 0},
        {'day': '2026-11-04', 'delta': -8},
      ],
      offset: 0,
      limit: 4,
      totalRows: 4,
    );

    await tester.pumpWidget(
      _host(VisualChooser.build(page, const Slot('metrics', visual: Visual.line))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final lineWidget = tester.widget<LineChart>(find.byType(LineChart));
    final spots = lineWidget.data.lineBarsData.first.spots;
    expect(spots.length, 4);
    expect(spots[1], FlSpot.nullSpot);
    expect(spots[2].y, 0.0);
    expect(spots[3].y, -8.0);

    await tester.pumpWidget(
      _host(VisualChooser.build(page, const Slot('metrics', visual: Visual.bar))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final barWidget = tester.widget<BarChart>(find.byType(BarChart));
    expect(barWidget.data.minY, -8.0);
    expect(barWidget.data.barGroups[1].barRods, isEmpty);
    expect(barWidget.data.barGroups[2].barRods.single.toY, 0.0);
    expect(barWidget.data.barGroups[3].barRods.single.toY, -8.0);
  });
}
