import 'package:flutter/material.dart';
import '../models/report.dart';
import '../models/template.dart';
import '../themes/report_palette.dart';
import 'bar_charts.dart';
import 'chart_frame.dart';
import 'comparison_charts.dart';
import 'data_table_view.dart';
import 'diagram_charts.dart';
import 'donut_chart.dart';
import 'format.dart';
import 'geo_charts.dart';
import 'indicator_table_charts.dart';
import 'kpi_tiles.dart';
import 'line_charts.dart';
import 'map_chart.dart';
import 'part_whole_charts.dart';
import 'distribution_charts.dart';
import 'relation_charts.dart';
import 'sankey_chart.dart';
import 'science_ai_charts.dart';
import 'sets_charts.dart';
import 'time_charts.dart';

/// Chooses the chart for a dataset from its field types and roles. The layout can
/// force a visual and the measures; the API never sends chart types.
class VisualChooser {
  static const _geo = {'latitude', 'longitude'};

  static List<FieldInfo> dimensions(DatasetDescriptor d) =>
      d.fields.where((f) => f.isDimension).toList();

  /// Explicit slot dimensions take precedence; an empty list preserves the
  /// descriptor-order behavior used by legacy, unbound callers.
  static List<FieldInfo> _slotDimensions(DatasetDescriptor d, Slot slot) {
    if (slot.dimensions.isEmpty) return dimensions(d);
    return [for (final name in slot.dimensions) ?d.field(name)];
  }

  static List<FieldInfo> measures(DatasetDescriptor d) => d.fields
      .where((f) => !f.isDimension && f.isNumeric && !_geo.contains(f.type))
      .toList();

  static bool hasGeo(DatasetDescriptor d) =>
      d.fields.any((f) => f.type == 'latitude') &&
      d.fields.any((f) => f.type == 'longitude');

  /// Automatic choice when the layout says [Visual.auto].
  /// Category stages of a Sankey: the slot list, or the category dimensions in field
  /// order (no dates, hours or coordinates), at most 4.
  static List<FieldInfo> sankeyStages(DatasetDescriptor d, Slot slot) {
    if (slot.dimensions.isNotEmpty) {
      return [
        for (final n in slot.dimensions)
          if (d.field(n) != null) d.field(n)!,
      ];
    }
    return dimensions(d).where((f) => f.type == 'string').take(4).toList();
  }

  static Visual auto(DatasetPage page) {
    final d = page.descriptor;
    final dims = dimensions(d);
    final ms = measures(d);
    if (page.rows.isEmpty) return Visual.table;
    if (dims.isEmpty && page.rows.length == 1) return Visual.kpi;
    if (ms.isEmpty) return Visual.table;
    if (hasGeo(d) && dims.isNotEmpty) return Visual.map;
    if (dims.length == 2 &&
        ms.length == 1 &&
        dims.first.isTime &&
        !dims.last.isTime) {
      return Visual.stackedBar;
    }
    if (dims.length == 1 && dims.first.isTime) {
      return page.rows.length > 1 ? Visual.line : Visual.kpi;
    }
    if (dims.length == 1 && dims.first.type == 'float') return Visual.curve;
    if (dims.length == 1 && dims.first.type == 'string') {
      if (ms.length > 3) return Visual.table;
      // A donut shows parts of a whole; rates and shares do not add up to one.
      final main = ms.firstWhere(
        (f) => f.type != 'percent',
        orElse: () => ms.first,
      );
      if (main.type == 'percent') return Visual.hbar;
      final hasLongLabel = page.rows.any(
        (r) => valueText(r[dims.first.name], dims.first).length > 14,
      );
      if (hasLongLabel) return Visual.hbar;
      return page.rows.length <= 6 ? Visual.donut : Visual.hbar;
    }
    return Visual.table;
  }

