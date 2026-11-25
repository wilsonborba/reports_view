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
  series: [
    Color(0xFF0F62FE),
    Color(0xFF8A3FFC),
    Color(0xFF009D9A),
    Color(0xFFEE5396),
  ],
);

const _darkPalette = ReportPalette(
  canvas: Color(0xFF121212),
  surface: Color(0xFF1E1E1E),
  surfaceAlt: Color(0xFF2C2C2C),
  border: Color(0xFF444444),
  textPrimary: Color(0xFFF4F4F4),
  textMuted: Color(0xFFBDBDBD),
  accent: Color(0xFF78A9FF),
  onAccent: Color(0xFF121212),
  positive: Color(0xFF42BE65),
  warning: Color(0xFFF1C21B),
  negative: Color(0xFFFF8389),
  info: Color(0xFF78A9FF),
  caution: Color(0xFFFF832B),
  series: [
    Color(0xFF78A9FF),
    Color(0xFFBE95FF),
    Color(0xFF08BDBA),
    Color(0xFFFF7EB6),
  ],
);

Future<ByteData> _font(String file) async => ByteData.sublistView(
  Uint8List.fromList(await File('test/fonts/$file').readAsBytes()),
);

/// Loads real Ubuntu Sans, Ubuntu Sans Mono, and IBM Plex Sans Thai fonts
/// so EN, pt-BR, and TH glyphs render clearly in golden images.
Future<void> _loadReportsFonts() async {
  await (FontLoader(ReportPalette.font)
        ..addFont(_font('UbuntuSans-Variable.ttf'))
        ..addFont(_font('UbuntuSans-Italic-Variable.ttf')))
      .load();
  await (FontLoader(ReportPalette.thaiFont)
        ..addFont(_font('IBMPlexSansThai-Regular.ttf'))
        ..addFont(_font('IBMPlexSansThai-SemiBold.ttf')))
      .load();
  await (FontLoader(
    ReportPalette.monoFont,
  )..addFont(_font('UbuntuSansMono-Variable.ttf'))).load();
}

String _localizedCategory(String lang, int index) {
  return switch (lang) {
    'pt-BR' => [
      'Ação Principal',
      'Produção Regional',
      'Educação Básica',
      'Saúde Pública',
      'Gestão Financeira',
      'Serviços Digitais',
      'Relatório Anual',
      'Meta Mensal',
    ][index % 8],
    'th' => [
      'หมวดหมู่หลัก ก',
      'การประเมินผลรวม',
      'ข้อมูลเชิงสถิติ',
      'ประสิทธิภาพระบบ',
      'สัดส่วนผู้ใช้งาน',
      'แนวโน้มรายเดือน',
      'เกณฑ์มาตรฐานกลาง',
      'สรุปรายงานประจำปี',
    ][index % 8],
    _ => [
      'Core Alpha',
      'Regional Output',
      'Primary Service',
      'System Metrics',
      'User Cohort',
      'Monthly Trend',
      'Baseline Target',
      'Annual Summary',
    ][index % 8],
  };
}

String _localizedTitle(String lang, String id) {
  return switch (lang) {
    'pt-BR' => 'Gráfico $id (pt-BR)',
    'th' => 'แผนภูมิ $id (ภาษาไทย)',
    _ => 'Chart $id (EN)',
  };
}

DatasetPage _makePage(
  String id,
  String dimName,
  String dimType,
  int count, {
  String lang = 'en',
}) {
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: id,
      title: _localizedTitle(lang, id),
      description: 'Catalog golden fixture',
      equation: null,
      fields: [
        FieldInfo(
          name: dimName,
          label: switch (lang) {
            'pt-BR' => 'Categoria',
            'th' => 'หมวดหมู่',
            _ => 'Category',
          },
          type: dimType,
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: switch (lang) {
            'pt-BR' => 'Principal',
            'th' => 'ค่าหลัก',
            _ => 'Primary',
          },
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'v2',
          label: switch (lang) {
            'pt-BR' => 'Secundário',
            'th' => 'ค่ารอง',
            _ => 'Secondary',
          },
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      filters: const [],
      meta: const DatasetMeta(
        source: 'Test fixture',
        sourceUrl: 'https://reports.asodya.com',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        timezone: 'UTC',
        freshnessMode: 'daily',
        expectedRefreshMinutes: 60,
        updatedAt: 1700000000,
        tier: 'public',
      ),
    ),
    rows: [
      for (var i = 0; i < count; i++)
        {
          dimName: dimType == 'date'
              ? '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}'
              : _localizedCategory(lang, i),
          'v1': 20 + (i * 17) % 80,
          'v2': 15 + (i * 11) % 60,
        },
    ],
    offset: 0,
    limit: count,
    totalRows: count,
  );
}

