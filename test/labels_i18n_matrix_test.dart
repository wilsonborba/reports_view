import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';

const _lightPalette = ReportPalette(
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
    Color(0xFFD12771),
    Color(0xFFBA4E00),
    Color(0xFF198038),
    Color(0xFF0043CE),
    Color(0xFFDA1E28),
  ],
  other: Color(0xFF6F6F6F),
  highlight: Color(0xFF0F62FE),
);

const _darkPalette = ReportPalette(
  canvas: Color(0xFF161616),
  surface: Color(0xFF262626),
  surfaceAlt: Color(0xFF393939),
  border: Color(0xFF525252),
  textPrimary: Color(0xFFF4F4F4),
  textMuted: Color(0xFFC6C6C6),
  accent: Color(0xFF78A9FF),
  onAccent: Color(0xFF161616),
  positive: Color(0xFF42BE65),
  warning: Color(0xFFF1C21B),
  negative: Color(0xFFFF8389),
  info: Color(0xFF78A9FF),
  caution: Color(0xFFFF832B),
  series: [
    Color(0xFF78A9FF),
    Color(0xFFBE95FF),
    Color(0xFF3DDBD9),
    Color(0xFFFF7EB6),
    Color(0xFFFF832B),
    Color(0xFF42BE65),
    Color(0xFF82CFFF),
    Color(0xFFFF8389),
  ],
  other: Color(0xFF8D8D8D),
  highlight: Color(0xFF78A9FF),
);

class _PermissiveMaterialLocalizations extends LocalizationsDelegate<MaterialLocalizations> {
  const _PermissiveMaterialLocalizations();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      const DefaultMaterialLocalizations();

  @override
  bool shouldReload(_PermissiveMaterialLocalizations old) => false;
}

