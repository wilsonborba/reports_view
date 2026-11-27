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
  series: [Color(0xFF0F62FE), Color(0xFF8A3FFC)],
);

const _template = VisualTemplate(
  templateId: 'regional-monthly-sales',
  version: 1,
  kind: 'chart',
  visual: 'bar',
  title: 'Monthly sales',
  slots: [
    TemplateSlot(
      slotName: 'category',
      role: 'dimension',
      acceptedTypes: ['string'],
    ),
    TemplateSlot(
      slotName: 'region',
      role: 'dimension',
      acceptedTypes: ['string'],
    ),
    TemplateSlot(
      slotName: 'sales',
      role: 'measure',
      acceptedTypes: ['integer'],
    ),
  ],
);

DatasetPage _page() => DatasetPage(
  descriptor: DatasetDescriptor(
    datasetId: 'sales',
    title: 'Sales',
    description: '',
    equation: null,
    fields: const [
      FieldInfo(
        name: 'region',
        label: 'Region',
        type: 'string',
        role: 'dimension',
      ),
      FieldInfo(
        name: 'month',
        label: 'Month',
        type: 'string',
        role: 'dimension',
      ),
      FieldInfo(
        name: 'sales',
        label: 'Sales',
        type: 'integer',
        role: 'measure',
      ),
    ],
    filters: const [],
  ),
  rows: const [
    {'region': 'North', 'month': 'Jan', 'sales': 12},
    {'region': 'South', 'month': 'Feb', 'sales': 18},
  ],
  offset: 0,
  limit: 10,
  totalRows: 2,
  visual: const CardVisualBinding(
    template: 'regional-monthly-sales',
    version: 1,
    mapping: {
      'category': ['month'],
      'region': ['region'],
      'sales': ['sales'],
    },
  ),
);

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.light().copyWith(extensions: const [_palette]),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('template category maps the bar to the selected field', (
    tester,
  ) async {
    final page = _page();
    await tester.pumpWidget(
      _wrap(
        VisualChooser.buildTemplate(
          page: page,
          template: _template,
          binding: page.visual!,
        ),
      ),
    );

    final chart = tester.widget<VerticalBarChart>(
      find.byType(VerticalBarChart),
    );
    expect(chart.x.name, 'month');
    expect(chart.measure.name, 'sales');
  });

  testWidgets('template frame preserves explicit offline state', (
    tester,
  ) async {
    final page = _page();
    await tester.pumpWidget(
      _wrap(
        VisualChooser.buildTemplate(
          page: page,
          template: _template,
          binding: page.visual!,
          frameState: ChartFrameState.offline,
        ),
      ),
    );

    final frame = tester.widget<ChartFrame>(find.byType(ChartFrame));
    expect(frame.state, ChartFrameState.offline);
    expect(find.byType(VerticalBarChart), findsOneWidget);
  });
}