DatasetPage _makeDiagramPage(String id, {String lang = 'en'}) {
  final isTh = lang == 'th';
  final isPt = lang == 'pt-BR';
  String lbl(String en, String pt, String th) => isTh ? th : (isPt ? pt : en);
  final rows = <Map<String, dynamic>>[
    {
      'src': lbl('Start', 'Início', 'เริ่ม'),
      'dst': lbl('Check', 'Validar', 'ตรวจ'),
      'grp': lbl('Edge', 'Borda', 'ขอบ'),
      'v1': 90,
    },
    {
      'src': lbl('Check', 'Validar', 'ตรวจ'),
      'dst': lbl('Fast', 'Rápido', 'เร็ว'),
      'grp': lbl('Core', 'Núcleo', 'แกน'),
      'v1': 55,
    },
    {
      'src': lbl('Check', 'Validar', 'ตรวจ'),
      'dst': lbl('Queue', 'Fila', 'คิว'),
      'grp': lbl('Core', 'Núcleo', 'แกน'),
      'v1': 35,
    },
    {
      'src': lbl('Fast', 'Rápido', 'เร็ว'),
      'dst': lbl('Store', 'Banco', 'คลัง'),
      'grp': lbl('Data', 'Dados', 'ข้อมูล'),
      'v1': 45,
    },
    {
      'src': lbl('Queue', 'Fila', 'คิว'),
      'dst': lbl('Store', 'Banco', 'คลัง'),
      'grp': lbl('Data', 'Dados', 'ข้อมูล'),
      'v1': 30,
    },
    if (id == 'state_diagram')
      {
        'src': lbl('Store', 'Banco', 'คลัง'),
        'dst': lbl('Check', 'Validar', 'ตรวจ'),
        'grp': lbl('Core', 'Núcleo', 'แกน'),
        'v1': 20,
      },
    if (id == 'chord' ||
        id == 'adjacency_matrix' ||
        id == 'alluvial' ||
        id == 'sankey')
      {
        'src': lbl('Start', 'Início', 'เริ่ม'),
        'dst': lbl('Store', 'Banco', 'คลัง'),
        'grp': lbl('Edge', 'Borda', 'ขอบ'),
        'v1': 25,
      },
  ];
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'diagram_$id',
      title: _localizedTitle(lang, id),
      description: 'Realistic diagram fixture ($id)',
      equation: null,
      fields: [
        FieldInfo(
          name: 'src',
          label: lbl('Source', 'Origem', 'ต้นทาง'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'dst',
          label: lbl('Target', 'Destino', 'ปลายทาง'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'grp',
          label: lbl('Lane', 'Raia', 'กลุ่ม'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Flow', 'Fluxo', 'ปริมาณ'),
          type: 'integer',
          role: 'measure',
          unit: 'u',
        ),
      ],
      filters: const [],
      meta: const DatasetMeta(
        source: 'Fixture',
        sourceUrl: 'https://reports.asodya.com',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        timezone: 'UTC',
        freshnessMode: 'daily',
        expectedRefreshMinutes: 60,
        updatedAt: 1700000000,
        tier: 'public',
      ),
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

DatasetPage _makeSetsPage(
  String id, {
  String dimField = 'item',
  String lang = 'en',
}) {
  final isTh = lang == 'th';
  final isPt = lang == 'pt-BR';
  String lbl(String en, String pt, String th) => isTh ? th : (isPt ? pt : en);
  final a = lbl('Core', 'Núcleo', 'แกน');
  final b = lbl('Cloud', 'Nuvem', 'คลาวด์');
  final c = lbl('Edge', 'Borda', 'ขอบ');
  final d = lbl('Mobile', 'Móvel', 'มือถือ');
  final rows = <Map<String, dynamic>>[
    {dimField: a, 'v1': 42},
    {dimField: b, 'v1': 35},
    {dimField: c, 'v1': 28},
    {dimField: d, 'v1': 18},
    {dimField: '$a & $b', 'v1': 22},
    {dimField: '$b & $c', 'v1': 14},
    {dimField: '$c & $d', 'v1': 10},
    {dimField: '$a & $b & $d', 'v1': 8},
  ];
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'sets_$id',
      title: _localizedTitle(lang, id),
      description: 'Realistic sets fixture with intersections ($id)',
      equation: null,
      fields: [
        FieldInfo(
          name: dimField,
          label: lbl('Sets', 'Conjuntos', 'กลุ่ม'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Count', 'Contagem', 'จำนวน'),
          type: 'integer',
          role: 'measure',
          unit: 'u',
        ),
      ],
      filters: const [],
      meta: const DatasetMeta(
        source: 'Fixture',
        sourceUrl: 'https://reports.asodya.com',
        periodStart: '2026-01-01',
        periodEnd: '2026-01-31',
        timezone: 'UTC',
        freshnessMode: 'daily',
        expectedRefreshMinutes: 60,
        updatedAt: 1700000000,
        tier: 'public',
      ),
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

DatasetPage _makeGeoPage(
  String id, {
  String dimField = 'item',
  String lang = 'en',
}) {
  final isTh = lang == 'th';
  final isPt = lang == 'pt-BR';
  String lbl(String en, String pt, String th) => isTh ? th : (isPt ? pt : en);

  if (id == 'choropleth') {
    final rows = [
      {dimField: 'TH-10', 'v1': 1420},
      {dimField: 'TH-50', 'v1': 680},
      {dimField: 'TH-83', 'v1': 540},
      {dimField: 'TH-40', 'v1': 490},
      {dimField: 'TH-30', 'v1': 430},
      {dimField: 'TH-90', 'v1': 380},
      {dimField: 'TH-20', 'v1': 720},
      {dimField: 'TH-57', 'v1': 310},
    ];
    return DatasetPage(
      descriptor: DatasetDescriptor(
        datasetId: 'geo_$id',
        title: _localizedTitle(lang, id),
        description: 'Thailand provinces Natural Earth admin-1 fixture',
        equation: null,
        fields: [
          FieldInfo(
            name: dimField,
            label: lbl('Province', 'Província', 'จังหวัด'),
            type: 'string',
            role: 'dimension',
          ),
          FieldInfo(
            name: 'v1',
            label: lbl('Volume', 'Volume', 'ปริมาณ'),
            type: 'integer',
            role: 'measure',
            unit: 'u',
          ),
        ],
        filters: const [],
      ),
      rows: rows,
      offset: 0,
      limit: rows.length,
      totalRows: rows.length,
    );
  }

  if (id == 'hex_tile_map') {
    final rows = [
      {dimField: 'BR-SP', 'v1': 1640},
      {dimField: 'BR-RJ', 'v1': 920},
      {dimField: 'BR-MG', 'v1': 780},
      {dimField: 'BR-BA', 'v1': 610},
      {dimField: 'BR-RS', 'v1': 540},
      {dimField: 'BR-PR', 'v1': 520},
      {dimField: 'BR-AM', 'v1': 290},
    ];
    return DatasetPage(
      descriptor: DatasetDescriptor(
        datasetId: 'geo_$id',
        title: _localizedTitle(lang, id),
        description: 'Brazil states Natural Earth admin-1 fixture',
        equation: null,
        fields: [
          FieldInfo(
            name: dimField,
            label: lbl('State', 'Estado', 'รัฐ'),
            type: 'string',
            role: 'dimension',
          ),
          FieldInfo(
            name: 'v1',
            label: lbl('Index', 'Índice', 'ดัชนี'),
            type: 'integer',
            role: 'measure',
            unit: 'u',
          ),
        ],
        filters: const [],
      ),
      rows: rows,
      offset: 0,
      limit: rows.length,
      totalRows: rows.length,
    );
  }

  final rows = [
    {
      dimField: lbl('Bangkok', 'Bangkok', 'กรุงเทพ'),
      'lat': 13.75,
      'lon': 100.50,
      'v1': 1420,
    },
    {
      dimField: lbl('Chiang Mai', 'Chiang Mai', 'เชียงใหม่'),
      'lat': 18.79,
      'lon': 98.98,
      'v1': 640,
    },
    {
      dimField: lbl('São Paulo', 'São Paulo', 'เซาเปาโล'),
      'lat': -23.55,
      'lon': -46.63,
      'v1': 1180,
    },
    {
      dimField: lbl('Tokyo', 'Tóquio', 'โตเกียว'),
      'lat': 35.68,
      'lon': 139.77,
      'v1': 960,
    },
    {
      dimField: lbl('London', 'Londres', 'ลอนดอน'),
      'lat': 51.51,
      'lon': -0.13,
      'v1': 840,
    },
    {
      dimField: lbl('New York', 'Nova York', 'นิวยอร์ก'),
      'lat': 40.71,
      'lon': -74.01,
      'v1': 910,
    },
  ];
  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'geo_$id',
      title: _localizedTitle(lang, id),
      description: 'Global cities coordinate fixture ($id)',
      equation: null,
      fields: [
        FieldInfo(
          name: dimField,
          label: lbl('City', 'Cidade', 'เมือง'),
          type: 'string',
          role: 'dimension',
        ),
        const FieldInfo(
          name: 'lat',
          label: 'Lat',
          type: 'latitude',
          role: 'dimension',
        ),
        const FieldInfo(
          name: 'lon',
          label: 'Lon',
          type: 'longitude',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Traffic', 'Tráfego', 'ปริมาณ'),
          type: 'integer',
          role: 'measure',
          unit: 'u',
        ),
      ],
      filters: const [],
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

DatasetPage _makeIndicatorPage(
  String id, {
  String dimField = 'item',
  String lang = 'en',
}) {
  final isTh = lang == 'th';
  final isPt = lang == 'pt-BR';
  String lbl(String en, String pt, String th) => isTh ? th : (isPt ? pt : en);

  final (fields, rows) = switch (id) {
    'kpi' => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Segment', 'Segmento', 'กลุ่ม'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Throughput', 'Vazão', 'ปริมาณงาน'),
          type: 'integer',
          role: 'measure',
          unit: 'ops',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Availability', 'Disponibilidade', 'ความพร้อมใช้'),
          type: 'float',
          role: 'measure',
          unit: '%',
        ),
      ],
      [
        {
          dimField: lbl('Core Cluster', 'Núcleo Principal', 'คลัสเตอร์หลัก'),
          'v1': 12480,
          'v2': 99.4,
        },
      ],
    ),
    'kpi_sparkline' => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Period', 'Período', 'ช่วงเวลา'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Daily Requests', 'Requisições Diárias', 'คำขอรายวัน'),
          type: 'integer',
          role: 'measure',
          unit: 'req',
        ),
      ],
      const [
        {'item': 'D1', 'v1': 1120},
        {'item': 'D2', 'v1': 1185},
        {'item': 'D3', 'v1': 1210},
        {'item': 'D4', 'v1': 1265},
        {'item': 'D5', 'v1': 1295},
        {'item': 'D6', 'v1': 1340},
      ],
    ),
    'status_scorecard' => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Service', 'Serviço', 'บริการ'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Score', 'Nota', 'คะแนน'),
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Target', 'Meta', 'เป้าหมาย'),
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
      ],
      [
        {
          dimField: lbl('API Gateway', 'Gateway API', 'เกตเวย์หลัก'),
          'v1': 98,
          'v2': 95,
        },
        {
          dimField: lbl('Vector Cache', 'Cache Vetorial', 'แคชเวกเตอร์'),
          'v1': 84,
          'v2': 80,
        },
        {
          dimField: lbl('Batch Queue', 'Fila em Lote', 'คิวประมวลผล'),
          'v1': 32,
          'v2': 85,
        },
        {
          dimField: lbl('Search Index', 'Índice de Busca', 'ดัชนีค้นหา'),
          'v1': 71,
          'v2': 75,
        },
      ],
    ),
    'word_cloud' => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Topic', 'Tópico', 'หัวข้อ'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Mentions', 'Menções', 'ความถี่'),
          type: 'integer',
          role: 'measure',
          unit: 'u',
        ),
      ],
      [
        {
          dimField: lbl('Neural Search', 'Busca Neural', 'การค้นหาเชิงลึก'),
          'v1': 96,
        },
        {dimField: lbl('Rust Async', 'Rust Assíncrono', 'ระบบขนาน'), 'v1': 82},
        {
          dimField: lbl('Flutter UI', 'Interface Flutter', 'ส่วนติดต่อผู้ใช้'),
          'v1': 70,
        },
        {dimField: lbl('PostgreSQL', 'PostgreSQL', 'ฐานข้อมูล'), 'v1': 58},
        {
          dimField: lbl('Valkey Cache', 'Cache Valkey', 'หน่วยความจำแคช'),
          'v1': 45,
        },
        {dimField: lbl('OpenAlex', 'OpenAlex', 'เอกสารวิจัย'), 'v1': 36},
      ],
    ),
    _ => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Region', 'Região', 'ภูมิภาค'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Revenue', 'Receita', 'รายได้'),
          type: 'integer',
          role: 'measure',
          unit: 'pts',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Growth', 'Crescimento', 'เติบโต'),
          type: 'integer',
          role: 'measure',
          unit: '%',
        ),
      ],
      [
        {dimField: _localizedCategory(lang, 0), 'v1': 88, 'v2': 24},
        {dimField: _localizedCategory(lang, 1), 'v1': 64, 'v2': 18},
        {dimField: _localizedCategory(lang, 2), 'v1': 52, 'v2': 12},
        {dimField: _localizedCategory(lang, 3), 'v1': 37, 'v2': 9},
      ],
    ),
  };

  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'indicator_$id',
      title: _localizedTitle(lang, id),
      description: 'Realistic indicator fixture ($id)',
      equation: null,
      fields: fields,
      filters: const [],
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

