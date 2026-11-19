import 'package:flutter/material.dart';
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
}
