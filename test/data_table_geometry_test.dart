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
  negative: Color(0xFFDA1B28),
  info: Color(0xFF0043CE),
  caution: Color(0xFFFF832B),
  series: [Color(0xFF0F62FE)],
);

final _page = DatasetPage(
  descriptor: const DatasetDescriptor(
    datasetId: 'language_sizes',
    title: 'Language sizes',
    description: '',
    equation: null,
    fields: [
      FieldInfo(
        name: 'language',
        label: 'Programming language and runtime',
        type: 'string',
        role: 'dimension',
      ),
      FieldInfo(
        name: 'bytes',
        label: 'Bytes',
        type: 'integer',
        role: 'measure',
      ),
      FieldInfo(
        name: 'share',
        label: 'Share',
        type: 'percent',
        role: 'measure',
      ),
    ],
    filters: [],
  ),
  rows: const [
    {'language': 'Kotlin/JVM', 'bytes': 820123, 'share': 68.3},
  ],
  offset: 0,
  limit: 1,
  totalRows: 1,
);

Widget _host(double width) => MaterialApp(
  theme: ThemeData.light().copyWith(extensions: const [_palette]),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: 180,
        child: DataTableView(page: _page),
      ),
    ),
  ),
);

void main() {
  testWidgets('expanded headers share column boundaries with body values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(1000));

    final headerRight = tester.getTopRight(find.text('Bytes')).dx;
    final valueRight = tester.getTopRight(find.text('820,123')).dx;
    expect(
      valueRight,
      closeTo(headerRight, 1),
      reason: 'the bytes header and value must end at the same column boundary',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow tables keep aligned columns and horizontal scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(320));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final headerRight = tester.getTopRight(find.text('Bytes')).dx;
    final valueRight = tester.getTopRight(find.text('820,123')).dx;
    expect(valueRight, closeTo(headerRight, 1));
    expect(tester.takeException(), isNull);
  });
}