  /// Measures of a slot: the forced list, or the first measure plus the next ones
  /// with the same type and unit (so one axis can show them).
  static List<FieldInfo> slotMeasures(
    DatasetDescriptor d,
    Slot slot, {
    int max = 4,
  }) {
    if (slot.measures.isNotEmpty) {
      return [
        for (final n in slot.measures)
          if (d.field(n) != null) d.field(n)!,
      ];
    }
    final ms = measures(d);
    if (ms.isEmpty) return const [];
    final first = ms.firstWhere(
      (f) => f.type != 'percent',
      orElse: () => ms.first,
    );
    return ms
        .where((f) => f.type == first.type && f.unit == first.unit)
        .take(max)
        .toList();
  }

  static FieldInfo? _share(DatasetDescriptor d, FieldInfo value) {
    for (final f in measures(d)) {
      if (f.type == 'percent' && f != value) return f;
    }
    return null;
  }

  /// Bar measure and second value of a ranking or donut: the first measure in field
  /// order (the dataset is ranked by it), then a share, or else the next measure.
  static (FieldInfo, FieldInfo?) ranked(DatasetDescriptor d, Slot slot) {
    final all = measures(d);
    final forced = slotMeasures(d, slot);
    final main = slot.measures.isNotEmpty ? forced.first : all.first;
    final second = slot.measures.length > 1
        ? forced[1]
        : (_share(d, main) ?? all.where((f) => f != main).firstOrNull);
    return (main, second);
  }

  /// The chart widget for a loaded dataset. [companions] holds the extra datasets of the slot.
  /// [height] is the body height of a board card; null means the natural height.
  /// [frame] is the largest height of a full view chart (80% of the screen); long content
  /// scrolls inside it.
  static Widget build(
    DatasetPage page,
    Slot slot, {
    Map<String, DatasetPage> companions = const {},
    bool full = false,
    double? height,
    double? frame,
  }) {
    final visual = resolve(page, slot);
    final limit = full ? null : previewLimit(visual);
    // The table sorts all rows first and then shows the preview rows itself. The map
    // draws every point and limits only its list.
    final shown =
        limit != null &&
            page.rows.length > limit &&
            visual != Visual.table &&
            visual != Visual.map
        ? DatasetPage(
            descriptor: page.descriptor,
            rows: page.rows.take(limit).toList(),
            offset: page.offset,
            limit: limit,
            totalRows: page.totalRows,
          )
        : page;
    final chart = _build(
      shown,
      visual,
      slot,
      companions: companions,
      full: full,
      height: height == null ? null : (height - 48).clamp(80.0, 4000.0),
      frame: frame ?? 640,
    );
    if (height == null) return chart;
    // Inside a fixed card the content never overflows: what does not fit scrolls.
    return SizedBox(
      height: height,
      child: SingleChildScrollView(child: chart),
    );
  }