void main() {
  test('C5: niceInterval uses {1, 2, 2.5, 5} * 10^n with 3 to 7 ticks', () {
    expect(ChartParts.niceInterval(0, 100), 20.0);
    expect(ChartParts.niceInterval(0, 12), 2.5);
    expect(ChartParts.niceInterval(0, 480), 100.0);
    expect(ChartParts.niceInterval(-10, 40), 10.0);
  });

  test('C12: light and dark palettes meet WCAG 2.2 contrast (4.5:1 text, 3:1 marks)', () {
    for (final p in [_lightPalette, _darkPalette]) {
      expect(ChartParts.contrastRatio(p.textPrimary, p.canvas), greaterThanOrEqualTo(4.5));
      expect(ChartParts.contrastRatio(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
      expect(ChartParts.contrastRatio(p.textMuted, p.surface), greaterThanOrEqualTo(4.5));
      expect(ChartParts.contrastRatio(p.accent, p.surface), greaterThanOrEqualTo(3.0));
      for (final c in p.series) {
        expect(ChartParts.contrastRatio(c, p.surface), greaterThanOrEqualTo(3.0));
      }
    }
  });

  test('C6: long category labels switch automatic bar selection to horizontal', () {
    final page = DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'long',
        title: 'Long categories',
        description: '',
        equation: null,
        fields: [
          FieldInfo(name: 'cat', label: 'Category', type: 'string', role: 'dimension'),
          FieldInfo(name: 'val', label: 'Value', type: 'integer', role: 'measure'),
        ],
        filters: [],
      ),
      rows: const [
        {'cat': 'Very Long Enterprise Category Name Alpha', 'val': 120},
        {'cat': 'Very Long Enterprise Category Name Beta', 'val': 85},
      ],
      offset: 0,
      limit: 2,
      totalRows: 2,
    );
    expect(VisualChooser.auto(page), Visual.hbar);
  });

  testWidgets('C23: EN, pt-BR, TH x light/dark x 320/390/768/1300 px render without overflow',
      (tester) async {
    final page = DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'i18n',
        title: 'รายงานการใช้งานประจำวัน / Daily Usage Report',
        description: 'รายละเอียดการประมวลผลและจำนวนโทเคนทั้งหมด',
        equation: null,
        fields: [
          FieldInfo(name: 'cat', label: 'หมวดหมู่', type: 'string', role: 'dimension'),
          FieldInfo(name: 'val', label: 'โทเคน', type: 'integer', role: 'measure', unit: 'tokens'),
        ],
        filters: [],
        meta: DatasetMeta(
          source: 'Telemetry',
          periodStart: '2026-11-01',
          periodEnd: '2026-11-18',
          timezone: 'Asia/Bangkok',
          tier: 'real',
        ),
      ),
      rows: const [
        {'cat': 'ภาษาไทยที่ยาวมากสำหรับการทดสอบการตัดคำอัตโนมัติ', 'val': 1234},
        {'cat': 'Categoria longa em Português do Brasil', 'val': 987},
        {'cat': 'Long English Category Label Example', 'val': 456},
      ],
      offset: 0,
      limit: 3,
      totalRows: 3,
    );

    for (final locale in [const Locale('en'), const Locale('pt', 'BR'), const Locale('th')]) {
      for (final palette in [_lightPalette, _darkPalette]) {
        for (final width in [320.0, 390.0, 768.0, 1300.0]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              theme: ThemeData.light().copyWith(extensions: [palette]),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: width,
                      child: ChartFrame(
                        page: page,
                        child: VisualChooser.build(page, const Slot('i18n', visual: Visual.hbar)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Failed for $locale width=$width');
        }
      }
    }
  });

  testWidgets(
    'ChartFrame keeps long localized headers readable and table toggle usable',
    (tester) async {
      const locales = [Locale('en'), Locale('pt', 'BR'), Locale('th')];
      String titleFor(Locale locale) => switch (locale.languageCode) {
        'pt' =>
          'Distribuição das pontuações das tentativas concluídas por faixa',
        'th' => 'การกระจายคะแนนของแบบทดสอบที่ทำเสร็จแล้วตามช่วงคะแนน',
        _ => 'Distribution of completed attempts grouped by score band',
      };
      String descriptionFor(Locale locale) => switch (locale.languageCode) {
        'pt' =>
          'Pontuações das tentativas concluídas agrupadas em faixas percentuais fixas',
        'th' => 'คะแนนของแบบทดสอบที่ทำเสร็จแล้วจัดกลุ่มตามช่วงเปอร์เซ็นต์คงที่',
        _ => 'Completed attempt scores grouped into fixed percentage bands',
      };
      String tableLabelFor(Locale locale) => switch (locale.languageCode) {
        'pt' => 'Mostrar como tabela',
        'th' => 'แสดงเป็นตาราง',
        _ => 'Show as table',
      };
      String chartLabelFor(Locale locale) => switch (locale.languageCode) {
        'pt' => 'Mostrar como gráfico',
        'th' => 'แสดงเป็นแผนภูมิ',
        _ => 'Show as chart',
      };
      String seeAllLabelFor(Locale locale) => switch (locale.languageCode) {
        'pt' => 'Ver tudo',
        'th' => 'ดูทั้งหมด',
        _ => 'See all',
      };
      String tierLabelFor(Locale locale) => switch (locale.languageCode) {
        'th' => 'ข้อมูลจริง',
        _ => 'Real',
      };

      final cases =
          <
            ({
              Locale locale,
              double cardWidth,
              double viewportWidth,
              double scale,
            })
          >[
            for (final locale in locales)
              for (final cardWidth in [320.0, 390.0])
                for (final scale in [1.0, 1.5])
                  (
                    locale: locale,
                    cardWidth: cardWidth,
                    viewportWidth: cardWidth,
                    scale: scale,
                  ),
            for (final locale in locales)
              for (final cardWidth in [480.0, 500.0, 600.0])
                (
                  locale: locale,
                  cardWidth: cardWidth,
                  viewportWidth: cardWidth,
                  scale: 1.0,
                ),
            for (final locale in locales)
              (
                locale: locale,
                cardWidth: 390.0,
                viewportWidth: 1440.0,
                scale: 1.0,
              ),
            for (final locale in locales)
              (
                locale: locale,
                cardWidth: 1440.0,
                viewportWidth: 1440.0,
                scale: 1.0,
              ),
          ];

      for (final testCase in cases) {
        final title = titleFor(testCase.locale);
        final description = descriptionFor(testCase.locale);
        final page = DatasetPage(
          descriptor: DatasetDescriptor(
            datasetId: 'responsive-score-distribution',
            title: title,
            description: description,
            equation: null,
            fields: const [
              FieldInfo(
                name: 'score_band',
                label: 'Score band',
                type: 'string',
                role: 'dimension',
              ),
              FieldInfo(
                name: 'attempt_count',
                label: 'Attempts',
                type: 'integer',
                role: 'measure',
              ),
            ],
            filters: const [],
            dataTier: 'real',
            visibility: 'restricted',
            meta: const DatasetMeta(tier: 'real'),
          ),
          rows: const [
            {'score_band': '0% to <50%', 'attempt_count': 1},
            {'score_band': '50% to <80%', 'attempt_count': 1},
            {'score_band': '80% to 100%', 'attempt_count': 1},
          ],
          offset: 0,
          limit: 3,
          totalRows: 3,
        );

        tester.view.physicalSize = Size(testCase.viewportWidth, 900);
        tester.view.devicePixelRatio = 1;
        var seeAllCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: ThemeData.light().copyWith(
              extensions: const [_lightPalette],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(testCase.scale)),
              child: child!,
            ),
            home: Localizations(
              locale: testCase.locale,
              delegates: const [
                _PermissiveMaterialLocalizations(),
                DefaultWidgetsLocalizations.delegate,
              ],
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Center(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: testCase.cardWidth,
                        child: ChartFrame(
                          page: page,
                          onSeeAll: () => seeAllCount++,
                          child: const SizedBox(
                            height: 120,
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final caseLabel =
            'locale=${testCase.locale} card=${testCase.cardWidth} '
            'viewport=${testCase.viewportWidth} scale=${testCase.scale}';
        expect(tester.takeException(), isNull, reason: caseLabel);
        final titleFinder = find.text(title);
        final descriptionFinder = find.text(description);
        expect(titleFinder, findsOneWidget, reason: caseLabel);
        expect(descriptionFinder, findsOneWidget, reason: caseLabel);
        expect(
          tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
          isFalse,
          reason: 'The title must remain fully available: $caseLabel',
        );
        expect(
          tester
              .renderObject<RenderParagraph>(descriptionFinder)
              .didExceedMaxLines,
          isFalse,
          reason: 'The description must remain fully available: $caseLabel',
        );

        final tableButton = find.text(tableLabelFor(testCase.locale));
        expect(tableButton, findsOneWidget, reason: caseLabel);
        expect(
          find.text(tierLabelFor(testCase.locale)),
          findsOneWidget,
          reason: caseLabel,
        );
        final seeAllButton = find.text(seeAllLabelFor(testCase.locale));
        expect(seeAllButton, findsOneWidget, reason: caseLabel);
        await tester.tap(seeAllButton);
        expect(seeAllCount, 1, reason: caseLabel);
        expect(find.byType(DataTableView), findsNothing, reason: caseLabel);
        await tester.tap(tableButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: caseLabel);
        expect(find.byType(DataTableView), findsOneWidget, reason: caseLabel);
        expect(
          find.text(chartLabelFor(testCase.locale)),
          findsOneWidget,
          reason: caseLabel,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets('ChartFrame accounts for themed TextButton padding', (
    tester,
  ) async {
    const title = 'Distribution of completed attempts grouped by score band';
    const description =
        'Completed attempt scores grouped into fixed percentage bands';
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final page = DatasetPage(
      descriptor: const DatasetDescriptor(
        datasetId: 'responsive-score-distribution',
        title: title,
        description: description,
        equation: null,
        fields: [
          FieldInfo(
            name: 'score_band',
            label: 'Score band',
            type: 'string',
            role: 'dimension',
          ),
          FieldInfo(
            name: 'attempt_count',
            label: 'Attempts',
            type: 'integer',
            role: 'measure',
          ),
        ],
        filters: [],
        dataTier: 'real',
        visibility: 'restricted',
        meta: DatasetMeta(tier: 'real'),
      ),
      rows: const [
        {'score_band': '0% to <50%', 'attempt_count': 1},
        {'score_band': '50% to <80%', 'attempt_count': 1},
        {'score_band': '80% to 100%', 'attempt_count': 1},
      ],
      offset: 0,
      limit: 3,
      totalRows: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [_lightPalette],
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 64),
            ),
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 600,
              child: ChartFrame(
                page: page,
                onSeeAll: () {},
                child: const SizedBox(
                  height: 120,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.text(title);
    final descriptionFinder = find.text(description);
    expect(titleFinder, findsOneWidget);
    expect(descriptionFinder, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester.renderObject<RenderParagraph>(descriptionFinder).didExceedMaxLines,
      isFalse,
    );
    final actionTop = tester.getTopLeft(find.text('Show as table')).dy;
    final descriptionBottom = tester.getBottomRight(descriptionFinder).dy;
    expect(actionTop, greaterThan(descriptionBottom));
    expect(tester.takeException(), isNull);
  });
}
