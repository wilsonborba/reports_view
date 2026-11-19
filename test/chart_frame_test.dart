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

Widget _wrap(Widget child, {double width = 640, double height = 520}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [_palette]),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

DatasetPage _pageWithMeta({bool withMeta = true}) {
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'tokens-by-provider',
      title: 'Tokens by provider',
      description: 'Total tokens across model providers',
      equation: null,
      fields: const [
        FieldInfo(name: 'provider', label: 'Provider', type: 'string', role: 'dimension'),
        FieldInfo(name: 'tokens', label: 'Tokens', type: 'integer', role: 'measure', unit: 'tokens'),
      ],
      filters: const [],
      dataTier: withMeta ? 'real' : 'sample',
      meta: withMeta
          ? const DatasetMeta(
              source: 'Cortex Telemetry',
              sourceUrl: 'https://reports.example.com/sources/telemetry',
              periodStart: '2026-11-01',
              periodEnd: '2026-11-18',
              timezone: 'Asia/Bangkok',
              tier: 'real',
            )
          : null,
    ),
    rows: const [
      {'provider': 'ollama', 'tokens': 1200},
      {'provider': 'openai', 'tokens': 800},
    ],
    offset: 0,
    limit: 2,
    totalRows: 2,
    lineage: withMeta
        ? const Lineage(
            calculationId: 'tokens-by-provider',
            calculationVersion: 1,
            calculatedAt: '2026-11-18T12:00:00Z',
          )
        : null,
  );
}

void main() {
  testWidgets('C1, C2, C18, C22: frame shows title, subtitle, axis units, meta footer, and tier',
      (tester) async {
    final page = _pageWithMeta(withMeta: true);

    for (final visual in [Visual.bar, Visual.donut, Visual.table]) {
      await tester.pumpWidget(
        _wrap(
          ChartFrame(
            page: page,
            mode: ChartFrameMode.card,
            fixedHeight: 300,
            onSeeAll: () {},
            onToggleTable: () {},
            child: VisualChooser.build(page, Slot('tokens-by-provider', visual: visual)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tokens by provider'), findsOneWidget);
      expect(find.text('Total tokens across model providers'), findsOneWidget);
      expect(find.text('Provider'), findsAtLeastNWidgets(1));
      expect(find.text('Tokens (tokens)'), findsAtLeastNWidgets(1));
      expect(find.text('Source: Cortex Telemetry'), findsOneWidget);
      expect(find.text('Period: 2026-11-01 to 2026-11-18 (Asia/Bangkok)'), findsOneWidget);
      expect(find.text('Updated: 2026-11-18T12:00:00Z (Asia/Bangkok)'), findsOneWidget);
      expect(find.text('Real'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
    }
  });

  testWidgets('C18: missing metadata shows unavailable honestly and embed hides See all',
      (tester) async {
    final page = _pageWithMeta(withMeta: false);
    await tester.pumpWidget(
      _wrap(
        ChartFrame(
          page: page,
          mode: ChartFrameMode.embed,
          fixedHeight: 200,
          onSeeAll: () {},
          child: VisualChooser.build(page, const Slot('tokens-by-provider', visual: Visual.bar)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Source unavailable'), findsOneWidget);
    expect(find.text('Period unavailable'), findsOneWidget);
    expect(find.text('Last update unavailable'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('C19: loading, empty, restricted, error, and offline states render cleanly',
      (tester) async {
    final page = _pageWithMeta(withMeta: true);

    for (final entry in [
      (ChartFrameState.loading, 'Loading chart...'),
      (ChartFrameState.empty, 'No data for this period'),
      (ChartFrameState.restricted, 'Restricted chart'),
      (ChartFrameState.error, 'Could not load chart'),
    ]) {
      await tester.pumpWidget(
        _wrap(
          ChartFrame(
            page: page,
            state: entry.$1,
            fixedHeight: 180,
            onRetry: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text(entry.$2), findsOneWidget);
    }

    await tester.pumpWidget(
      _wrap(
        ChartFrame(
          page: page,
          state: ChartFrameState.offline,
          fixedHeight: 180,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Offline — last updated'), findsOneWidget);
  });
}