  /// Maps a template `visual` string to a [Visual] enum value.
  static Visual visualFromName(String name) => switch (name.trim()) {
    'kpi' => Visual.kpi,
    'line' => Visual.line,
    'stepLine' || 'step_line' => Visual.stepLine,
    'area' => Visual.area,
    'stackedArea' || 'stacked_area' => Visual.stackedArea,
    'stackedArea100' || 'stacked_area_100' => Visual.stackedArea100,
    'streamgraph' => Visual.streamgraph,
    'sparkline' => Visual.sparkline,
    'bumpChart' || 'bump_chart' => Visual.bumpChart,
    'candlestick' => Visual.candlestick,
    'rangeBand' || 'range_band' => Visual.rangeBand,
    'annotatedLine' || 'annotated_line' => Visual.annotatedLine,
    'timeline' => Visual.timeline,
    'gantt' => Visual.gantt,
    'calendarHeatmap' || 'calendar_heatmap' => Visual.calendarHeatmap,
    'horizon' => Visual.horizon,
    'controlChart' || 'control_chart' => Visual.controlChart,
    'burndown' => Visual.burndown,
    'cyclePlot' || 'cycle_plot' => Visual.cyclePlot,
    'bar' || 'vertical_bar' => Visual.bar,
    'hbar' || 'horizontal_bar' => Visual.hbar,
    'rankingBar' || 'ranking_bar' => Visual.rankingBar,
    'groupedBar' || 'grouped_bar' => Visual.groupedBar,
    'stackedBar' || 'stacked_bar' => Visual.stackedBar,
    'stackedBar100' || 'stacked_bar_100' => Visual.stackedBar100,
    'divergingBar' || 'diverging_bar' => Visual.divergingBar,
    'floatingBar' || 'floating_bar' => Visual.floatingBar,
    'lollipop' => Visual.lollipop,
    'dotPlot' || 'dot_plot' => Visual.dotPlot,
    'dumbbell' => Visual.dumbbell,
    'slope' => Visual.slope,
    'bullet' => Visual.bullet,
    'utilizationBar' || 'utilization_bar' => Visual.utilizationBar,
    'pictogram' => Visual.pictogram,
    'radialBar' || 'radial_bar' => Visual.radialBar,
    'circularBar' || 'circular_bar' => Visual.circularBar,
    'radar' => Visual.radar,
    'parallelCoordinates' ||
    'parallel_coordinates' => Visual.parallelCoordinates,
    'marimekko' => Visual.marimekko,
    'waterfall' => Visual.waterfall,
    'pareto' => Visual.pareto,
    'smallMultiples' || 'small_multiples' => Visual.smallMultiples,
    'donut' => Visual.donut,
    'pie' => Visual.pie,
    'gauge' => Visual.gauge,
    'meter' => Visual.meter,
    'treemap' => Visual.treemap,
    'sunburst' => Visual.sunburst,
    'icicle' => Visual.icicle,
    'circlePacking' || 'circle_packing' => Visual.circlePacking,
    'waffle' => Visual.waffle,
    'nightingaleRose' || 'nightingale_rose' => Visual.nightingaleRose,
    'funnel' => Visual.funnel,
    'histogram' => Visual.histogram,
    'boxPlot' || 'box_plot' => Visual.boxPlot,
    'violin' => Visual.violin,
    'density' => Visual.density,
    'ridgeline' => Visual.ridgeline,
    'strip' => Visual.strip,
    'ecdf' => Visual.ecdf,
    'qqPlot' || 'qq_plot' => Visual.qqPlot,
    'populationPyramid' || 'population_pyramid' => Visual.populationPyramid,
    'raincloud' => Visual.raincloud,
    'scatter' => Visual.scatter,
    'bubble' => Visual.bubble,
    'heatmap' => Visual.heatmap,
    'correlationMatrix' || 'correlation_matrix' => Visual.correlationMatrix,
    'hexbin' => Visual.hexbin,
    'contour2d' || 'contour_2d' => Visual.contour2d,
    'splom' => Visual.splom,
    'quadrant' => Visual.quadrant,
    'ternary' => Visual.ternary,
    'combo' => Visual.combo,
    'curve' => Visual.curve,
    'map' => Visual.map,
    'table' => Visual.table,
    'sankey' => Visual.sankey,
    'alluvial' => Visual.alluvial,
    'chord' => Visual.chord,
    'arcDiagram' || 'arc_diagram' => Visual.arcDiagram,
    'flowchart' => Visual.flowchart,
    'layeredDag' || 'layered_dag' => Visual.layeredDag,
    'sequenceDiagram' || 'sequence_diagram' => Visual.sequenceDiagram,
    'stateDiagram' || 'state_diagram' => Visual.stateDiagram,
    'swimlane' => Visual.swimlane,
    'treeOrg' || 'tree_org' => Visual.treeOrg,
    'dendrogram' => Visual.dendrogram,
    'mindMap' || 'mind_map' => Visual.mindMap,
    'network' => Visual.network,
    'adjacencyMatrix' || 'adjacency_matrix' => Visual.adjacencyMatrix,
    'erDiagram' || 'er_diagram' => Visual.erDiagram,
    'architectureDiagram' ||
    'architecture_diagram' => Visual.architectureDiagram,
    'venn' => Visual.venn,
    'euler' => Visual.euler,
    'upset' => Visual.upset,
    'bubbleMap' || 'bubble_map' => Visual.bubbleMap,
    'choropleth' => Visual.choropleth,
    'geoHeatmap' || 'geo_heatmap' => Visual.geoHeatmap,
    'flowMap' || 'flow_map' => Visual.flowMap,
    'hexTileMap' || 'hex_tile_map' => Visual.hexTileMap,
    'kpiSparkline' || 'kpi_sparkline' => Visual.kpiSparkline,
    'heatTable' || 'heat_table' => Visual.heatTable,
    'statusScorecard' || 'status_scorecard' => Visual.statusScorecard,
    'wordCloud' || 'word_cloud' => Visual.wordCloud,
    'topKProb' || 'top_k_prob' => Visual.topKProb,
    'calibration' => Visual.calibration,
    'confusionMatrix' || 'confusion_matrix' => Visual.confusionMatrix,
    'rocPr' || 'roc_pr' => Visual.rocPr,
    'learningCurve' || 'learning_curve' => Visual.learningCurve,
    'irtIcc' || 'irt_icc' => Visual.irtIcc,
    'irtIif' || 'irt_iif' => Visual.irtIif,
    'wrightMap' || 'wright_map' => Visual.wrightMap,
    'itemDiffDisc' || 'item_diff_disc' => Visual.itemDiffDisc,
    'kaplanMeier' || 'kaplan_meier' => Visual.kaplanMeier,
    _ => Visual.auto,
  };

