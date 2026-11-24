import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geo/natural_earth_boundaries.dart';
import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Projected geographic datum extracted strictly from real coordinates or ISO boundaries.
class GeoPointDatum {
  final String label;
  final String? isoCode;
  final double lat;
  final double lon;
  final double value;
  final GeoBoundary? boundary;

  const GeoPointDatum({
    required this.label,
    this.isoCode,
    required this.lat,
    required this.lon,
    required this.value,
    this.boundary,
  });
}

/// Geographic bounding box used to project map polygons and points together.
class _GeoViewport {
  final double minLon;
  final double maxLon;
  final double minLat;
  final double maxLat;
  final String? focusCountry;

  const _GeoViewport({
    required this.minLon,
    required this.maxLon,
    required this.minLat,
    required this.maxLat,
    this.focusCountry,
  });

  Offset project(double lon, double lat, Rect plot) {
    final lonSpan = math.max(1e-4, maxLon - minLon);
    final latSpan = math.max(1e-4, maxLat - minLat);
    final x = ((lon - minLon) / lonSpan).clamp(0.0, 1.0);
    final y = (1.0 - (lat - minLat) / latSpan).clamp(0.0, 1.0);
    return Offset(plot.left + x * plot.width, plot.top + y * plot.height);
  }
}

/// Renders geographic catalog visuals 94 to 98 (`bubble_map`, `choropleth`,
/// `geo_heatmap`, `flow_map`, `hex_tile_map`) over bundled Natural Earth admin-0 and
/// admin-1 boundaries using [ReportPalette] tokens and [Semantics] summaries (C1 to C23).
/// Refuses to render invented positions when coordinates and ISO region codes are missing.
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

  /// Whether [v] plots region polygons/tiles keyed by ISO country or admin-1 codes.
  static bool isRegionVisual(Visual v) =>
      v == Visual.choropleth || v == Visual.hexTileMap;

  /// Validates that [page] supplies real latitude/longitude coordinates (point visuals)
  /// or valid ISO 3166-1 / ISO 3166-2 region codes matching Natural Earth (region visuals).
  /// Returns `null` if valid, or a non-empty error description when data must be refused.
  static String? validateGeoData(
    DatasetPage page,
    Visual visual,
    FieldInfo? labelField,
  ) {
    if (page.rows.isEmpty) {
      return 'Geographic visual requires non-empty rows.';
    }
    if (isRegionVisual(visual)) {
      if (labelField == null) {
        return "Visual '${visual.name}' requires an ISO region code dimension.";
      }
      var matched = 0;
      for (final r in page.rows.take(maxRegions)) {
        final code = ChartParts.xLabel(r[labelField.name], labelField);
        if (lookupGeoBoundary(code) != null) matched++;
      }
      if (matched == 0) {
        return "Visual '${visual.name}' requires ISO 3166-1 or ISO 3166-2 region codes (for example TH, BR, TH-10, BR-SP).";
      }
      return null;
    }

    String? latName;
    String? lonName;
    for (final f in page.descriptor.fields) {
      if (f.type == 'latitude') latName ??= f.name;
      if (f.type == 'longitude') lonName ??= f.name;
    }
    if (latName == null || lonName == null) {
      return "Visual '${visual.name}' requires 'latitude' and 'longitude' coordinate fields.";
    }
    var validCoords = 0;
    for (final r in page.rows.take(maxRegions)) {
      final lat = asDouble(r[latName]);
      final lon = asDouble(r[lonName]);
      if (lat != null &&
          lon != null &&
          lat.isFinite &&
          lon.isFinite &&
          lat >= -90 &&
          lat <= 90 &&
          lon >= -180 &&
          lon <= 180) {
        validCoords++;
      }
    }
    if (validCoords == 0) {
      return "Visual '${visual.name}' requires numeric latitude/longitude coordinates.";
    }
    return null;
  }

  /// Extracts geographic data strictly from explicit `latitude`/`longitude` coordinates or
  /// ISO-matched Natural Earth boundaries. Rows lacking valid geometry are omitted; nothing
  /// is invented.
  static List<GeoPointDatum> extractPoints(
    DatasetPage page,
    Visual visual,
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
      final lbl = ChartParts.xLabel(r[label.name], label).trim();
      final v = (measureValue(r[value.name], value) ?? 0.0).abs();
      final boundary = lookupGeoBoundary(lbl);
      final lat = latName != null ? asDouble(r[latName]) : null;
      final lon = lonName != null ? asDouble(r[lonName]) : null;

      if (isRegionVisual(visual)) {
        if (boundary == null) continue;
        out.add(
          GeoPointDatum(
            label: lbl,
            isoCode: boundary.isoCode,
            lat: boundary.centroidLat,
            lon: boundary.centroidLon,
            value: v,
            boundary: boundary,
          ),
        );
      } else {
        if (lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat < -90 ||
            lat > 90 ||
            lon < -180 ||
            lon > 180) {
          continue;
        }
        out.add(
          GeoPointDatum(
            label: lbl,
            isoCode: boundary?.isoCode,
            lat: lat,
            lon: lon,
            value: v,
            boundary: boundary,
          ),
        );
      }
    }
    return out;
  }

  /// Normalizes `(lon, lat)` points onto `0..1` fractions within the point envelope.
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

  /// Computes a `grid x grid` spatial density matrix over projected point bounds.
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

  static _GeoViewport _computeViewport(
    List<GeoPointDatum> pts, {
    bool includeWorldFallback = true,
  }) {
    final parents = {
      for (final p in pts)
        if (p.boundary?.parentCountry != null) p.boundary!.parentCountry!,
    };
    final focusCountry = parents.length == 1 ? parents.first : null;
    if (includeWorldFallback && focusCountry == null) {
      // Check if points span more than one continent/region -> use world Natural Earth frame
      var minLat = 90.0;
      var maxLat = -90.0;
      var minLon = 180.0;
      var maxLon = -180.0;
      for (final p in pts) {
        if (p.boundary != null) {
          for (final ring in p.boundary!.rings) {
            for (final pt in ring) {
              minLon = math.min(minLon, pt.dx);
              maxLon = math.max(maxLon, pt.dx);
              minLat = math.min(minLat, pt.dy);
              maxLat = math.max(maxLat, pt.dy);
            }
          }
        } else {
          minLon = math.min(minLon, p.lon);
          maxLon = math.max(maxLon, p.lon);
          minLat = math.min(minLat, p.lat);
          maxLat = math.max(maxLat, p.lat);
        }
      }
      if ((maxLon - minLon) > 65 || (maxLat - minLat) > 45) {
        return const _GeoViewport(
          minLon: -180,
          maxLon: 180,
          minLat: -58,
          maxLat: 82,
        );
      }
      final padLon = math.max(4.0, (maxLon - minLon) * 0.18);
      final padLat = math.max(4.0, (maxLat - minLat) * 0.18);
      return _GeoViewport(
        minLon: math.max(-180, minLon - padLon),
        maxLon: math.min(180, maxLon + padLon),
        minLat: math.max(-58, minLat - padLat),
        maxLat: math.min(82, maxLat + padLat),
      );
    }

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLon = 180.0;
    var maxLon = -180.0;
    if (focusCountry != null) {
      for (final r in naturalEarthAdmin1) {
        if (r.parentCountry != focusCountry) continue;
        for (final ring in r.rings) {
          for (final pt in ring) {
            minLon = math.min(minLon, pt.dx);
            maxLon = math.max(maxLon, pt.dx);
            minLat = math.min(minLat, pt.dy);
            maxLat = math.max(maxLat, pt.dy);
          }
        }
      }
    } else {
      for (final p in pts) {
        minLon = math.min(minLon, p.lon);
        maxLon = math.max(maxLon, p.lon);
        minLat = math.min(minLat, p.lat);
        maxLat = math.max(maxLat, p.lat);
      }
    }
    final padLon = math.max(1.2, (maxLon - minLon) * 0.08);
    final padLat = math.max(1.2, (maxLat - minLat) * 0.08);
    return _GeoViewport(
      minLon: minLon - padLon,
      maxLon: maxLon + padLon,
      minLat: minLat - padLat,
      maxLat: maxLat + padLat,
      focusCountry: focusCountry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final error = validateGeoData(page, visual, label);
    if (error != null) {
      return Semantics(
        label: error,
        child: Container(
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.negative.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.negative,
              fontSize: 12,
              fontFamily: ReportPalette.font,
              fontFamilyFallback: ReportPalette.fontFallback,
            ),
          ),
        ),
      );
    }

    final pts = extractPoints(page, visual, label, value);
    final summary =
        '${visual.name}: ${pts.take(4).map((e) => e.label).join(', ')} (${pts.length}) — $naturalEarthAttribution';
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _GeoPainter(
              visual: visual,
              pts: pts,
              viewport: _computeViewport(pts),
              palette: p,
            ),
          ),
        ),
      ),
    );
  }
}

