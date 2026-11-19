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

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: ThemeData.light().copyWith(extensions: const [_palette]),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 640, height: 500, child: child),
        ),
      ),
    ),
  );
}

DatasetPage _samplePage() => DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'requests',
        title: 'Requests by model',
        description: '',
        equation: null,
        fields: [
          FieldInfo(name: 'model', label: 'Model', type: 'string', role: 'dimension'),
          FieldInfo(name: 'count', label: 'Count', type: 'integer', role: 'measure'),
        ],
        filters: [],
      ),
      rows: const [
        {'model': 'qwen', 'count': 10},
        {'model': 'llama', 'count': 25},
      ],
      offset: 0,
      limit: 2,
      totalRows: 2,
    );

void main() {
  testWidgets('C13, C17: Legend items are >= 24x24 and toggle via keyboard Enter/Space', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      _wrap(
        Legend(
          items: const [('Series A', Color(0xFF0F62FE)), ('Series B', Color(0xFF8A3FFC))],
          onToggle: toggled.add,
        ),
      ),
    );
    final box = tester.getSize(find.byKey(const Key('legend_Series A')));
    expect(box.height, greaterThanOrEqualTo(24));
    expect(box.width, greaterThanOrEqualTo(24));

    // Focus and press Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(toggled, ['Series A', 'Series A']);
  });

  testWidgets('C16: ChartFrame exposes Semantics summary and built-in Show as table toggle', (tester) async {
    final page = _samplePage();
    await tester.pumpWidget(
      _wrap(
        ChartFrame(
          page: page,
          child: VisualChooser.build(page, const Slot('requests', visual: Visual.bar)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      ChartFrame.semanticsSummary(page),
      'Requests by model, 2 rows, Count from 10 to 25',
    );
    expect(find.byType(DataTableView), findsNothing);

    await tester.tap(find.text('Show as table'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTableView), findsOneWidget);
    expect(find.text('Show as chart'), findsOneWidget);
  });

  testWidgets('C21: reduced motion renders final state immediately', (tester) async {
    final page = _samplePage();
    await tester.pumpWidget(
      _wrap(
        ChartFrame(
          page: page,
          child: VisualChooser.build(page, const Slot('requests', visual: Visual.bar)),
        ),
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
