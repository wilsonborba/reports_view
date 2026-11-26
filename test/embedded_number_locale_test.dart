import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/comparison_charts.dart';
import 'package:reports_view/src/charts/distribution_charts.dart';
import 'package:reports_view/src/charts/part_whole_charts.dart';
import 'package:reports_view/src/charts/time_charts.dart';

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
  series: [Color(0xFF0F62FE)],
);

final _page = DatasetPage(
  descriptor: const DatasetDescriptor(
    datasetId: 'locale-numbers',
    title: 'Locale numbers',
    description: '',
    equation: null,
    fields: [
      FieldInfo(
        name: 'category',
        label: 'Category',
        type: 'string',
        role: 'dimension',
      ),
      FieldInfo(
        name: 'score',
        label: 'Score',
        type: 'float',
        role: 'measure',
        decimals: 1,
      ),
      FieldInfo(
        name: 'amount',
        label: 'Amount',
        type: 'float',
        role: 'measure',
        decimals: 1,
      ),
    ],
    filters: [],
  ),
  rows: const [
    {'category': 'A', 'score': 0.2, 'amount': 1234.5},
    {'category': 'B', 'score': 0.8, 'amount': 2345.6},
    {'category': 'C', 'score': 1.4, 'amount': 3456.7},
  ],
  offset: 0,
  limit: 3,
  totalRows: 3,
);

const _measure = FieldInfo(
  name: 'score',
  label: 'Score',
  type: 'float',
  role: 'measure',
  decimals: 1,
);

Widget _chart() => SizedBox(
  height: 450,
  child: ChartFrame(
    page: _page,
    mode: ChartFrameMode.embed,
    fixedHeight: 450,
    enableTableToggle: false,
    child: SeriesLineChart(
      page: _page,
      x: const FieldInfo(
        name: 'category',
        label: 'Category',
        type: 'string',
        role: 'dimension',
      ),
      measures: const [_measure],
    ),
  ),
);

Widget _table() => SizedBox(height: 160, child: DataTableView(page: _page));

Widget _sparkline() {
  final page = DatasetPage(
    descriptor: const DatasetDescriptor(
      datasetId: 'sparkline-locale',
      title: 'Sparkline locale',
      description: '',
      equation: null,
      fields: [
        FieldInfo(name: 'day', label: 'Day', type: 'string', role: 'dimension'),
        FieldInfo(
          name: 'users',
          label: 'Users',
          type: 'integer',
          role: 'measure',
        ),
      ],
      filters: [],
    ),
    rows: const [
      {'day': 'D1', 'users': 1120},
      {'day': 'D2', 'users': 1185},
    ],
    offset: 0,
    limit: 2,
    totalRows: 2,
  );
  return VisualChooser.build(
    page,
    const Slot('sparkline', visual: Visual.kpiSparkline),
  );
}

Widget _localized(Locale locale, Widget child) => Localizations(
  locale: locale,
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: child,
);

