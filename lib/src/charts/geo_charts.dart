import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Projected geographic datum extracted from [DatasetPage] rows.
class GeoPointDatum {
  final String label;
  final double lat;
  final double lon;
  final double value;

  const GeoPointDatum({
    required this.label,
    required this.lat,
    required this.lon,
    required this.value,
  });
}

/// Renders geographic catalog visuals 94 to 98 (`bubble_map`, `choropleth`,
/// `geo_heatmap`, `flow_map`, `hex_tile_map`) from real [DatasetPage] rows
/// using [ReportPalette] tokens and [Semantics] summaries (C1 to C23).
class GeoCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final FieldInfo label;
  final FieldInfo value;
  final double height;

  /// Maximum regions/tiles rendered before capping to preserve legibility.
  static const int maxRegions = 24;

  const GeoCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.label,
    required this.value,
    this.height = 260,
  });

  /// Extracts `(lat, lon, value)` points from [page.rows], deriving deterministic
  /// grid coordinates from row index when explicit `latitude`/`longitude` fields
  /// are absent.
  static List<GeoPointDatum> extractPoints(
    DatasetPage page,
    FieldInfo label,
    FieldInfo value,
  ) {
    String? latName;
    String? lonName;
    for (final f in page.descriptor.fields) {
      if (f.type == 'latitude') latName ??= f.name;
      if (f.type == 'longitude') lonName ??= f.name;
    }
    final out = <GeoPointDatum>[];
    for (var i = 0; i < page.rows.length && out.length < maxRegions; i++) {
      final r = page.rows[i];
      final lbl = ChartParts.xLabel(r[label.name], label);
      final v = (measureValue(r[value.name], value) ?? 0.0).abs();
      final lat = latName != null && r[latName] is num
          ? (r[latName] as num).toDouble()
          : -30.0 + (i ~/ 4) * 20.0;
      final lon = lonName != null && r[lonName] is num
          ? (r[lonName] as num).toDouble()
          : -90.0 + (i % 4) * 55.0;
      out.add(GeoPointDatum(label: lbl, lat: lat, lon: lon, value: v));
    }
    return out;
  }

  /// Normalizes `(lon, lat)` coordinates into `0..1` viewport fractions.
  static List<Offset> projectPoints(List<GeoPointDatum> pts) {
    if (pts.isEmpty) return const [];
    var minLat = pts.first.lat;
    var maxLat = pts.first.lat;
    var minLon = pts.first.lon;
    var maxLon = pts.first.lon;
    for (final p in pts) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    final latSpan = (maxLat - minLat).abs() < 1e-6 ? 1.0 : maxLat - minLat;
    final lonSpan = (maxLon - minLon).abs() < 1e-6 ? 1.0 : maxLon - minLon;
    return [
      for (final p in pts)
        Offset(
          ((p.lon - minLon) / lonSpan).clamp(0.0, 1.0),
          (1.0 - (p.lat - minLat) / latSpan).clamp(0.0, 1.0),
        ),
    ];
  }

  /// Computes a `grid x grid` spatial density matrix for [geoHeatmap].
  static List<List<double>> computeGeoHeatmapGrid(
    List<GeoPointDatum> pts, {
    int grid = 8,
  }) {
    final norm = projectPoints(pts);
    final mat = List.generate(grid, (_) => List<double>.filled(grid, 0.0));
    for (var i = 0; i < pts.length; i++) {
      final gx = (norm[i].dx * (grid - 1)).round().clamp(0, grid - 1);
      final gy = (norm[i].dy * (grid - 1)).round().clamp(0, grid - 1);
      mat[gy][gx] += pts[i].value;
    }
    return mat;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final pts = extractPoints(page, label, value);
    final summary =
        '${visual.name}: ${pts.take(4).map((e) => e.label).join(', ')} (${pts.length})';
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _GeoPainter(visual: visual, pts: pts, palette: p),
          ),
        ),
      ),
    );
  }
}

class _GeoPainter extends CustomPainter {
  final Visual visual;
  final List<GeoPointDatum> pts;
  final ReportPalette palette;

  const _GeoPainter({
    required this.visual,
    required this.pts,
    required this.palette,
  });