  /// Validates [binding] against [template] slots and [page] fields before drawing.
  /// Shows [ChartFrameState.error] with the validation error when validation fails.
  static Widget buildTemplate({
    required DatasetPage page,
    required VisualTemplate template,
    required CardVisualBinding binding,
    ChartFrameMode mode = ChartFrameMode.card,
    String? title,
    String? subtitle,
    String? snapshotDate,
    bool showAxisTitles = true,
    ChartFrameState? frameState,
    bool full = false,
    double? height,
    double? frame,
    VoidCallback? onSeeAll,
    VoidCallback? onRetry,
  }) {
    final validation = TemplateValidator.validate(
      template,
      binding,
      page.descriptor,
    );
    if (!validation.isValid) {
      return ChartFrame(
        page: page,
        mode: mode,
        state: ChartFrameState.error,
        errorMessage: validation.error,
        title: title,
        subtitle: subtitle,
        snapshotDate: snapshotDate,
        showAxisTitles: showAxisTitles,
        onRetry: onRetry,
        fixedHeight: height,
        child: const SizedBox.shrink(),
      );
    }

    final mappedDimensions = <String>[];
    final mappedMeasures = <String>[];
    for (final slotDef in template.slots) {
      final fields = binding.mapping[slotDef.slotName] ?? const <String>[];
      if (slotDef.role == 'measure' || slotDef.role == 'value') {
        mappedMeasures.addAll(fields);
      } else {
        mappedDimensions.addAll(fields);
      }
    }

    final slot = Slot(
      page.descriptor.datasetId,
      visual: visualFromName(template.visual),
      dimensions: mappedDimensions,
      measures: mappedMeasures,
    );
    if (page.rows.isNotEmpty &&
        (slot.visual == Visual.map ||
            slot.visual == Visual.bubbleMap ||
            slot.visual == Visual.choropleth ||
            slot.visual == Visual.geoHeatmap ||
            slot.visual == Visual.flowMap ||
            slot.visual == Visual.hexTileMap)) {
      final dimField = mappedDimensions.isNotEmpty
          ? page.descriptor.field(mappedDimensions.first)
          : dimensions(page.descriptor).firstOrNull;
      final geoError = GeoCatalogChart.validateGeoData(
        page,
        slot.visual,
        dimField,
      );
      if (geoError != null) {
        return ChartFrame(
          page: page,
          mode: mode,
          state: ChartFrameState.error,
          errorMessage: geoError,
          title: title,
          subtitle: subtitle,
          snapshotDate: snapshotDate,
          showAxisTitles: showAxisTitles,
          onRetry: onRetry,
          fixedHeight: height,
          child: const SizedBox.shrink(),
        );
      }
    }
    final state =
        frameState ??
        (page.rows.isEmpty ? ChartFrameState.empty : ChartFrameState.ready);
    return ChartFrame(
      page: page,
      mode: mode,
      state: state,
      title: title,
      subtitle: subtitle,
      snapshotDate: snapshotDate,
      showAxisTitles: showAxisTitles,
      onSeeAll: onSeeAll,
      onRetry: onRetry,
      fixedHeight: height,
      child: state == ChartFrameState.ready || state == ChartFrameState.offline
          ? build(page, slot, full: full, frame: frame)
          : const SizedBox.shrink(),
    );
  }

