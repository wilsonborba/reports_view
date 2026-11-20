import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'format.dart';

/// Directed edge extracted from [DatasetPage] rows for diagram rendering.
class DiagramEdge {
  final String source;
  final String target;
  final String group;
  final double value;

  const DiagramEdge({
    required this.source,
    required this.target,
    required this.group,
    required this.value,
  });
}

/// Renders flow, process, and structure diagrams (catalog items 75 to 89)
/// from real [DatasetPage] rows using [ReportPalette] tokens and [Semantics]
/// summaries (D1 to D10).
class DiagramCatalogChart extends StatelessWidget {
  final DatasetPage page;
  final Visual visual;
  final List<FieldInfo> dims;
  final FieldInfo measure;
  final double height;

  /// Maximum nodes shown before folding/clamping to keep diagrams legible (D7).
  static const int maxNodes = 12;

  const DiagramCatalogChart({
    super.key,
    required this.page,
    required this.visual,
    required this.dims,
    required this.measure,
    this.height = 260,
  });

  /// Extracts directed edges from [rows] using [dims] and [measure].
  /// Supports both 2+ dimension edge lists `(source, target, [group])` and
  /// 1-dimension sequential chains `(row[i] -> row[i+1])`.
  static List<DiagramEdge> extractEdges(
    List<Map<String, dynamic>> rows,
    List<FieldInfo> dims,
    FieldInfo measure,
  ) {
    if (rows.isEmpty || dims.isEmpty) return const [];
    final edges = <DiagramEdge>[];
    if (dims.length >= 2) {
      for (final r in rows) {
        final s = ChartParts.xLabel(r[dims[0].name], dims[0]);
        final t = ChartParts.xLabel(r[dims[1].name], dims[1]);
        final g = dims.length >= 3
            ? ChartParts.xLabel(r[dims[2].name], dims[2])
            : s;
        final v = (measureValue(r[measure.name], measure) ?? 1.0).abs();
        edges.add(DiagramEdge(source: s, target: t, group: g, value: v));
      }
      return edges;
    }
    for (var i = 0; i < rows.length; i++) {
      final s = ChartParts.xLabel(rows[i][dims[0].name], dims[0]);
      final nextIdx = (i + 1) < rows.length ? i + 1 : 0;
      final t = rows.length == 1
          ? '$s*'
          : ChartParts.xLabel(rows[nextIdx][dims[0].name], dims[0]);
      final v = (measureValue(rows[i][measure.name], measure) ?? 1.0).abs();
      edges.add(DiagramEdge(source: s, target: t, group: s, value: v));
    }
    return edges;
  }