Widget _app({required Widget child}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('en')],
  theme: ThemeData.light().copyWith(extensions: const [_palette]),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('numeric category labels use the host locale across catalogs', (
    tester,
  ) async {
    const dimension = FieldInfo(
      name: 'amount',
      label: 'Amount',
      type: 'float',
      role: 'dimension',
      decimals: 1,
    );
    final page = DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'numeric-category',
        title: 'Numeric categories',
        description: '',
        equation: null,
        fields: [dimension, _measure],
        filters: [],
      ),
      rows: const [
        {'amount': 1234.5, 'score': 0.2},
      ],
      offset: 0,
      limit: 1,
      totalRows: 1,
    );
    final charts = <Widget>[
      for (final visual in [
        Visual.groupedBar,
        Visual.stackedBar100,
        Visual.divergingBar,
        Visual.floatingBar,
        Visual.lollipop,
        Visual.dotPlot,
        Visual.dumbbell,
        Visual.bullet,
        Visual.pictogram,
        Visual.marimekko,
        Visual.waterfall,
      ])
        ComparisonCatalogChart(
          page: page,
          visual: visual,
          dimension: dimension,
          measures: const [_measure],
        ),
      for (final visual in [Visual.meter, Visual.icicle, Visual.funnel])
        PartWholeCatalogChart(
          page: page,
          visual: visual,
          label: dimension,
          value: _measure,
        ),
      for (final visual in [Visual.gantt, Visual.timeline])
        TimeCatalogChart(
          page: page,
          visual: visual,
          x: dimension,
          measures: const [_measure],
        ),
    ];
    for (final chart in charts) {
      await tester.pumpWidget(
        _app(child: _localized(const Locale('pt', 'BR'), chart)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('1.234,5'),
        findsWidgets,
        reason: '${chart.runtimeType} must localize numeric category labels',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('comparison values use the host locale in every helper', (
    tester,
  ) async {
    final amount = _page.descriptor.fields.last;
    for (final visual in [Visual.lollipop, Visual.dotPlot, Visual.pictogram]) {
      for (final locale in const [
        Locale('en'),
        Locale('pt', 'BR'),
        Locale('th'),
      ]) {
        await tester.pumpWidget(
          _app(
            child: _localized(
              locale,
              ComparisonCatalogChart(
                page: _page,
                visual: visual,
                dimension: _page.descriptor.fields.first,
                measures: [amount],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(locale.languageCode == 'pt' ? '1.234,5' : '1,234.5'),
          findsOneWidget,
          reason: '${visual.name} must use the actual host locale $locale',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('distribution repaints after a locale-only host update', (
    tester,
  ) async {
    Future<CustomPainter> show(Locale locale) async {
      await tester.pumpWidget(
        _app(
          child: _localized(
            locale,
            DistributionCatalogChart(
              page: _page,
              visual: Visual.histogram,
              label: _page.descriptor.fields.first,
              value: _measure,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(DistributionCatalogChart),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
    }

    final original = await show(const Locale('en'));
    final unchanged = await show(const Locale('en'));
    expect(unchanged.shouldRepaint(original), isFalse);
    final portuguese = await show(const Locale('pt', 'BR'));
    expect(portuguese.shouldRepaint(unchanged), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('explicit host formatting keeps the export zone fallback intact', () {
    expect(withNumberLanguage('pt-BR', () => numberText(1234.5, 1)), '1.234,5');
    expect(numberText(-1, 1, language: 'pt-BR'), '-1,0');
    expect(numberText(1, 1, language: 'pt-BR'), '1,0');
    expect(
      withNumberLanguage('pt-BR', () => numberText(1234.5, 1, language: 'en')),
      '1,234.5',
    );
  });

  testWidgets('axis, tooltip and numeric table follow a changing host locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> show(Locale locale) async {
      await tester.pumpWidget(
        _app(
          child: _localized(
            locale,
            Column(
              children: [
                Expanded(child: _chart()),
                _table(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const Locale('en'));
    expect(find.text('0.2'), findsWidgets);
    expect(find.text('1,234.5'), findsOneWidget);

    final chart = find.byType(SeriesLineChart);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.moveTo(tester.getCenter(chart));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.8'), findsWidgets);

    await show(const Locale('pt', 'BR'));
    expect(find.text('0,2'), findsWidgets);
    expect(find.text('1.234,5'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(chart));
    await tester.pumpAndSettle();
    expect(find.textContaining('0,8'), findsWidgets);

    await show(const Locale('th'));
    expect(find.text('0.2'), findsWidgets);
    expect(find.text('1,234.5'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(chart));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.8'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separate localized subtrees do not share number formatting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        child: Builder(
          builder: (context) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final locale in const [
                Locale('en'),
                Locale('pt', 'BR'),
                Locale('th'),
              ])
                Expanded(
                  child: _localized(
                    locale,
                    Column(children: [_chart(), _table()]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1,234.5'), findsNWidgets(2));
    expect(find.text('1.234,5'), findsOneWidget);
    expect(find.text('0.2'), findsWidgets);
    expect(find.text('0,2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculated KPI percentage uses the host decimal separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        child: _localized(
          const Locale('pt', 'BR'),
          SizedBox(width: 440, height: 180, child: _sparkline()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+5,8%'), findsOneWidget);
    expect(find.text('+5.8%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