  /// Smallest width of one x position in a full view line or bar chart.
  static const double fullPointWidth = 8;

  /// Rows of one table page in a full view.
  static const int fullPageSize = 50;

  /// Rows a card shows for a visual; null shows every row. More rows give a See all button.
  static int? previewLimit(Visual v) => switch (v) {
    Visual.hbar => 10,
    Visual.table => 8,
    Visual.map => 8,
    _ => null,
  };

  /// True when the card shows only a part of the rows of the dataset.
  static bool needsFullView(DatasetPage page, Slot slot) {
    final limit = previewLimit(resolve(page, slot));
    final total = page.totalRows > page.rows.length
        ? page.totalRows
        : page.rows.length;
    return limit != null && total > limit;
  }

  /// The visual for a slot: the forced one when the dataset fits it, else the table.
  static Visual resolve(DatasetPage page, Slot slot) {
    final d = page.descriptor;
    final visual = slot.visual == Visual.auto ? auto(page) : slot.visual;
    final dims = _slotDimensions(d, slot);
    final ms = slotMeasures(d, slot);
    final fits = switch (visual) {
      Visual.kpi || Visual.table || Visual.auto => true,
      Visual.map => hasGeo(d) && dims.isNotEmpty && ms.isNotEmpty,
      Visual.bubbleMap ||
      Visual.geoHeatmap ||
      Visual.flowMap ||
      Visual.choropleth ||
      Visual.hexTileMap =>
        ms.isNotEmpty &&
            GeoCatalogChart.validateGeoData(page, visual, dims.firstOrNull) ==
                null,
      Visual.stackedBar => dims.length >= 2 && ms.isNotEmpty,
      Visual.curve => d.fields.isNotEmpty && ms.isNotEmpty,
      Visual.combo => dims.isNotEmpty && ms.length >= 2,
      Visual.sankey => sankeyStages(d, slot).length >= 2 && ms.isNotEmpty,
      _ => dims.isNotEmpty && ms.isNotEmpty,
    };
    return fits ? visual : Visual.table;
  }

