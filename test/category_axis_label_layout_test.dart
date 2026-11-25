import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  series: [Color(0xFF0F62FE), Color(0xFF8A3FFC)],
);

Future<ByteData> _font(String file) async => ByteData.sublistView(
  Uint8List.fromList(await File('test/fonts/$file').readAsBytes()),
);

Future<void> _loadFonts() async {
  await (FontLoader(
    ReportPalette.font,
  )..addFont(_font('UbuntuSans-Variable.ttf'))).load();
  await (FontLoader(
    ReportPalette.thaiFont,
  )..addFont(_font('IBMPlexSansThai-Regular.ttf'))).load();
}

DatasetPage _page(List<String> labels) => DatasetPage(
  descriptor: DatasetDescriptor(
    datasetId: 'score-bands',
    title: 'Score bands',
    description: 'Fixture for category axis labels',
    equation: null,
    fields: const [
      FieldInfo(
        name: 'band',
        label: 'Score band',
        type: 'string',
        role: 'dimension',
      ),
      FieldInfo(
        name: 'count',
        label: 'Attempts',
        type: 'integer',
        role: 'measure',
      ),
    ],
    filters: const [],
  ),
  rows: [
    for (var i = 0; i < labels.length; i++) {'band': labels[i], 'count': i + 1},
  ],
  offset: 0,
  limit: labels.length,
  totalRows: labels.length,
);

Widget _chart(int width, List<String> labels, {double? pointWidth}) =>
    MaterialApp(
      theme: _palette.toTheme(Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width.toDouble(),
            height: 320,
            child: VerticalBarChart(
              page: _page(labels),
              x: const FieldInfo(
                name: 'band',
                label: 'Score band',
                type: 'string',
                role: 'dimension',
              ),
              measure: const FieldInfo(
                name: 'count',
                label: 'Attempts',
                type: 'integer',
                role: 'measure',
              ),
              pointWidth: pointWidth,
            ),
          ),
        ),
      ),
    );

Widget _lineChart(int width, List<String> labels) => MaterialApp(
  theme: _palette.toTheme(Brightness.light),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width.toDouble(),
        height: 320,
        child: SeriesLineChart(
          page: _page(labels),
          x: const FieldInfo(
            name: 'band',
            label: 'Score band',
            type: 'string',
            role: 'dimension',
          ),
          measures: const [
            FieldInfo(
              name: 'count',
              label: 'Attempts',
              type: 'integer',
              role: 'measure',
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('percentage range labels fit their phone category slots', (
    tester,
  ) async {
    const labels = ['0% to <50%', '50% to <80%', '80% to 100%'];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_chart(390, labels));
    await tester.pumpAndSettle();

    final chartRect = tester.getRect(find.byType(VerticalBarChart));
    final labelRects = <Rect>[];
    for (final label in labels) {
      final finder = find.text(label).first;
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label should fit without truncation',
      );
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(chartRect.left));
      expect(rect.right, lessThanOrEqualTo(chartRect.right));
      labelRects.add(rect);
    }
    labelRects.sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < labelRects.length; i++) {
      expect(
        labelRects[i - 1].right,
        lessThanOrEqualTo(labelRects[i].left),
        reason: 'phone label rectangles: $labelRects',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('percentage range labels use the full desktop category slots', (
    tester,
  ) async {
    const labels = ['0% to <50%', '50% to <80%', '80% to 100%'];
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_chart(1440, labels));
    await tester.pumpAndSettle();

    final labelRects = <Rect>[];
    for (final label in labels) {
      final finder = find.text(label).first;
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label should fit without truncation',
      );
      labelRects.add(tester.getRect(finder));
    }
    labelRects.sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < labelRects.length; i++) {
      expect(
        labelRects[i - 1].right,
        lessThanOrEqualTo(labelRects[i].left + 0.1),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('line labels fit tick slots and stay separated at phone width', (
    tester,
  ) async {
    const labels = ['0% to <50%', '50% to <80%', '80% to 100%'];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_lineChart(390, labels));
    await tester.pumpAndSettle();

    final labelRects = <Rect>[];
    for (final label in labels) {
      final finder = find.text(label).first;
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label should fit its line-chart tick slot',
      );
      labelRects.add(tester.getRect(finder));
    }
    labelRects.sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < labelRects.length; i++) {
      expect(
        labelRects[i - 1].right,
        lessThanOrEqualTo(labelRects[i].left),
        reason: 'line label rectangles: $labelRects',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dense Thai categories use point width without label overlap', (
    tester,
  ) async {
    const labels = [
      'หมวดหมู่หลัก ก',
      'การประเมินผลรวม',
      'ข้อมูลเชิงสถิติ',
      'ประสิทธิภาพระบบ',
      'สัดส่วนผู้ใช้งาน',
      'แนวโน้มรายเดือน',
      'เกณฑ์มาตรฐานกลาง',
      'สรุปรายงานประจำปี',
    ];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_chart(390, labels, pointWidth: 100));
    await tester.pumpAndSettle();

    final labelRects = <Rect>[];
    for (final label in labels) {
      final finder = find.text(label).first;
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      labelRects.add(tester.getRect(finder));
    }
    labelRects.sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < labelRects.length; i++) {
      expect(
        labelRects[i - 1].right,
        lessThanOrEqualTo(labelRects[i].left + 0.1),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