DatasetPage _makeSciencePage(
  String id, {
  String dimField = 'item',
  String lang = 'en',
}) {
  final isTh = lang == 'th';
  final isPt = lang == 'pt-BR';
  String lbl(String en, String pt, String th) => isTh ? th : (isPt ? pt : en);

  final (fields, rows) = switch (id) {
    'top_k_prob' => (
      [
        FieldInfo(
          name: dimField,
          label: lbl('Class', 'Classe', 'คลาส'),
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Prob', 'Probabilidade', 'ความน่าจะเป็น'),
          type: 'float',
          role: 'measure',
        ),
      ],
      [
        {dimField: lbl('Pneumonia', 'Pneumonia', 'ปอดอักเสบ'), 'v1': 0.56},
        {dimField: lbl('Bronchitis', 'Bronquite', 'หลอดลมอักเสบ'), 'v1': 0.22},
        {dimField: lbl('Normal', 'Normal', 'ปกติ'), 'v1': 0.12},
        {
          dimField: lbl('Effusion', 'Efusão', 'น้ำในช่องเยื่อหุ้มปอด'),
          'v1': 0.06,
        },
        {dimField: lbl('Edema', 'Edema', 'ภาวะบวมน้ำ'), 'v1': 0.04},
      ],
    ),
    'roc_pr' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Sample',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Score', 'Escore', 'คะแนนทำนาย'),
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('True Label', 'Rótulo Real', 'ค่าจริง'),
          type: 'integer',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'S01', 'v1': 0.96, 'v2': 1},
        {'item': 'S02', 'v1': 0.91, 'v2': 1},
        {'item': 'S03', 'v1': 0.85, 'v2': 1},
        {'item': 'S04', 'v1': 0.78, 'v2': 0},
        {'item': 'S05', 'v1': 0.72, 'v2': 1},
        {'item': 'S06', 'v1': 0.64, 'v2': 1},
        {'item': 'S07', 'v1': 0.53, 'v2': 0},
        {'item': 'S08', 'v1': 0.46, 'v2': 1},
        {'item': 'S09', 'v1': 0.34, 'v2': 0},
        {'item': 'S10', 'v1': 0.25, 'v2': 0},
        {'item': 'S11', 'v1': 0.16, 'v2': 0},
        {'item': 'S12', 'v1': 0.07, 'v2': 0},
      ],
    ),
    'calibration' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Sample',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Pred Prob', 'Prob Predita', 'ความน่าจะเป็น'),
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Outcome', 'Desfecho', 'ผลลัพธ์จริง'),
          type: 'integer',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'P01', 'v1': 0.08, 'v2': 0},
        {'item': 'P02', 'v1': 0.14, 'v2': 0},
        {'item': 'P03', 'v1': 0.24, 'v2': 0},
        {'item': 'P04', 'v1': 0.32, 'v2': 1},
        {'item': 'P05', 'v1': 0.45, 'v2': 0},
        {'item': 'P06', 'v1': 0.52, 'v2': 1},
        {'item': 'P07', 'v1': 0.66, 'v2': 1},
        {'item': 'P08', 'v1': 0.73, 'v2': 1},
        {'item': 'P09', 'v1': 0.86, 'v2': 1},
        {'item': 'P10', 'v1': 0.94, 'v2': 1},
      ],
    ),
    'confusion_matrix' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Sample',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Predicted', 'Predito', 'ค่าทำนาย'),
          type: 'integer',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Actual', 'Real', 'ค่าจริง'),
          type: 'integer',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'M01', 'v1': 0, 'v2': 0},
        {'item': 'M02', 'v1': 0, 'v2': 0},
        {'item': 'M03', 'v1': 0, 'v2': 0},
        {'item': 'M04', 'v1': 1, 'v2': 0},
        {'item': 'M05', 'v1': 1, 'v2': 1},
        {'item': 'M06', 'v1': 1, 'v2': 1},
        {'item': 'M07', 'v1': 1, 'v2': 1},
        {'item': 'M08', 'v1': 2, 'v2': 1},
        {'item': 'M09', 'v1': 2, 'v2': 2},
        {'item': 'M10', 'v1': 2, 'v2': 2},
        {'item': 'M11', 'v1': 2, 'v2': 2},
        {'item': 'M12', 'v1': 0, 'v2': 2},
      ],
    ),
    'learning_curve' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Epoch',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Train loss', 'Perda treino', 'ค่าสูญเสียฝึก'),
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Val loss', 'Perda val', 'ค่าสูญเสียตรวจ'),
          type: 'float',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'E1', 'v1': 0.94, 'v2': 0.98},
        {'item': 'E2', 'v1': 0.68, 'v2': 0.74},
        {'item': 'E3', 'v1': 0.49, 'v2': 0.56},
        {'item': 'E4', 'v1': 0.36, 'v2': 0.44},
        {'item': 'E5', 'v1': 0.27, 'v2': 0.37},
        {'item': 'E6', 'v1': 0.21, 'v2': 0.34},
      ],
    ),
    'wright_map' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Item',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Person logit', 'Logit pessoa', 'ความสามารถผู้สอบ'),
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Item logit', 'Logit item', 'ความยากข้อสอบ'),
          type: 'float',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'Q1', 'v1': -2.1, 'v2': -1.8},
        {'item': 'Q2', 'v1': -1.3, 'v2': -0.9},
        {'item': 'Q3', 'v1': -0.6, 'v2': -0.3},
        {'item': 'Q4', 'v1': 0.1, 'v2': 0.2},
        {'item': 'Q5', 'v1': 0.5, 'v2': 0.8},
        {'item': 'Q6', 'v1': 1.1, 'v2': 1.5},
        {'item': 'Q7', 'v1': 1.8, 'v2': 2.1},
      ],
    ),
    'irt_icc' || 'irt_iif' || 'item_diff_disc' => (
      [
        FieldInfo(
          name: dimField,
          label: 'Item',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Difficulty (b)', 'Dificuldade (b)', 'ความยาก b'),
          type: 'float',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Discrimination (a)', 'Discriminação (a)', 'อำนาจจำแนก a'),
          type: 'float',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'Item 1', 'v1': -1.4, 'v2': 0.9},
        {'item': 'Item 2', 'v1': -0.2, 'v2': 1.8},
        {'item': 'Item 3', 'v1': 0.9, 'v2': 1.3},
        {'item': 'Item 4', 'v1': 1.6, 'v2': 2.3},
      ],
    ),
    _ => (
      [
        FieldInfo(
          name: dimField,
          label: 'Patient',
          type: 'string',
          role: 'dimension',
        ),
        FieldInfo(
          name: 'v1',
          label: lbl('Months', 'Meses', 'เดือน'),
          type: 'integer',
          role: 'measure',
        ),
        FieldInfo(
          name: 'v2',
          label: lbl('Event', 'Evento', 'เหตุการณ์'),
          type: 'integer',
          role: 'measure',
        ),
      ],
      const [
        {'item': 'P1', 'v1': 2, 'v2': 1},
        {'item': 'P2', 'v1': 4, 'v2': 0},
        {'item': 'P3', 'v1': 6, 'v2': 1},
        {'item': 'P4', 'v1': 8, 'v2': 1},
        {'item': 'P5', 'v1': 11, 'v2': 0},
        {'item': 'P6', 'v1': 14, 'v2': 1},
        {'item': 'P7', 'v1': 18, 'v2': 1},
      ],
    ),
  };

  return DatasetPage(
    descriptor: DatasetDescriptor(
      datasetId: 'science_$id',
      title: _localizedTitle(lang, id),
      description: 'Realistic science/AI fixture ($id)',
      equation: null,
      fields: fields,
      filters: const [],
    ),
    rows: rows,
    offset: 0,
    limit: rows.length,
    totalRows: rows.length,
  );
}