class _GeoPainter extends CustomPainter {
  final Visual visual;
  final List<GeoPointDatum> pts;
  final _GeoViewport viewport;
  final ReportPalette palette;

  const _GeoPainter({
    required this.visual,
    required this.pts,
    required this.viewport,
    required this.palette,
  });

  double get _maxV => pts.map((p) => p.value).fold<double>(1.0, math.max);

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 86,
    double fontSize = 8.5,
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

  void _paintBaseMap(Canvas canvas, Rect plot) {
    final landFill = Paint()
      ..color = palette.surfaceAlt.withValues(alpha: 0.72);
    final borderStroke = Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    final boundaries = viewport.focusCountry != null
        ? naturalEarthAdmin1.where(
            (b) => b.parentCountry == viewport.focusCountry,
          )
        : naturalEarthAdmin0;

    for (final b in boundaries) {
      for (final ring in b.rings) {
        final path = Path();
        for (var i = 0; i < ring.length; i++) {
          final px = viewport.project(ring[i].dx, ring[i].dy, plot);
          if (i == 0) {
            path.moveTo(px.dx, px.dy);
          } else {
            path.lineTo(px.dx, px.dy);
          }
        }
        path.close();
        canvas.drawPath(path, landFill);
        canvas.drawPath(path, borderStroke);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || pts.isEmpty) return;
    final plot = Rect.fromLTWH(16, 12, size.width - 32, size.height - 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(6)),
      Paint()..color = palette.surface,
    );

    canvas.save();
    canvas.clipRect(plot);
    _paintBaseMap(canvas, plot);
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
    canvas.restore();

    _drawText(
      canvas,
      naturalEarthAttribution,
      Offset(plot.left, plot.bottom + 3),
      maxWidth: plot.width,
      fontSize: 8.0,
      color: palette.textMuted,
    );
  }