  static Widget _build(
    DatasetPage page,
    Visual visual,
    Slot slot, {
    required Map<String, DatasetPage> companions,
    required bool full,
    double? height,
    double frame = 640,
  }) {
    final d = page.descriptor;
    final dims = _slotDimensions(d, slot);
    final ms = slotMeasures(d, slot);
    switch (visual) {
      case Visual.kpi:
        return KpiTiles(
          page: page,
          measures: slot.measures.isNotEmpty ? ms : null,
        );
      case Visual.line:
        if (full && ms.length > ReportPalette.slots) {
          return SmallMultiples(
            titles: [for (final m in ms) labelWithUnit(m)],
            pages: [for (final _ in ms) page],
            x: dims.first,
            measures: ms,
            line: true,
            measurePerCell: true,
          );
        }
        return SeriesLineChart(
          page: page,
          x: dims.first,
          measures: ms,
          height: height ?? (full ? 420 : 260),
          pointWidth: full ? fullPointWidth : null,
        );
      case Visual.curve:
        return SeriesLineChart(
          page: page,
          x: dims.isNotEmpty ? dims.first : d.fields.first,
          measures: ms,
          numericX: true,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.stepLine:
      case Visual.area:
      case Visual.stackedArea:
      case Visual.stackedArea100:
      case Visual.streamgraph:
      case Visual.sparkline:
      case Visual.bumpChart:
      case Visual.candlestick:
      case Visual.rangeBand:
      case Visual.annotatedLine:
      case Visual.timeline:
      case Visual.gantt:
      case Visual.calendarHeatmap:
      case Visual.horizon:
      case Visual.controlChart:
      case Visual.burndown:
      case Visual.cyclePlot:
        return TimeCatalogChart(
          page: page,
          visual: visual,
          x: dims.first,
          measures: ms,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.bar:
        return VerticalBarChart(
          page: page,
          x: dims.first,
          measure: ms.first,
          height: height ?? (full ? 420 : 260),
          pointWidth: full ? fullPointWidth : null,
        );
      case Visual.stackedBar:
        if (full) {
          final totals = <String, double>{};
          for (final r in page.rows) {
            final k = '${r[dims[1].name]}';
            if (measureValue(r[ms.first.name], ms.first) case final v?) {
              totals[k] = (totals[k] ?? 0) + v;
            }
          }
          if (totals.length > ReportPalette.slots) {
            final cats = totals.keys.toList()
              ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
            final labels = {
              for (final r in page.rows)
                '${r[dims[1].name]}': valueText(r[dims[1].name], dims[1]),
            };
            return SmallMultiples(
              titles: [for (final c in cats) labels[c]!],
              pages: SmallMultiples.split(page, dims[1], cats),
              x: dims[0],
              measures: [ms.first],
            );
          }
        }
        return StackedBarChart(
          page: page,
          x: dims[0],
          category: dims[1],
          measure: ms.first,
          height: height ?? (full ? 460 : 300),
        );
      case Visual.hbar:
        final (main, second) = ranked(d, slot);
        if (full) {
          return RankingColumns(
            page: page,
            label: dims.first,
            measure: main,
            share: second,
            frame: frame,
          );
        }
        return RankingBars(
          page: page,
          label: dims.first,
          measure: main,
          share: second,
          maxItems: null,
        );
      case Visual.donut:
        final (main, second) = ranked(d, slot);
        return DonutChart(
          page: page,
          label: dims.first,
          value: main,
          share: second?.type == 'percent' ? second : null,
          listMaxHeight: full ? frame : null,
        );
      case Visual.pie:
      case Visual.gauge:
      case Visual.meter:
      case Visual.treemap:
      case Visual.sunburst:
      case Visual.icicle:
      case Visual.circlePacking:
      case Visual.waffle:
      case Visual.nightingaleRose:
      case Visual.funnel:
        return PartWholeCatalogChart(
          page: page,
          visual: visual,
          label: dims.first,
          value: ms.first,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.histogram:
      case Visual.boxPlot:
      case Visual.violin:
      case Visual.density:
      case Visual.ridgeline:
      case Visual.strip:
      case Visual.ecdf:
      case Visual.qqPlot:
      case Visual.populationPyramid:
      case Visual.raincloud:
        return DistributionCatalogChart(
          page: page,
          visual: visual,
          label: dims.first,
          value: ms.first,
          secondValue: ms.length > 1 ? ms[1] : null,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.scatter:
      case Visual.bubble:
      case Visual.heatmap:
      case Visual.correlationMatrix:
      case Visual.hexbin:
      case Visual.contour2d:
      case Visual.splom:
      case Visual.quadrant:
      case Visual.ternary:
        return RelationCatalogChart(
          page: page,
          visual: visual,
          label: dims.first,
          xMeasure: ms.first,
          yMeasure: ms.length > 1 ? ms[1] : ms.first,
          sizeMeasure: ms.length > 2 ? ms[2] : null,
          measures: ms,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.alluvial:
      case Visual.chord:
      case Visual.arcDiagram:
      case Visual.flowchart:
      case Visual.layeredDag:
      case Visual.sequenceDiagram:
      case Visual.stateDiagram:
      case Visual.swimlane:
      case Visual.treeOrg:
      case Visual.dendrogram:
      case Visual.mindMap:
      case Visual.network:
      case Visual.adjacencyMatrix:
      case Visual.erDiagram:
      case Visual.architectureDiagram:
        return DiagramCatalogChart(
          page: page,
          visual: visual,
          dims: dims,
          measure: ms.first,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.venn:
      case Visual.euler:
      case Visual.upset:
        return SetsCatalogChart(
          page: page,
          visual: visual,
          label: dims.first,
          measure: ms.first,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.bubbleMap:
      case Visual.choropleth:
      case Visual.geoHeatmap:
      case Visual.flowMap:
      case Visual.hexTileMap:
        return GeoCatalogChart(
          page: page,
          visual: visual,
          label: dims.first,
          value: ms.first,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.combo:
        return AlignedCharts(
          page: page,
          x: dims.first,
          first: ms[0],
          second: ms[1],
          height: height ?? (full ? 460 : 320),
        );
      case Visual.map:
        final links = slot.companions
            .map((c) => companions[c])
            .whereType<DatasetPage>()
            .firstOrNull;
        final label = dims.firstWhere(
          (f) => f.type == 'string',
          orElse: () => dims.first,
        );
        return SpatialMap(
          points: page,
          links: links,
          label: label,
          value: ms.first,
          share: _share(d, ms.first),
          listSize: full ? page.rows.length : 8,
          height: height,
          maxHeight: full ? frame : null,
        );
      case Visual.sankey:
        // A Sankey uses every loaded row; it suits aggregated datasets.
        return SankeyChart(
          page: page,
          stages: sankeyStages(d, slot),
          measure: ms.first,
          height: height,
          maxHeight: full ? frame : null,
        );
      case Visual.rankingBar:
      case Visual.groupedBar:
      case Visual.stackedBar100:
      case Visual.divergingBar:
      case Visual.floatingBar:
      case Visual.lollipop:
      case Visual.dotPlot:
      case Visual.dumbbell:
      case Visual.slope:
      case Visual.bullet:
      case Visual.utilizationBar:
      case Visual.pictogram:
      case Visual.radialBar:
      case Visual.circularBar:
      case Visual.radar:
      case Visual.parallelCoordinates:
      case Visual.marimekko:
      case Visual.waterfall:
      case Visual.pareto:
      case Visual.smallMultiples:
        return ComparisonCatalogChart(
          page: page,
          visual: visual,
          dimension: dims.first,
          measures: ms,
          seriesField: dims.length > 1 ? dims[1] : null,
          height: height ?? (full ? 420 : 260),
        );
      case Visual.kpiSparkline:
      case Visual.heatTable:
      case Visual.statusScorecard:
      case Visual.wordCloud:
        return IndicatorTableChart(
          page: page,
          visual: visual,
          dimension: dims.isNotEmpty ? dims.first : null,
          measures: ms,
          height: height ?? (full ? 360 : 240),
        );
      case Visual.topKProb:
      case Visual.calibration:
      case Visual.confusionMatrix:
      case Visual.rocPr:
      case Visual.learningCurve:
      case Visual.irtIcc:
      case Visual.irtIif:
      case Visual.wrightMap:
      case Visual.itemDiffDisc:
      case Visual.kaplanMeier:
        return ScienceAiChart(
          page: page,
          visual: visual,
          dimension: dims.isNotEmpty ? dims.first : null,
          measures: ms,
          height: height ?? (full ? 360 : 240),
        );
      case Visual.table:
      case Visual.auto:
        // Full view: pages of 50 rows; header and pager stay inside the frame.
        return DataTableView(
          page: page,
          maxRows: full ? null : previewLimit(Visual.table),
          maxHeight:
              height ?? (full ? (frame - 100).clamp(200.0, 4000.0) : 380),
          pageSize: full ? fullPageSize : null,
        );
    }
  }
}