  /// Collects unique node labels in insertion order, capped at [limit].
  static List<String> collectNodes(
    List<DiagramEdge> edges, {
    int limit = maxNodes,
  }) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in edges) {
      if (seen.add(e.source)) {
        out.add(e.source);
        if (out.length >= limit) return out;
      }
      if (seen.add(e.target)) {
        out.add(e.target);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// Computes an `N x N` adjacency matrix of edge weights for [nodes].
  static List<List<double>> computeAdjacencyMatrix(
    List<String> nodes,
    List<DiagramEdge> edges,
  ) {
    final idx = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    final n = nodes.length;
    final m = List.generate(n, (_) => List<double>.filled(n, 0.0));
    for (final e in edges) {
      final si = idx[e.source];
      final ti = idx[e.target];
      if (si != null && ti != null) {
        m[si][ti] += e.value;
      }
    }
    return m;
  }

  /// Assigns topological layer indices (`0..maxLayer`) for a DAG / layered diagram.
  static Map<String, int> computeLayeredOrder(
    List<String> nodes,
    List<DiagramEdge> edges,
  ) {
    final layer = {for (final n in nodes) n: 0};
    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (final e in edges) {
        final ls = layer[e.source];
        final lt = layer[e.target];
        if (ls != null && lt != null && lt <= ls && ls + 1 < nodes.length) {
          layer[e.target] = ls + 1;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return layer;
  }

  /// Computes normalized `(0..1, 0..1)` positions for nodes using deterministic
  /// force-directed iterations seeded by node totals.
  static Map<String, Offset> computeNetworkPositions(
    List<String> nodes,
    List<DiagramEdge> edges,
  ) {
    final n = nodes.length;
    if (n == 0) return const {};
    if (n == 1) return {nodes.first: const Offset(0.5, 0.5)};
    final pos = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          0.5 + 0.35 * math.cos(2 * math.pi * i / n),
          0.5 + 0.35 * math.sin(2 * math.pi * i / n),
        ),
    ];
    final idx = {for (var i = 0; i < n; i++) nodes[i]: i};
    for (var iter = 0; iter < 18; iter++) {
      final disp = List<Offset>.filled(n, Offset.zero);
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          final delta = pos[i] - pos[j];
          final dist = math.max(0.05, delta.distance);
          final force = 0.012 / (dist * dist);
          final push = Offset(delta.dx / dist * force, delta.dy / dist * force);
          disp[i] = disp[i] + push;
          disp[j] = disp[j] - push;
        }
      }
      for (final e in edges) {
        final si = idx[e.source];
        final ti = idx[e.target];
        if (si == null || ti == null || si == ti) continue;
        final delta = pos[ti] - pos[si];
        final dist = math.max(0.05, delta.distance);
        final pull = dist * 0.14;
        final step = Offset(delta.dx / dist * pull, delta.dy / dist * pull);
        disp[si] = disp[si] + step;
        disp[ti] = disp[ti] - step;
      }
      for (var i = 0; i < n; i++) {
        final d = disp[i];
        final mag = d.distance;
        final clamped = mag > 0.06
            ? Offset(d.dx / mag * 0.06, d.dy / mag * 0.06)
            : d;
        pos[i] = Offset(
          (pos[i].dx + clamped.dx).clamp(0.12, 0.88),
          (pos[i].dy + clamped.dy).clamp(0.14, 0.86),
        );
      }
    }
    return {for (var i = 0; i < n; i++) nodes[i]: pos[i]};
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (page.rows.isEmpty || dims.isEmpty) return const SizedBox.shrink();
    final edges = extractEdges(page.rows, dims, measure);
    final nodes = collectNodes(edges);
    final summary =
        '${visual.name}: ${nodes.take(4).join(', ')} (${edges.length})';
    return Semantics(
      label: summary,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _DiagramPainter(
              visual: visual,
              edges: edges,
              nodes: nodes,
              fields: page.descriptor.fields,
              palette: p,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  final Visual visual;
  final List<DiagramEdge> edges;
  final List<String> nodes;
  final List<FieldInfo> fields;
  final ReportPalette palette;

  const _DiagramPainter({
    required this.visual,
    required this.edges,
    required this.nodes,
    required this.fields,
    required this.palette,
  });

  double get _maxVal {
    var m = 1.0;
    for (final e in edges) {
      if (e.value > m) m = e.value;
    }
    return m;
  }

  Map<String, double> get _nodeWeights {
    final w = <String, double>{};
    for (final e in edges) {
      w[e.source] = (w[e.source] ?? 0) + e.value;
      w[e.target] = (w[e.target] ?? 0) + e.value;
    }
    return w;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    double maxWidth = 84,
    double fontSize = 10,
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
    final offset = center ? pos - Offset(tp.width / 2, tp.height / 2) : pos;
    tp.paint(canvas, offset);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color, {double width = 1.4}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const headLen = 6.0;
    final p1 = to - Offset(headLen * math.cos(angle - 0.45), headLen * math.sin(angle - 0.45));
    final p2 = to - Offset(headLen * math.cos(angle + 0.45), headLen * math.sin(angle + 0.45));
    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawBox(
    Canvas canvas,
    Rect rect,
    Color accent,
    String title, {
    bool pill = false,
    double weightRatio = 0.0,
  }) {
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(pill ? rect.height / 2 : 6),
    );
    canvas.drawRRect(rrect, Paint()..color = palette.surface);
    if (weightRatio > 0) {
      final fillW = (rect.width - 6) * weightRatio.clamp(0.02, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 3, rect.bottom - 5, fillW, 3),
        Paint()..color = accent.withValues(alpha: 0.75),
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawText(
      canvas,
      title,
      rect.center,
      maxWidth: math.max(20, rect.width - 10),
      center: true,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16 || nodes.isEmpty) return;
    switch (visual) {
      case Visual.alluvial:
        _paintAlluvial(canvas, size);
      case Visual.chord:
        _paintChord(canvas, size);
      case Visual.arcDiagram:
        _paintArc(canvas, size);
      case Visual.flowchart:
        _paintFlowchart(canvas, size);
      case Visual.layeredDag:
        _paintLayeredDag(canvas, size);
      case Visual.sequenceDiagram:
        _paintSequence(canvas, size);
      case Visual.stateDiagram:
        _paintState(canvas, size);
      case Visual.swimlane:
        _paintSwimlane(canvas, size);
      case Visual.treeOrg:
        _paintTreeOrg(canvas, size);
      case Visual.dendrogram:
        _paintDendrogram(canvas, size);
      case Visual.mindMap:
        _paintMindMap(canvas, size);
      case Visual.network:
        _paintNetwork(canvas, size);
      case Visual.adjacencyMatrix:
        _paintAdjacencyMatrix(canvas, size);
      case Visual.erDiagram:
        _paintErDiagram(canvas, size);
      case Visual.architectureDiagram:
      default:
        _paintArchitecture(canvas, size);
    }
  }

  void _paintAlluvial(Canvas canvas, Size size) {
    final sources = <String>{for (final e in edges) e.source}.take(6).toList();
    final targets = <String>{for (final e in edges) e.target}.take(6).toList();
    if (sources.isEmpty || targets.isEmpty) return;
    final leftX = 72.0;
    final rightX = size.width - 84.0;
    final sStep = (size.height - 28) / sources.length;
    final tStep = (size.height - 28) / targets.length;
    final maxV = _maxVal;

    for (final e in edges) {
      final si = sources.indexOf(e.source);
      final ti = targets.indexOf(e.target);
      if (si < 0 || ti < 0) continue;
      final sy = 14 + (si + 0.5) * sStep;
      final ty = 14 + (ti + 0.5) * tStep;
      final thick = 2.0 + (e.value / maxV) * 10.0;
      final mx = (leftX + rightX) / 2;
      final path = Path()
        ..moveTo(leftX + 12, sy - thick / 2)
        ..cubicTo(mx, sy - thick / 2, mx, ty - thick / 2, rightX, ty - thick / 2)
        ..lineTo(rightX, ty + thick / 2)
        ..cubicTo(mx, ty + thick / 2, mx, sy + thick / 2, leftX + 12, sy + thick / 2)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = palette.seriesAt(si).withValues(alpha: 0.42),
      );
    }
    for (var i = 0; i < sources.length; i++) {
      final y = 14 + i * sStep;
      canvas.drawRect(
        Rect.fromLTWH(leftX, y + 3, 12, math.max(8, sStep - 6)),
        Paint()..color = palette.seriesAt(i),
      );
      _drawText(canvas, sources[i], Offset(6, y + sStep / 2 - 6), maxWidth: 62);
    }
    for (var i = 0; i < targets.length; i++) {
      final y = 14 + i * tStep;
      canvas.drawRect(
        Rect.fromLTWH(rightX, y + 3, 12, math.max(8, tStep - 6)),
        Paint()..color = palette.textMuted,
      );
      _drawText(canvas, targets[i], Offset(rightX + 16, y + tStep / 2 - 6), maxWidth: 66);
    }
  }

  void _paintChord(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) * 0.34;
    final n = math.min(nodes.length, 10);
    final idx = {for (var i = 0; i < n; i++) nodes[i]: i};
    final pos = [
      for (var i = 0; i < n; i++)
        Offset(
          cx + r * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
          cy + r * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
        ),
    ];
    final maxV = _maxVal;
    for (final e in edges) {
      final si = idx[e.source];
      final ti = idx[e.target];
      if (si == null || ti == null) continue;
      final path = Path()
        ..moveTo(pos[si].dx, pos[si].dy)
        ..quadraticBezierTo(cx, cy, pos[ti].dx, pos[ti].dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = palette.seriesAt(si).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (e.value / maxV) * 5.0,
      );
    }
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      canvas.drawCircle(pos[i], 6, Paint()..color = palette.seriesAt(i));
      final lp = Offset(cx + (r + 18) * math.cos(a), cy + (r + 14) * math.sin(a));
      _drawText(canvas, nodes[i], lp, maxWidth: 64, fontSize: 9, center: true);
    }
  }

  void _paintArc(Canvas canvas, Size size) {
    final n = math.min(nodes.length, 10);
    final baseY = size.height - 34;
    final step = (size.width - 48) / math.max(1, n - 1);
    final idx = {for (var i = 0; i < n; i++) nodes[i]: i};
    final xs = [for (var i = 0; i < n; i++) 24.0 + (n == 1 ? (size.width - 48) / 2 : i * step)];
    final maxV = _maxVal;

    for (final e in edges) {
      final si = idx[e.source];
      final ti = idx[e.target];
      if (si == null || ti == null || si == ti) continue;
      final x1 = math.min(xs[si], xs[ti]);
      final x2 = math.max(xs[si], xs[ti]);
      final h = math.min(baseY - 12, (x2 - x1) * 0.55);
      final rect = Rect.fromLTRB(x1, baseY - h, x2, baseY + h);
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = palette.seriesAt(si).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (e.value / maxV) * 3.5,
      );
    }
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(xs[i], baseY), 5, Paint()..color = palette.seriesAt(i));
      _drawText(canvas, nodes[i], Offset(xs[i], baseY + 14), maxWidth: 52, fontSize: 9, center: true);
    }
  }

  void _drawDiamond(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    Color accent,
    String title,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy)
      ..lineTo(center.dx, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = palette.surface);
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawText(canvas, title, center, maxWidth: w * 0.72, fontSize: 9, center: true);
  }

  void _paintFlowchart(Canvas canvas, Size size) {
    final layers = DiagramCatalogChart.computeLayeredOrder(nodes, edges);
    final maxL = layers.values.fold<int>(0, math.max);
    final byLayer = <int, List<String>>{};
    for (final n in nodes) {
      byLayer.putIfAbsent(layers[n] ?? 0, () => []).add(n);
    }
    final colCount = maxL + 1;
    final colW = (size.width - 28) / colCount;
    final outDeg = <String, int>{};
    for (final e in edges) {
      outDeg[e.source] = (outDeg[e.source] ?? 0) + 1;
    }
    final centers = <String, Offset>{};
    for (var l = 0; l < colCount; l++) {
      final list = byLayer[l] ?? const [];
      final rowH = (size.height - 24) / math.max(1, list.length);
      for (var r = 0; r < list.length; r++) {
        centers[list[r]] = Offset(14 + (l + 0.5) * colW, 12 + (r + 0.5) * rowH);
      }
    }
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    for (final e in edges) {
      final from = centers[e.source];
      final to = centers[e.target];
      if (from != null && to != null && from != to) {
        _drawArrow(
          canvas,
          from + const Offset(28, 0),
          to - const Offset(28, 0),
          palette.textMuted,
          width: 1.0 + (e.value / _maxVal) * 2.2,
        );
      }
    }
    var idx = 0;
    for (final entry in centers.entries) {
      final n = entry.key;
      final c = palette.seriesAt(idx++);
      final isDecision = (outDeg[n] ?? 0) >= 2;
      if (isDecision) {
        _drawDiamond(canvas, entry.value, math.min(72, colW - 8), 44, c, n);
      } else {
        final isTerminal = idx == 1 || (outDeg[n] ?? 0) == 0;
        _drawBox(
          canvas,
          Rect.fromCenter(center: entry.value, width: math.min(68, colW - 10), height: 30),
          c,
          n,
          pill: isTerminal,
          weightRatio: (weights[n] ?? 0) / maxW,
        );
      }
    }
  }

  void _paintLayeredDag(Canvas canvas, Size size) {
    final layers = DiagramCatalogChart.computeLayeredOrder(nodes, edges);
    final maxL = layers.values.fold<int>(0, math.max);
    final byLayer = <int, List<String>>{};
    for (final n in nodes) {
      byLayer.putIfAbsent(layers[n] ?? 0, () => []).add(n);
    }
    final colCount = maxL + 1;
    final colW = (size.width - 36) / colCount;
    final centers = <String, Offset>{};
    for (var l = 0; l < colCount; l++) {
      final list = byLayer[l] ?? const [];
      final rowH = (size.height - 24) / math.max(1, list.length);
      for (var r = 0; r < list.length; r++) {
        centers[list[r]] = Offset(18 + (l + 0.5) * colW, 12 + (r + 0.5) * rowH);
      }
    }
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    for (final e in edges) {
      final from = centers[e.source];
      final to = centers[e.target];
      if (from != null && to != null && from != to) {
        _drawArrow(
          canvas,
          from + const Offset(34, 0),
          to - const Offset(34, 0),
          palette.accent,
          width: 1.0 + (e.value / _maxVal) * 2.5,
        );
      }
    }
    var i = 0;
    for (final entry in centers.entries) {
      _drawBox(
        canvas,
        Rect.fromCenter(center: entry.value, width: 68, height: 28),
        palette.seriesAt(i++),
        entry.key,
        weightRatio: (weights[entry.key] ?? 0) / maxW,
      );
    }
  }

  void _paintSequence(Canvas canvas, Size size) {
    final actors = nodes.take(5).toList();
    final n = actors.length;
    final colW = (size.width - 32) / n;
    final xs = [for (var i = 0; i < n; i++) 16 + (i + 0.5) * colW];
    final idx = {for (var i = 0; i < n; i++) actors[i]: i};

    for (var i = 0; i < n; i++) {
      _drawBox(
        canvas,
        Rect.fromCenter(center: Offset(xs[i], 22), width: math.min(82, colW - 8), height: 26),
        palette.seriesAt(i),
        actors[i],
      );
      canvas.drawLine(
        Offset(xs[i], 35),
        Offset(xs[i], size.height - 12),
        Paint()
          ..color = palette.border
          ..strokeWidth = 1.2,
      );
    }

    final msgCount = math.min(edges.length, 6);
    final stepY = (size.height - 54) / math.max(1, msgCount);
    for (var i = 0; i < msgCount; i++) {
      final e = edges[i];
      final si = idx[e.source];
      final ti = idx[e.target];
      if (si == null || ti == null) continue;
      final y = 48 + (i + 0.5) * stepY;
      _drawArrow(
        canvas,
        Offset(xs[si], y),
        Offset(xs[ti], y),
        palette.seriesAt(si),
        width: 1.0 + (e.value / _maxVal) * 2.5,
      );
      _drawText(
        canvas,
        e.value.toStringAsFixed(0),
        Offset((xs[si] + xs[ti]) / 2, y - 10),
        maxWidth: 50,
        fontSize: 9,
        center: true,
      );
    }
  }

  void _paintState(Canvas canvas, Size size) {
    final n = math.min(nodes.length, 6);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.32;
    final ry = size.height * 0.30;
    final centers = [
      for (var i = 0; i < n; i++)
        Offset(
          cx + rx * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
          cy + ry * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
        ),
    ];
    final idx = {for (var i = 0; i < n; i++) nodes[i]: i};
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    for (final e in edges) {
      final si = idx[e.source];
      final ti = idx[e.target];
      if (si == null || ti == null || si == ti) continue;
      _drawArrow(
        canvas,
        centers[si],
        centers[ti],
        palette.textMuted,
        width: 1.0 + (e.value / _maxVal) * 2.5,
      );
    }
    for (var i = 0; i < n; i++) {
      _drawBox(
        canvas,
        Rect.fromCenter(center: centers[i], width: 72, height: 28),
        palette.seriesAt(i),
        nodes[i],
        pill: true,
        weightRatio: (weights[nodes[i]] ?? 0) / maxW,
      );
    }
  }

  void _paintSwimlane(Canvas canvas, Size size) {
    final lanes = <String>{for (final e in edges) e.group}.take(3).toList();
    if (lanes.isEmpty) return;
    final weights = _nodeWeights;
    final laneNodeSets = [
      for (final lane in lanes)
        {
          for (final e in edges)
            if (e.group == lane) e.source,
        }.take(4).toList(),
    ];
    var maxW = 1.0;
    for (final ln in laneNodeSets.expand((e) => e)) {
      final w = weights[ln] ?? 0;
      if (w > maxW) maxW = w;
    }
    final laneH = (size.height - 16) / lanes.length;
    for (var l = 0; l < lanes.length; l++) {
      final y = 8 + l * laneH;
      canvas.drawRect(
        Rect.fromLTWH(8, y, size.width - 16, laneH - 4),
        Paint()
          ..color = palette.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      _drawText(canvas, lanes[l], Offset(14, y + 6), maxWidth: 72, fontSize: 10);
      final laneNodes = laneNodeSets[l];
      for (var j = 0; j < laneNodes.length; j++) {
        final box = Rect.fromLTWH(96 + j * 84, y + laneH / 2 - 14, 72, 28);
        _drawBox(
          canvas,
          box,
          palette.seriesAt(l),
          laneNodes[j],
          weightRatio: (weights[laneNodes[j]] ?? 0) / maxW,
        );
      }
    }
    // Draw cross-lane hand-off arrows using computed node centers.
    final nodePos = <String, Offset>{};
    for (var l = 0; l < lanes.length; l++) {
      final y = 8 + l * laneH;
      final laneNodes = laneNodeSets[l];
      for (var j = 0; j < laneNodes.length; j++) {
        nodePos[laneNodes[j]] = Offset(96 + j * 84 + 36, y + laneH / 2);
      }
    }
    for (final e in edges) {
      final p1 = nodePos[e.source];
      final p2 = nodePos[e.target];
      if (p1 != null && p2 != null && p1 != p2) {
        _drawArrow(canvas, p1, p2, palette.accent.withValues(alpha: 0.7), width: 1.2);
      }
    }
  }

  void _paintTreeOrg(Canvas canvas, Size size) {
    final layers = DiagramCatalogChart.computeLayeredOrder(nodes, edges);
    final maxL = layers.values.fold<int>(0, math.max).clamp(0, 3);
    final byLevel = <int, List<String>>{};
    for (final n in nodes) {
      final lvl = (layers[n] ?? 0).clamp(0, 3);
      byLevel.putIfAbsent(lvl, () => []).add(n);
    }
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    final levelH = (size.height - 24) / (maxL + 1);
    final centers = <String, Offset>{};
    for (var l = 0; l <= maxL; l++) {
      final row = (byLevel[l] ?? const []).take(5).toList();
      final step = (size.width - 28) / math.max(1, row.length);
      final cy = 12 + (l + 0.5) * levelH;
      for (var i = 0; i < row.length; i++) {
        centers[row[i]] = Offset(14 + (i + 0.5) * step, cy);
      }
    }
    final linePaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1.4;
    for (final e in edges) {
      final p1 = centers[e.source];
      final p2 = centers[e.target];
      if (p1 != null && p2 != null && p2.dy > p1.dy) {
        final midY = (p1.dy + p2.dy) / 2;
        canvas.drawLine(Offset(p1.dx, p1.dy + 14), Offset(p1.dx, midY), linePaint);
        canvas.drawLine(Offset(p1.dx, midY), Offset(p2.dx, midY), linePaint);
        canvas.drawLine(Offset(p2.dx, midY), Offset(p2.dx, p2.dy - 14), linePaint);
      }
    }
    var idx = 0;
    for (final entry in centers.entries) {
      _drawBox(
        canvas,
        Rect.fromCenter(center: entry.value, width: 76, height: 28),
        palette.seriesAt(idx++),
        entry.key,
        weightRatio: (weights[entry.key] ?? 0) / maxW,
      );
    }
  }

  void _paintDendrogram(Canvas canvas, Size size) {
    final leaves = nodes.take(6).toList();
    final n = leaves.length;
    final rowH = (size.height - 24) / n;
    final labelX = size.width - 82;
    final ys = [for (var i = 0; i < n; i++) 12 + (i + 0.5) * rowH];
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    final linePaint = Paint()
      ..color = palette.accent
      ..strokeWidth = 1.5;
    for (var i = 0; i < n; i++) {
      final wRatio = (weights[leaves[i]] ?? 0) / maxW;
      final branchX = labelX - 24 - wRatio * 48;
      _drawText(canvas, leaves[i], Offset(labelX + 6, ys[i] - 6), maxWidth: 74);
      canvas.drawLine(Offset(branchX, ys[i]), Offset(labelX, ys[i]), linePaint);
    }
    for (var i = 0; i + 1 < n; i += 2) {
      final r1 = (weights[leaves[i]] ?? 0) / maxW;
      final r2 = (weights[leaves[i + 1]] ?? 0) / maxW;
      final mergeX = labelX - 24 - math.max(r1, r2) * 48;
      canvas.drawLine(Offset(mergeX, ys[i]), Offset(mergeX, ys[i + 1]), linePaint);
      final midY = (ys[i] + ys[i + 1]) / 2;
      canvas.drawLine(Offset(28, midY), Offset(mergeX, midY), linePaint);
    }
    if (n >= 3) {
      canvas.drawLine(Offset(28, (ys[0] + ys[1]) / 2), Offset(28, ys.last), linePaint);
    }
  }

  void _paintMindMap(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final root = nodes.first;
    final branches = nodes.skip(1).take(6).toList();
    final weights = _nodeWeights;
    final maxW = weights.values.fold<double>(1.0, math.max);
    for (var i = 0; i < branches.length; i++) {
      final right = i.isEven;
      final sideIdx = i ~/ 2;
      final sideCount = ((branches.length + (right ? 1 : 0)) / 2).ceil().clamp(1, 4);
      final y = 28 + (sideIdx + 0.5) * ((size.height - 56) / sideCount);
      final x = right ? size.width - 76 : 76.0;
      final target = Offset(x, y);
      final c = palette.seriesAt(i);
      final wRatio = (weights[branches[i]] ?? 0) / maxW;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + (right ? 60 : -60),
          center.dy,
          target.dx + (right ? -50 : 50),
          target.dy,
          target.dx,
          target.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + wRatio * 2.5,
      );
      _drawBox(
        canvas,
        Rect.fromCenter(center: target, width: 84, height: 26),
        c,
        branches[i],
        pill: true,
        weightRatio: wRatio,
      );
    }
    _drawBox(
      canvas,
      Rect.fromCenter(center: center, width: 96, height: 34),
      palette.accent,
      root,
      pill: true,
      weightRatio: (weights[root] ?? 0) / maxW,
    );
  }

  void _paintNetwork(Canvas canvas, Size size) {
    final pos = DiagramCatalogChart.computeNetworkPositions(nodes, edges);
    final maxV = _maxVal;
    for (final e in edges) {
      final p1 = pos[e.source];
      final p2 = pos[e.target];
      if (p1 == null || p2 == null) continue;
      canvas.drawLine(
        Offset(p1.dx * size.width, p1.dy * size.height),
        Offset(p2.dx * size.width, p2.dy * size.height),
        Paint()
          ..color = palette.border
          ..strokeWidth = 1.0 + (e.value / maxV) * 2.5,
      );
    }
    var i = 0;
    for (final entry in pos.entries) {
      final c = palette.seriesAt(i++);
      final pt = Offset(entry.value.dx * size.width, entry.value.dy * size.height);
      canvas.drawCircle(pt, 9, Paint()..color = c);
      _drawText(canvas, entry.key, pt + const Offset(0, 14), maxWidth: 62, fontSize: 9, center: true);
    }
  }

  void _paintAdjacencyMatrix(Canvas canvas, Size size) {
    final sub = nodes.take(6).toList();
    final m = DiagramCatalogChart.computeAdjacencyMatrix(sub, edges);
    final n = sub.length;
    final leftPad = 68.0;
    final topPad = 24.0;
    final gridSize = math.min(size.width - leftPad - 12, size.height - topPad - 12);
    final cell = gridSize / n;
    final maxV = _maxVal;

    for (var i = 0; i < n; i++) {
      _drawText(canvas, sub[i], Offset(4, topPad + i * cell + cell * 0.25), maxWidth: 60, fontSize: 9);
      _drawText(canvas, sub[i], Offset(leftPad + i * cell + cell * 0.5, 10), maxWidth: cell, fontSize: 9, center: true);
      for (var j = 0; j < n; j++) {
        final v = m[i][j];
        final t = (v / maxV).clamp(0.0, 1.0);
        final rect = Rect.fromLTWH(leftPad + j * cell + 1, topPad + i * cell + 1, cell - 2, cell - 2);
        canvas.drawRect(
          rect,
          Paint()
            ..color = v > 0
                ? Color.lerp(palette.surfaceAlt, palette.accent, 0.25 + 0.75 * t)!
                : palette.surface,
        );
      }
    }
  }

  void _paintErDiagram(Canvas canvas, Size size) {
    final entities = nodes.take(3).toList();
    final step = (size.width - 24) / entities.length;
    final attrs = fields.take(3).map((f) => f.label).toList();
    final weights = _nodeWeights;
    var maxW = 1.0;
    for (final ent in entities) {
      final w = weights[ent] ?? 0;
      if (w > maxW) maxW = w;
    }
    for (var i = 0; i < entities.length; i++) {
      final x = 12 + i * step + 6;
      final w = math.max(70.0, step - 18);
      final box = Rect.fromLTWH(x, 34, w, size.height - 68);
      canvas.drawRect(box, Paint()..color = palette.surface);
      canvas.drawRect(Rect.fromLTWH(x, 34, w, 24), Paint()..color = palette.seriesAt(i));
      final wRatio = ((weights[entities[i]] ?? 0) / maxW).clamp(0.02, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(x + 4, 62, (w - 8) * wRatio, 4),
        Paint()..color = palette.seriesAt(i),
      );
      canvas.drawRect(
        box,
        Paint()
          ..color = palette.seriesAt(i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      _drawText(
        canvas,
        '${entities[i]} (${(weights[entities[i]] ?? 0).toStringAsFixed(0)})',
        Offset(x + 6, 40),
        maxWidth: w - 12,
        color: palette.onAccent,
      );
      for (var a = 0; a < attrs.length; a++) {
        _drawText(canvas, '• ${attrs[a]}', Offset(x + 8, 68 + a * 20), maxWidth: w - 16, fontSize: 9);
      }
      if (i + 1 < entities.length) {
        final ew = i < edges.length ? 1.0 + (edges[i].value / _maxVal) * 2.5 : 1.4;
        _drawArrow(
          canvas,
          Offset(box.right, size.height / 2),
          Offset(12 + (i + 1) * step + 6, size.height / 2),
          palette.textMuted,
          width: ew,
        );
      }
    }
  }

  void _paintArchitecture(Canvas canvas, Size size) {
    final tiers = <String>{for (final e in edges) e.group}.take(3).toList();
    final tierCount = math.max(1, tiers.length);
    final tierH = (size.height - 20) / tierCount;
    final weights = _nodeWeights;
    final tierItems = [
      for (final t in tiers)
        {
          for (final e in edges)
            if (e.group == t) e.source,
        }.take(4).toList(),
    ];
    var maxW = 1.0;
    for (final it in tierItems.expand((e) => e)) {
      final w = weights[it] ?? 0;
      if (w > maxW) maxW = w;
    }
    for (var t = 0; t < tierCount; t++) {
      final y = 10 + t * tierH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(10, y, size.width - 20, tierH - 8), const Radius.circular(6)),
        Paint()
          ..color = palette.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final items = t < tierItems.length ? tierItems[t] : const <String>[];
      final boxW = math.min(92.0, (size.width - 40) / math.max(1, items.length) - 10);
      for (var j = 0; j < items.length; j++) {
        _drawBox(
          canvas,
          Rect.fromLTWH(22 + j * (boxW + 12), y + tierH / 2 - 18, boxW, 28),
          palette.seriesAt(t),
          items[j],
          weightRatio: (weights[items[j]] ?? 0) / maxW,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiagramPainter old) =>
      old.visual != visual || old.edges != edges || old.palette != palette;
}