  void _paintBubbleMap(Canvas canvas, Rect plot) {
    final maxV = _maxV;
    for (var i = 0; i < pts.length; i++) {
      final pos = viewport.project(pts[i].lon, pts[i].lat, plot);
      final r = 5.0 + 13.0 * math.sqrt((pts[i].value / maxV).clamp(0.0, 1.0));
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
    final maxV = _maxV;
    for (var i = 0; i < pts.length; i++) {
      final datum = pts[i];
      final b = datum.boundary;
      if (b == null) continue;
      final t = (datum.value / maxV).clamp(0.0, 1.0);
      final fill = Color.lerp(
        palette.surfaceAlt,
        palette.accent,
        0.28 + 0.72 * t,
      )!;
      final border = Paint()
        ..color = palette.textPrimary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (final ring in b.rings) {
        final path = Path();
        for (var j = 0; j < ring.length; j++) {
          final px = viewport.project(ring[j].dx, ring[j].dy, plot);
          if (j == 0) {
            path.moveTo(px.dx, px.dy);
          } else {
            path.lineTo(px.dx, px.dy);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.88));
        canvas.drawPath(path, border);
      }
      final center = viewport.project(b.centroidLon, b.centroidLat, plot);
      _drawText(
        canvas,
        datum.label,
        center,
        maxWidth: 64,
        fontSize: 8,
        color: t > 0.55 ? palette.onAccent : palette.textPrimary,
        center: true,
      );
    }
  }

  void _paintGeoHeatmap(Canvas canvas, Rect plot) {
    const grid = 12;
    final cw = plot.width / grid;
    final ch = plot.height / grid;
    final mat = List.generate(grid, (_) => List<double>.filled(grid, 0.0));
    for (final p in pts) {
      final px = viewport.project(p.lon, p.lat, plot);
      final gx = ((px.dx - plot.left) / cw).floor().clamp(0, grid - 1);
      final gy = ((px.dy - plot.top) / ch).floor().clamp(0, grid - 1);
      mat[gy][gx] += p.value;
    }
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
        final rect = Rect.fromLTWH(
          plot.left + gx * cw,
          plot.top + gy * ch,
          cw - 1,
          ch - 1,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.lerp(
              palette.warning,
              palette.negative,
              t,
            )!.withValues(alpha: 0.72),
        );
      }
    }
  }

  void _paintFlowMap(Canvas canvas, Rect plot) {
    final maxV = _maxV;
    final pos = [for (final p in pts) viewport.project(p.lon, p.lat, plot)];
    for (var i = 0; i + 1 < pos.length; i++) {
      final p1 = pos[i];
      final p2 = pos[i + 1];
      final ctrl = Offset((p1.dx + p2.dx) / 2, math.min(p1.dy, p2.dy) - 22);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.accent.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (pts[i].value / maxV) * 3.0,
      );
    }
    for (var i = 0; i < pos.length; i++) {
      canvas.drawCircle(pos[i], 4.2, Paint()..color = palette.seriesAt(i));
      _drawText(
        canvas,
        pts[i].label,
        pos[i] + const Offset(0, 9),
        center: true,
      );
    }
  }

  void _paintHexTileMap(Canvas canvas, Rect plot) {
    final maxV = _maxV;
    final r =
        (math.min(plot.width, plot.height) / (math.max(6, pts.length) * 1.4))
            .clamp(11.0, 20.0);
    for (var i = 0; i < pts.length; i++) {
      final pos = viewport.project(pts[i].lon, pts[i].lat, plot);
      final cx = pos.dx.clamp(plot.left + r, plot.right - r);
      final cy = pos.dy.clamp(plot.top + r, plot.bottom - r);
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 6 + k * math.pi / 3;
        final pt = Offset(
          cx + r * 0.92 * math.cos(a),
          cy + r * 0.92 * math.sin(a),
        );
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
        Paint()
          ..color = Color.lerp(
            palette.surfaceAlt,
            palette.accent,
            0.25 + 0.75 * t,
          )!.withValues(alpha: 0.88),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      _drawText(
        canvas,
        pts[i].label,
        Offset(cx, cy),
        maxWidth: r * 1.6,
        fontSize: 7.5,
        color: t > 0.55 ? palette.onAccent : palette.textPrimary,
        center: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GeoPainter old) =>
      old.visual != visual || old.pts != pts || old.palette != palette;
}
