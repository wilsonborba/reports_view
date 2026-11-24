import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reports_view/reports_view.dart';
import 'package:reports_view/src/charts/geo_charts.dart';

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
    Color(0xFF009D9A),
    Color(0xFFEE5396),
  ],
);

void main() {
  const geoIds = <String>[
    'map',
    'bubble_map',
    'choropleth',
    'geo_heatmap',
    'flow_map',
    'hex_tile_map',
  ];

  final coordPage = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'geo_coord_ds',
      title: 'Geographic Coordinate Fixture',
      description: 'Point geographic catalog fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'region',
          label: 'City',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'lat',
          label: 'Lat',
          type: 'latitude',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'lon',
          label: 'Lon',
          type: 'longitude',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'val',
          label: 'Total',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
    ),
    rows: const [
      {'region': 'Bangkok', 'lat': 13.75, 'lon': 100.50, 'val': 120},
      {'region': 'Chiang Mai', 'lat': 18.79, 'lon': 98.98, 'val': 65},
      {'region': 'Phuket', 'lat': 7.88, 'lon': 98.39, 'val': 48},
      {'region': 'São Paulo', 'lat': -23.55, 'lon': -46.63, 'val': 95},
      {'region': 'Rio', 'lat': -22.91, 'lon': -43.17, 'val': 52},
    ],
    offset: 0,
    limit: 5,
    totalRows: 5,
  );

  final isoRegionPage = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'geo_iso_ds',
      title: 'Geographic ISO Boundary Fixture',
      description: 'Thailand & Brazil ISO region fixture',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'region',
          label: 'ISO Code',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'val',
          label: 'Total',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
    ),
    rows: const [
      {'region': 'TH-10', 'val': 120},
      {'region': 'TH-50', 'val': 75},
      {'region': 'TH-83', 'val': 62},
      {'region': 'TH-40', 'val': 54},
      {'region': 'TH-90', 'val': 48},
    ],
    offset: 0,
    limit: 5,
    totalRows: 5,
  );

  final missingGeoPage = DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'no_geo_ds',
      title: 'Missing Geo Fixture',
      description: 'No lat/lon and no ISO codes',
      equation: null,
      fields: const [
        FieldInfo(
          name: 'region',
          label: 'Category',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'val',
          label: 'Total',
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
    ),
    rows: const [
      {'region': 'Core Alpha', 'val': 42},
      {'region': 'Regional Output', 'val': 18},
    ],
    offset: 0,
    limit: 2,
    totalRows: 2,
  );

  for (final id in geoIds) {
    testWidgets('$id renders valid geometry across EN, pt-BR, and TH', (
      tester,
    ) async {
      final isRegion = id == 'choropleth' || id == 'hex_tile_map';
      final page = isRegion ? isoRegionPage : coordPage;
      final tpl = VisualTemplate(
        templateId: id,
        version: 1,
        kind: 'chart',
        visual: id,
        title: id,
        slots: const [
          TemplateSlot(
            slotName: 'category',
            role: 'dimension',
            minCount: 1,
            maxCount: 1,
            acceptedTypes: ['string'],
          ),
          TemplateSlot(
            slotName: 'value',
            role: 'measure',
            minCount: 1,
            maxCount: 1,
            acceptedTypes: ['integer'],
          ),
        ],
      );
      final binding = CardVisualBinding(
        template: id,
        version: 1,
        mapping: const {
          'category': ['region'],
          'value': ['val'],
        },
      );
      for (final locale in const [
        Locale('en'),
        Locale('pt', 'BR'),
        Locale('th'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: _palette.toTheme(Brightness.light),
            home: Scaffold(
              body: SizedBox(
                width: 440,
                height: 320,
                child: SingleChildScrollView(
                  child: VisualChooser.buildTemplate(
                    page: page,
                    template: tpl,
                    binding: binding,
                    title: id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$id ($locale) threw');
      }
    });
  }

  testWidgets(
    'refuses missing coordinates and missing ISO codes (not offered by chooser, error state in template)',
    (tester) async {
      for (final visual in [
        Visual.bubbleMap,
        Visual.geoHeatmap,
        Visual.flowMap,
        Visual.choropleth,
        Visual.hexTileMap,
      ]) {
        // Chooser refuses to offer geo chart on non-geo data (falls back to table)
        expect(
          VisualChooser.resolve(missingGeoPage, Slot('s', visual: visual)),
          Visual.table,
        );

        final tpl = VisualTemplate(
          templateId: visual.name,
          version: 1,
          kind: 'chart',
          visual: visual.name,
          title: visual.name,
          slots: const [
            TemplateSlot(
              slotName: 'category',
              role: 'dimension',
              minCount: 1,
              maxCount: 1,
              acceptedTypes: ['string'],
            ),
            TemplateSlot(
              slotName: 'value',
              role: 'measure',
              minCount: 1,
              maxCount: 1,
              acceptedTypes: ['integer'],
            ),
          ],
        );
        final binding = CardVisualBinding(
          template: visual.name,
          version: 1,
          mapping: const {
            'category': ['region'],
            'value': ['val'],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: _palette.toTheme(Brightness.light),
            home: Scaffold(
              body: VisualChooser.buildTemplate(
                page: missingGeoPage,
                template: tpl,
                binding: binding,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.textContaining('requires'),
          findsOneWidget,
          reason:
              '${visual.name} must refuse data without coordinates or ISO codes',
        );
      }
    },
  );

  test(
    'Natural Earth bundled geometry includes admin-0, Thailand & Brazil admin-1, and stays compact',
    () {
      expect(naturalEarthAdmin0.length, greaterThanOrEqualTo(170));
      final thProvinces = naturalEarthAdmin1
          .where((b) => b.parentCountry == 'TH')
          .length;
      final brStates = naturalEarthAdmin1
          .where((b) => b.parentCountry == 'BR')
          .length;
      expect(thProvinces, 77);
      expect(brStates, 27);
      expect(lookupGeoBoundary('TH')?.isoAlpha3, 'THA');
      expect(lookupGeoBoundary('BRA')?.isoCode, 'BR');
      expect(lookupGeoBoundary('TH-10'), isNotNull);
      expect(lookupGeoBoundary('BR-SP'), isNotNull);
      expect(naturalEarthAttribution, contains('Natural Earth'));
      final sizeBytes = File(
        'lib/src/geo/natural_earth_boundaries.dart',
      ).lengthSync();
      expect(sizeBytes, lessThan(200 * 1024));
    },
  );

  test('geo size limit caps regions at maxRegions (24)', () {
    final manyRows = [
      for (var i = 0; i < 40; i++)
        {'region': 'R$i', 'lat': 10.0 + i, 'lon': 20.0 + i, 'val': 10 + i},
    ];
    final manyPage = DatasetPage(
      descriptor: coordPage.descriptor,
      rows: manyRows,
      offset: 0,
      limit: 40,
      totalRows: 40,
    );
    final pts = GeoCatalogChart.extractPoints(
      manyPage,
      Visual.bubbleMap,
      coordPage.descriptor.fields.first,
      coordPage.descriptor.fields.last,
    );
    expect(pts.length, GeoCatalogChart.maxRegions);
  });

  test(
    'equirectangular projection preserves Thailand aspect ratio without stretching and shows region names instead of ISO codes',
    () {
      final pts = GeoCatalogChart.extractPoints(
        isoRegionPage,
        Visual.choropleth,
        isoRegionPage.descriptor.fields.first,
        isoRegionPage.descriptor.fields.last,
      );
      expect(pts.map((p) => p.isoCode).toList(), [
        'TH-10',
        'TH-50',
        'TH-83',
        'TH-40',
        'TH-90',
      ]);
      expect(pts.map((p) => p.label).toList(), [
        'Bangkok Metropolis',
        'Chiang Mai',
        'Phuket',
        'Khon Kaen',
        'Songkhla',
      ]);
      for (final p in pts) {
        expect(p.label.startsWith('TH-'), isFalse);
      }

      // Compute raw Natural Earth Thailand polygon extents.
      var minLon = 180.0;
      var maxLon = -180.0;
      var minLat = 90.0;
      var maxLat = -90.0;
      for (final b in naturalEarthAdmin1.where(
        (r) => r.parentCountry == 'TH',
      )) {
        for (final ring in b.rings) {
          for (final pt in ring) {
            minLon = math.min(minLon, pt.dx);
            maxLon = math.max(maxLon, pt.dx);
            minLat = math.min(minLat, pt.dy);
            maxLat = math.max(maxLat, pt.dy);
          }
        }
      }

      final viewport = GeoCatalogChart.computeViewport(pts);
      const widePlot = Rect.fromLTWH(0, 0, 420, 220);
      final topLeft = viewport.project(minLon, maxLat, widePlot);
      final bottomRight = viewport.project(maxLon, minLat, widePlot);
      final projWidth = (bottomRight.dx - topLeft.dx).abs();
      final projHeight = (bottomRight.dy - topLeft.dy).abs();

      final midLat = (viewport.minLat + viewport.maxLat) * 0.5;
      final expectedAspect =
          ((maxLon - minLon) * math.cos(midLat * math.pi / 180.0)) /
          (maxLat - minLat);
      expect(projWidth / projHeight, closeTo(expectedAspect, 1e-3));
      expect(projWidth, lessThan(projHeight));

      // Verify centered inside the wide plot box with equal horizontal margins.
      final leftMargin = topLeft.dx - widePlot.left;
      final rightMargin = widePlot.right - bottomRight.dx;
      final vpLeft = viewport.project(
        viewport.minLon,
        viewport.maxLat,
        widePlot,
      );
      final vpRight = viewport.project(
        viewport.maxLon,
        viewport.minLat,
        widePlot,
      );
      expect(
        (vpLeft.dx - widePlot.left) - (widePlot.right - vpRight.dx),
        closeTo(0.0, 1e-6),
      );
      expect((leftMargin - rightMargin).abs(), lessThan(40.0));
    },
  );
}
