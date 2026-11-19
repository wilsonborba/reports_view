import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

void main() {
  const scoreTemplate = VisualTemplate(
    templateId: 'cert-score-distribution',
    version: 1,
    kind: 'chart',
    visual: 'bar',
    title: 'Score distribution',
    slots: [
      TemplateSlot(
        slotName: 'bucket',
        role: 'dimension',
        isRequired: true,
        minCount: 1,
        maxCount: 1,
        acceptedTypes: ['string'],
      ),
      TemplateSlot(
        slotName: 'attempts',
        role: 'measure',
        isRequired: true,
        minCount: 1,
        maxCount: 2,
        acceptedTypes: ['integer', 'float'],
      ),
    ],
  );

  DatasetPage sampleAggregatePage({String bucketType = 'string'}) {
    return DatasetPage(
      descriptor: DatasetDescriptor(
        datasetId: 'cert:quiz-42:score-distribution',
        title: 'Quiz 42 score distribution',
        description: 'Backend aggregate rendered without a Reports catalog row',
        equation: null,
        fields: [
          FieldInfo(name: 'score_band', label: 'Score band', type: bucketType, role: 'dimension'),
          const FieldInfo(name: 'attempt_count', label: 'Attempts', type: 'integer', role: 'measure', unit: 'attempts'),
        ],
        filters: const [],
        meta: const DatasetMeta(source: 'Certifications API', periodStart: '2026-11-01', periodEnd: '2026-11-19', tier: 'live'),
      ),
      rows: const [
        {'score_band': '0-49%', 'attempt_count': 4},
        {'score_band': '50-79%', 'attempt_count': 18},
        {'score_band': '80-100%', 'attempt_count': 27},
      ],
      offset: 0,
      limit: 10,
      totalRows: 3,
      visual: const CardVisualBinding(
        template: 'cert-score-distribution',
        version: 1,
        mapping: {
          'bucket': ['score_band'],
          'attempts': ['attempt_count'],
        },
      ),
    );
  }

  const palette = ReportPalette(
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
    other: Color(0xFF8D8D8D),
    highlight: Color(0xFF0F62FE),
  );

  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.light().copyWith(extensions: const [palette]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('template-only aggregate renders with valid slot mapping', (tester) async {
    final page = sampleAggregatePage();
    await tester.pumpWidget(wrap(
      VisualChooser.buildTemplate(
        page: page,
        template: scoreTemplate,
        binding: page.visual!,
      ),
    ));

    expect(find.text('Quiz 42 score distribution'), findsOneWidget);
    expect(find.text('Could not load chart'), findsNothing);
    expect(find.byType(VerticalBarChart), findsOneWidget);
  });

  testWidgets('missing required slot shows ChartFrame error state before drawing', (tester) async {
    final page = sampleAggregatePage();
    const badBinding = CardVisualBinding(
      template: 'cert-score-distribution',
      version: 1,
      mapping: {
        'bucket': ['score_band'],
      },
    );

    await tester.pumpWidget(wrap(
      VisualChooser.buildTemplate(
        page: page,
        template: scoreTemplate,
        binding: badBinding,
      ),
    ));

    expect(find.text("Slot 'attempts' requires at least 1 field(s)"), findsOneWidget);
    expect(find.byType(VerticalBarChart), findsNothing);
  });

  testWidgets('wrong field type or unknown field shows ChartFrame error state', (tester) async {
    final wrongTypePage = sampleAggregatePage(bucketType: 'integer');
    await tester.pumpWidget(wrap(
      VisualChooser.buildTemplate(
        page: wrongTypePage,
        template: scoreTemplate,
        binding: wrongTypePage.visual!,
      ),
    ));
    expect(find.text("Field 'score_band' has type 'integer', expected string"), findsOneWidget);
    expect(find.byType(VerticalBarChart), findsNothing);

    final page = sampleAggregatePage();
    const unknownFieldBinding = CardVisualBinding(
      template: 'cert-score-distribution',
      version: 1,
      mapping: {
        'bucket': ['missing_col'],
        'attempts': ['attempt_count'],
      },
    );
    await tester.pumpWidget(wrap(
      VisualChooser.buildTemplate(
        page: page,
        template: scoreTemplate,
        binding: unknownFieldBinding,
      ),
    ));
    expect(find.text("Unknown field 'missing_col' for slot 'bucket'"), findsOneWidget);
    expect(find.byType(VerticalBarChart), findsNothing);
  });

  testWidgets('template version mismatch or unknown slot shows error state', (tester) async {
    final page = sampleAggregatePage();
    const wrongVersion = CardVisualBinding(
      template: 'cert-score-distribution',
      version: 2,
      mapping: {
        'bucket': ['score_band'],
        'attempts': ['attempt_count'],
      },
    );
    await tester.pumpWidget(wrap(
      VisualChooser.buildTemplate(
        page: page,
        template: scoreTemplate,
        binding: wrongVersion,
      ),
    ));
    expect(find.textContaining('Binding targets cert-score-distribution v2'), findsOneWidget);
    expect(find.byType(VerticalBarChart), findsNothing);
  });
}