Future<void> _pumpAndGolden(
  WidgetTester tester, {
  required String group,
  required String id,
  required String dimSlot,
  required String dimType,
  required String dimField,
  required int count,
  required bool twoMeasures,
  bool captureFullCard = false,
}) async {
  for (final locale in const [Locale('en'), Locale('pt', 'BR'), Locale('th')]) {
    final tag = locale.toLanguageTag();
    final isDiag = group == 'diagram';
    final isSets = group == 'sets';
    final page = isDiag
        ? _makeDiagramPage(id, lang: tag)
        : isSets
        ? _makeSetsPage(id, dimField: dimField, lang: tag)
        : group == 'geo'
        ? _makeGeoPage(id, dimField: dimField, lang: tag)
        : group == 'indicator'
        ? _makeIndicatorPage(id, dimField: dimField, lang: tag)
        : group == 'science'
        ? _makeSciencePage(id, dimField: dimField, lang: tag)
        : _makePage('${group}_$id', dimField, dimType, count, lang: tag);
    final tpl = VisualTemplate(
      templateId: id,
      version: 1,
      kind: isDiag ? 'diagram' : 'chart',
      visual: id,
      title: _localizedTitle(tag, id),
      slots: [
        TemplateSlot(
          slotName: dimSlot,
          role: 'dimension',
          minCount: isDiag ? 2 : 1,
          maxCount: isDiag ? 3 : 1,
          acceptedTypes: [dimType],
        ),
        TemplateSlot(
          slotName: 'value',
          role: 'measure',
          minCount: twoMeasures ? 2 : 1,
          maxCount: twoMeasures ? 2 : 1,
          acceptedTypes: const ['integer', 'float'],
        ),
      ],
    );
    final binding = CardVisualBinding(
      template: id,
      version: 1,
      mapping: {
        dimSlot: isDiag ? ['src', 'dst', 'grp'] : [dimField],
        'value': twoMeasures ? ['v1', 'v2'] : ['v1'],
      },
    );
    final chart = VisualChooser.buildTemplate(
      page: page,
      template: tpl,
      binding: binding,
      title: _localizedTitle(tag, id),
    );
    final key = UniqueKey();
    final fullCardCapture = captureFullCard && tag == 'pt-BR';
    await tester.pumpWidget(
      MaterialApp(
        theme: _palette.toTheme(Brightness.light),
        home: Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale,
            child: Scaffold(
              body: fullCardCapture
                  ? SingleChildScrollView(
                      child: Center(
                        child: RepaintBoundary(
                          key: key,
                          child: SizedBox(width: 480, child: chart),
                        ),
                      ),
                    )
                  : RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 480,
                        height: 360,
                        child: SingleChildScrollView(child: chart),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    if (group == 'indicator' || group == 'geo' || group == 'science') {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    if (fullCardCapture) {
      final expectedTitle = _localizedTitle(tag, id);
      final titleFinder = find.text(expectedTitle);
      expect(titleFinder, findsOneWidget);
      final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);
      expect(titleParagraph.text.toPlainText(), expectedTitle);
      expect(titleParagraph.didExceedMaxLines, isFalse);

      final cardRect = tester.getRect(find.byType(ChartFrame));
      final captureRect = tester.getRect(find.byKey(key));
      final footerFinder = find.text('Atualizado: 1700000000 (UTC)');
      expect(footerFinder, findsOneWidget);
      final footerRect = tester.getRect(footerFinder);
      expect(cardRect.left, greaterThanOrEqualTo(captureRect.left));
      expect(cardRect.top, greaterThanOrEqualTo(captureRect.top));
      expect(cardRect.right, lessThanOrEqualTo(captureRect.right));
      expect(cardRect.bottom, lessThanOrEqualTo(captureRect.bottom));
      expect(footerRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(footerRect.top, greaterThanOrEqualTo(cardRect.top));
      expect(footerRect.right, lessThanOrEqualTo(cardRect.right));
      expect(footerRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    }
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/$group/${id}_$tag.png'),
    );
  }
}

void main() {
  setUpAll(_loadReportsFonts);

  const comparisonIds = [
    'vertical_bar',
    'horizontal_bar',
    'ranking_bar',
    'grouped_bar',
    'stacked_bar',
    'stacked_bar_100',
    'diverging_bar',
    'floating_bar',
    'lollipop',
    'dot_plot',
    'dumbbell',
    'slope',
    'bullet',
    'utilization_bar',
    'pictogram',
    'radial_bar',
    'circular_bar',
    'radar',
    'parallel_coordinates',
    'marimekko',
    'waterfall',
    'pareto',
    'small_multiples',
  ];
  const twoMeasureComparison = {
    'grouped_bar',
    'stacked_bar',
    'stacked_bar_100',
    'diverging_bar',
    'floating_bar',
    'dumbbell',
    'slope',
    'bullet',
    'utilization_bar',
    'parallel_coordinates',
    'marimekko',
  };

  const timeIds = [
    'line',
    'step_line',
    'area',
    'stacked_area',
    'stacked_area_100',
    'streamgraph',
    'sparkline',
    'bump_chart',
    'candlestick',
    'range_band',
    'combo',
    'annotated_line',
    'timeline',
    'gantt',
    'calendar_heatmap',
    'horizon',
    'control_chart',
    'burndown',
    'cycle_plot',
    'curve',
  ];
  const twoMeasureTime = {
    'stacked_area',
    'stacked_area_100',
    'streamgraph',
    'candlestick',
    'range_band',
    'combo',
    'gantt',
  };

  const partWholeIds = [
    'donut',
    'pie',
    'gauge',
    'meter',
    'treemap',
    'sunburst',
    'icicle',
    'circle_packing',
    'waffle',
    'nightingale_rose',
    'funnel',
  ];

  const distIds = [
    'histogram',
    'box_plot',
    'violin',
    'density',
    'ridgeline',
    'strip',
    'ecdf',
    'qq_plot',
    'population_pyramid',
    'raincloud',
  ];

  const relationIds = [
    'scatter',
    'bubble',
    'heatmap',
    'correlation_matrix',
    'hexbin',
    'contour_2d',
    'splom',
    'quadrant',
    'ternary',
  ];

  const diagramIds = [
    'sankey',
    'alluvial',
    'chord',
    'arc_diagram',
    'flowchart',
    'layered_dag',
    'sequence_diagram',
    'state_diagram',
    'swimlane',
    'tree_org',
    'dendrogram',
    'mind_map',
    'network',
    'adjacency_matrix',
    'er_diagram',
    'architecture_diagram',
  ];
  const setsIds = ['venn', 'euler', 'upset'];
  const geoIds = [
    'bubble_map',
    'choropleth',
    'geo_heatmap',
    'flow_map',
    'hex_tile_map',
  ];
  const indicatorIds = [
    'kpi',
    'kpi_sparkline',
    'table',
    'heat_table',
    'status_scorecard',
    'word_cloud',
  ];
  const scienceIds = [
    'top_k_prob',
    'calibration',
    'confusion_matrix',
    'roc_pr',
    'learning_curve',
    'irt_icc',
    'irt_iif',
    'wright_map',
    'item_diff_disc',
    'kaplan_meier',
  ];

  for (final id in comparisonIds) {
    testWidgets('golden comparison/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'comparison',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cat',
        count: 6,
        twoMeasures: twoMeasureComparison.contains(id),
        captureFullCard: id == 'parallel_coordinates',
      );
    });
  }

  for (final id in timeIds) {
    testWidgets('golden time/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'time',
        id: id,
        dimSlot: 'time',
        dimType: 'date',
        dimField: 'day',
        count: 8,
        twoMeasures: twoMeasureTime.contains(id),
      );
    });
  }

  for (final id in partWholeIds) {
    testWidgets('golden part_whole/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'part_whole',
        id: id,
        dimSlot: 'part',
        dimType: 'string',
        dimField: 'part',
        count: 5,
        twoMeasures: false,
      );
    });
  }

  for (final id in distIds) {
    testWidgets('golden distribution/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'distribution',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'cohort',
        count: 8,
        twoMeasures: false,
        captureFullCard: id == 'population_pyramid',
      );
    });
  }

  for (final id in relationIds) {
    testWidgets('golden relation/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'relation',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 6,
        twoMeasures: true,
      );
    });
  }

  for (final id in diagramIds) {
    testWidgets('golden diagram/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'diagram',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 6,
        twoMeasures: false,
        captureFullCard: id == 'architecture_diagram',
      );
    });
  }

  for (final id in setsIds) {
    testWidgets('golden sets/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'sets',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 5,
        twoMeasures: false,
      );
    });
  }

  for (final id in geoIds) {
    testWidgets('golden geo/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'geo',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 6,
        twoMeasures: false,
      );
    });
  }

  for (final (name, pal, brightness) in [
    ('choropleth_narrow_light_en', _palette, Brightness.light),
    ('choropleth_narrow_dark_en', _darkPalette, Brightness.dark),
  ]) {
    testWidgets('golden geo/$name', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 420);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final page = _makeGeoPage('choropleth', dimField: 'item', lang: 'en');
      const tpl = VisualTemplate(
        templateId: 'choropleth',
        version: 1,
        kind: 'chart',
        visual: 'choropleth',
        title: 'Choropleth Narrow Contrast',
        slots: [
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
      const binding = CardVisualBinding(
        template: 'choropleth',
        version: 1,
        mapping: {
          'category': ['item'],
          'value': ['v1'],
        },
      );
      final key = UniqueKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: pal.toTheme(brightness),
          home: Scaffold(
            backgroundColor: pal.canvas,
            body: SingleChildScrollView(
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 360,
                    child: VisualChooser.buildTemplate(
                      page: page,
                      template: tpl,
                      binding: binding,
                      title: _localizedTitle('en', 'choropleth'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final frameFinder = find.byType(ChartFrame);
      final geoSummary = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.contains(naturalEarthAttribution) ??
                false),
      );
      final mapCanvas = find
          .descendant(of: geoSummary, matching: find.byType(CustomPaint))
          .first;
      expect(frameFinder, findsOneWidget);
      expect(geoSummary, findsOneWidget);
      expect(mapCanvas, findsOneWidget);
      expect(find.text('Period unavailable'), findsOneWidget);
      expect(find.text('Last update unavailable'), findsOneWidget);
      final frameRect = tester.getRect(frameFinder);
      final mapRect = tester.getRect(mapCanvas);
      final footerRect = tester.getRect(find.text('Last update unavailable'));
      expect(
        frameRect.contains(mapRect.topLeft),
        isTrue,
        reason: 'frame=$frameRect map=$mapRect',
      );
      expect(
        frameRect.contains(mapRect.bottomRight),
        isTrue,
        reason: 'frame=$frameRect map=$mapRect',
      );
      expect(
        frameRect.contains(footerRect.topLeft),
        isTrue,
        reason: 'frame=$frameRect footer=$footerRect',
      );
      expect(
        frameRect.contains(footerRect.bottomRight),
        isTrue,
        reason: 'frame=$frameRect footer=$footerRect',
      );
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/geo/$name.png'),
      );
    });
  }

  for (final id in indicatorIds) {
    testWidgets('golden indicator/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'indicator',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 6,
        twoMeasures: id == 'heat_table' || id == 'status_scorecard',
      );
    });
  }

  for (final id in scienceIds) {
    testWidgets('golden science/$id', (tester) async {
      await _pumpAndGolden(
        tester,
        group: 'science',
        id: id,
        dimSlot: 'category',
        dimType: 'string',
        dimField: 'item',
        count: 6,
        twoMeasures: id != 'top_k_prob',
      );
    });
  }

  testWidgets('size limits measurement across 10, 50, 200, 500 rows', (
    tester,
  ) async {
    for (final n in [10, 50, 200, 500]) {
      final p = _makePage('bench_$n', 'cat', 'string', n);
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: _palette.toTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 360,
              child: Column(
                children: [
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.treemap),
                    ),
                  ),
                  Expanded(
                    child: VisualChooser.build(
                      p,
                      const Slot('bench', visual: Visual.streamgraph),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      sw.stop();
      // ignore: avoid_print
      print('SIZE_LIMIT_ROWS=$n RENDER_MS=${sw.elapsedMilliseconds}');
      expect(tester.takeException(), isNull);
    }
  });
}