  double get _maxV => pts.map((p) => p.value).fold<double>(1.0, math.max);

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 72,
    double fontSize = 9,
    Color? color,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? palette.textPrimary,
          fontSize: fontSize,
          fontFamily: ReportPalette.font,
          fontFamilyFallback: ReportPalette.fontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, center ? pos - Offset(tp.width / 2, tp.height / 2) : pos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || pts.isEmpty) return;
    final plot = Rect.fromLTWH(20, 14, size.width - 40, size.height - 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(6)),
      Paint()..color = palette.surface,
    );
    switch (visual) {
      case Visual.bubbleMap:
        _paintBubbleMap(canvas, plot);
      case Visual.choropleth:
        _paintChoropleth(canvas, plot);
      case Visual.geoHeatmap:
        _paintGeoHeatmap(canvas, plot);
      case Visual.flowMap:
        _paintFlowMap(canvas, plot);
      case Visual.hexTileMap:
      default:
        _paintHexTileMap(canvas, plot);
    }
  }

  void _paintBubbleMap(Canvas canvas, Rect plot) {
    final norm = GeoCatalogChart.projectPoints(pts);
    final maxV = _maxV;
    for (var i = 0; i < pts.length; i++) {
      final pos = Offset(
        plot.left + 20 + norm[i].dx * math.max(10, plot.width - 40),
        plot.top + 20 + norm[i].dy * math.max(10, plot.height - 40),
      );
      final r = 5.0 + 14.0 * math.sqrt((pts[i].value / maxV).clamp(0.0, 1.0));
      final c = palette.seriesAt(i);
      canvas.drawCircle(pos, r, Paint()..color = c.withValues(alpha: 0.45));
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      _drawText(canvas, pts[i].label, pos + Offset(0, r + 6), center: true);
    }
  }

  void _paintChoropleth(Canvas canvas, Rect plot) {
    final cols = math.min(4, math.max(2, math.sqrt(pts.length).ceil()));
    final rows = (pts.length / cols).ceil();
    final cw = (plot.width - 16) / cols;
    final ch = (plot.height - 16) / rows;
    final maxV = _maxV;
    for (var i = 0; i < pts.length; i++) {
      final r = i ~/ cols;
      final c = i % cols;
      final rect = Rect.fromLTWH(plot.left + 8 + c * cw + 2, plot.top + 8 + r * ch + 2, cw - 4, ch - 4);
      final t = (pts[i].value / maxV).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = Color.lerp(palette.surfaceAlt, palette.accent, 0.2 + 0.8 * t)!,
      );
      _drawText(
        canvas,
        '${pts[i].label} ${pts[i].value.toStringAsFixed(0)}',
        rect.center,
        maxWidth: cw - 8,
        color: t > 0.55 ? palette.onAccent : palette.textPrimary,
        center: true,
      );
    }
  }

  void _paintGeoHeatmap(Canvas canvas, Rect plot) {
    const grid = 8;
    final mat = GeoCatalogChart.computeGeoHeatmapGrid(pts, grid: grid);
    final cw = (plot.width - 16) / grid;
    final ch = (plot.height - 16) / grid;
    var maxCell = 1.0;
    for (final row in mat) {
      for (final v in row) {
        if (v > maxCell) maxCell = v;
      }
    }
    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        final v = mat[gy][gx];
        if (v <= 0) continue;
        final t = (v / maxCell).clamp(0.0, 1.0);
        final rect = Rect.fromLTWH(plot.left + 8 + gx * cw, plot.top + 8 + gy * ch, cw - 1, ch - 1);
        canvas.drawRect(
          rect,
          Paint()..color = Color.lerp(palette.warning, palette.negative, t)!.withValues(alpha: 0.78),
        );
      }
    }
  }

  void _paintFlowMap(Canvas canvas, Rect plot) {
    final norm = GeoCatalogChart.projectPoints(pts);
    final maxV = _maxV;
    final pos = [
      for (final n in norm)
        Offset(
          plot.left + 20 + n.dx * math.max(10, plot.width - 40),
          plot.top + 20 + n.dy * math.max(10, plot.height - 40),
        ),
    ];
    for (var i = 0; i + 1 < pos.length; i++) {
      final p1 = pos[i];
      final p2 = pos[i + 1];
      final ctrl = Offset((p1.dx + p2.dx) / 2, math.min(p1.dy, p2.dy) - 24);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.accent.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (pts[i].value / maxV) * 3.0,
      );
    }
    for (var i = 0; i < pos.length; i++) {
      canvas.drawCircle(pos[i], 4.5, Paint()..color = palette.seriesAt(i));
      _drawText(canvas, pts[i].label, pos[i] + const Offset(0, 10), center: true);
    }
  }

  void _paintHexTileMap(Canvas canvas, Rect plot) {
    final cols = math.min(4, math.max(2, math.sqrt(pts.length).ceil()));
    final r = math.min(plot.width / (cols * 2.4), plot.height / 4.2).clamp(14.0, 28.0);
    final maxV = _maxV;
    for (var i = 0; i < pts.length; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final cx = plot.left + 32 + col * r * 1.9 + (row.isOdd ? r * 0.95 : 0);
      final cy = plot.top + 28 + row * r * 1.65;
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 6 + k * math.pi / 3;
        final pt = Offset(cx + r * 0.92 * math.cos(a), cy + r * 0.92 * math.sin(a));
        if (k == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      final t = (pts[i].value / maxV).clamp(0.0, 1.0);
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(palette.surfaceAlt, palette.accent, 0.25 + 0.75 * t)!,
      );
      _drawText(
        canvas,
        pts[i].label,
        Offset(cx, cy),
        maxWidth: r * 1.5,
        fontSize: 8,
        color: t > 0.55 ? palette.onAccent : palette.textPrimary,
        center: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GeoPainter old) =>
      old.visual != visual || old.pts != pts || old.palette != palette;
}
