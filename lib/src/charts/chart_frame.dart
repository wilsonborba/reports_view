import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/chart_strings.dart';
import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';
import 'data_table_view.dart';
import 'format.dart';

enum ChartFrameMode { card, full, embed }

enum ChartFrameState { ready, loading, empty, restricted, error, offline }

/// Standard chart frame wrapping any visual (C1, C2, C16, C18, C19, C22).
class ChartFrame extends StatefulWidget {
  final DatasetPage page;
  final Widget child;
  final ChartFrameMode mode;
  final ChartFrameState state;
  final String? title;
  final String? subtitle;
  final String? snapshotDate;
  final bool showAxisTitles;
  final bool showAsTable;
  final bool enableTableToggle;
  final VoidCallback? onToggleTable;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRetry;
  final double? fixedHeight;
  final String? errorMessage;

  const ChartFrame({
    super.key,
    required this.page,
    required this.child,
    this.mode = ChartFrameMode.card,
    this.state = ChartFrameState.ready,
    this.title,
    this.subtitle,
    this.snapshotDate,
    this.showAxisTitles = true,
    this.showAsTable = false,
    this.enableTableToggle = true,
    this.onToggleTable,
    this.onSeeAll,
    this.onRetry,
    this.fixedHeight,
    this.errorMessage,
  });

  static (String?, String?) axisTitlesFor(DatasetPage page) {
    final x = page.descriptor.fields.where((f) => f.isDimension || f.isTime).firstOrNull;
    final y = page.descriptor.fields.where((f) => f.isNumeric).firstOrNull;
    return (
      x == null ? null : ChartParts.labelWithUnit(x),
      y == null ? null : ChartParts.labelWithUnit(y),
    );
  }

  static String semanticsSummary(DatasetPage page, {String? title}) {
    final resolvedTitle = (title ?? page.descriptor.title).trim();
    final label = resolvedTitle.isEmpty ? page.descriptor.datasetId : resolvedTitle;
    final count = page.rows.length;
    final m = page.descriptor.fields.where((f) => f.isNumeric).firstOrNull;
    if (m == null || page.rows.isEmpty) {
      return '$label, $count rows';
    }
    final vals = [
      for (final r in page.rows) ?measureValue(r[m.name], m),
    ];
    if (vals.isEmpty) {
      return '$label, $count rows, no numeric values';
    }
    var lo = vals.first, hi = vals.first;
    for (final v in vals) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return '$label, $count rows, ${m.label} from ${valueWithUnit(lo, m)} to ${valueWithUnit(hi, m)}';
  }

  @override
  State<ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<ChartFrame> {
  late bool _localTable = widget.showAsTable;

  bool get _showingTable => widget.onToggleTable != null ? widget.showAsTable : _localTable;

  DatasetPage get page => widget.page;
  ChartFrameMode get mode => widget.mode;
  ChartFrameState get state => widget.state;
  String? get title => widget.title;
  String? get subtitle => widget.subtitle;
  String? get snapshotDate => widget.snapshotDate;
  bool get showAxisTitles => widget.showAxisTitles;
  VoidCallback? get onSeeAll => widget.onSeeAll;
  VoidCallback? get onRetry => widget.onRetry;
  double? get fixedHeight => widget.fixedHeight;
  String? get errorMessage => widget.errorMessage;
  Widget get child => _showingTable ? DataTableView(page: page) : widget.child;

  String _sourceText(BuildContext context) {
    final s = page.descriptor.meta?.source.trim() ?? '';
    return s.isEmpty
        ? context.tr('source_unavailable')
        : context.tr('source_label', {'source': s});
  }

  String _periodText(BuildContext context) {
    final m = page.descriptor.meta;
    if (m == null || (m.periodStart.isEmpty && m.periodEnd.isEmpty)) {
      return context.tr('period_unavailable');
    }
    final tz = m.timezone.isEmpty ? 'UTC' : m.timezone;
    if (m.periodStart.isNotEmpty && m.periodEnd.isNotEmpty) {
      return context.tr('period_range', {
        'start': m.periodStart,
        'end': m.periodEnd,
        'tz': tz,
      });
    }
    return context.tr('period_single', {
      'value': '${m.periodStart}${m.periodEnd}',
      'tz': tz,
    });
  }

  String _updatedText(BuildContext context) {
    if (snapshotDate != null && snapshotDate!.trim().isNotEmpty) {
      return context.tr('snapshot_label', {'value': snapshotDate!.trim()});
    }
    final calcAt = page.lineage?.calculatedAt.trim() ?? '';
    final m = page.descriptor.meta;
    final tz = (m?.timezone.isNotEmpty ?? false) ? m!.timezone : 'UTC';
    if (calcAt.isNotEmpty) {
      return state == ChartFrameState.offline
          ? context.tr('offline_updated', {'value': calcAt, 'tz': tz})
          : context.tr('updated_label', {'value': calcAt, 'tz': tz});
    }
    if (m != null && m.updatedAt > 0) {
      return state == ChartFrameState.offline
          ? context.tr('offline_updated', {'value': '${m.updatedAt}', 'tz': tz})
          : context.tr('updated_label', {'value': '${m.updatedAt}', 'tz': tz});
    }
    return context.tr('last_update_unavailable');
  }

  String _tierLabel(BuildContext context) {
    final raw = (page.descriptor.meta?.tier.isNotEmpty ?? false)
        ? page.descriptor.meta!.tier
        : page.descriptor.dataTier;
    return switch (raw) {
      'real' => context.tr('tier_real'),
      'hybrid' => context.tr('tier_hybrid'),
      _ => context.tr('tier_sample'),
    };
  }

  Widget _buildBody(BuildContext context, ReportPalette p) {
    final body = switch (state) {
      ChartFrameState.loading => Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
              ),
              const SizedBox(width: 8),
              Text(context.tr('loading_chart'), style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ChartFrameState.empty => Center(
          child: Text(
            context.tr('no_data_period'),
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
        ),
      ChartFrameState.restricted => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 20, color: p.textMuted),
              const SizedBox(height: 4),
              Text(
                context.tr('restricted_chart'),
                style: TextStyle(color: p.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ChartFrameState.error => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage ?? context.tr('error_chart'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.negative, fontSize: 12),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 6),
                TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
              ],
            ],
          ),
        ),
      ChartFrameState.ready || ChartFrameState.offline => _buildAxisWrappedChild(p),
    };
    if (fixedHeight == null) return body;
    if (state == ChartFrameState.ready) {
      return ConstrainedBox(constraints: BoxConstraints(minHeight: fixedHeight!), child: body);
    }
    return SizedBox(height: fixedHeight, child: body);
  }

  Widget _buildAxisWrappedChild(ReportPalette p) {
    if (!showAxisTitles || _showingTable) return child;
    final (xTitle, yTitle) = ChartFrame.axisTitlesFor(page);
    if (xTitle == null && yTitle == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (yTitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              yTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
          ),
        Flexible(fit: FlexFit.loose, child: child),
        if (xTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              xTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ReportPalette p, {
    required String resolvedTitle,
    required String resolvedSubtitle,
    required String tier,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final inheritedTextStyle = DefaultTextStyle.of(context).style;
        final titleStyle = inheritedTextStyle.merge(
          TextStyle(
            color: p.textPrimary,
            fontSize: mode == ChartFrameMode.full ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        );
        final subtitleStyle = inheritedTextStyle.merge(
          TextStyle(color: p.textMuted, fontSize: 12),
        );
        double measureText(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        bool exceedsTwoLines(String text, TextStyle style, double width) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
            ellipsis: '\u2026',
          )..layout(maxWidth: math.max(1, width));
          final exceeds = painter.didExceedMaxLines;
          painter.dispose();
          return exceeds;
        }

        final hasTableToggle =
            widget.onToggleTable != null ||
            (widget.enableTableToggle && state == ChartFrameState.ready);
        final tableLabel = _showingTable
            ? context.tr('show_as_chart')
            : context.tr('show_as_table');
        final tableToggle = hasTableToggle
            ? TextButton(
                onPressed:
                    widget.onToggleTable ??
                    () => setState(() => _localTable = !_localTable),
                child: Text(tableLabel),
              )
            : null;
        final seeAllLabel = context.tr('see_all');
        final seeAll = mode == ChartFrameMode.card && onSeeAll != null
            ? TextButton(onPressed: onSeeAll, child: Text(seeAllLabel))
            : null;
        const enabledButtonStates = <WidgetState>{};
        final actionButton = tableToggle ?? seeAll;
        final widgetButtonStyle = actionButton?.style;
        final themeButtonStyle = TextButtonTheme.of(context).style;
        // Resolve the exact TextButton defaults from the existing action widget.
        final defaultButtonStyle = actionButton?.defaultStyleOf(context);
        final buttonStyle =
            widgetButtonStyle?.textStyle?.resolve(enabledButtonStates) ??
            themeButtonStyle?.textStyle?.resolve(enabledButtonStates) ??
            defaultButtonStyle?.textStyle?.resolve(enabledButtonStates) ??
            Theme.of(context).textTheme.labelLarge!;
        final buttonPadding =
            widgetButtonStyle?.padding?.resolve(enabledButtonStates) ??
            themeButtonStyle?.padding?.resolve(enabledButtonStates) ??
            defaultButtonStyle?.padding?.resolve(enabledButtonStates) ??
            EdgeInsets.zero;
        final minButtonSize =
            widgetButtonStyle?.minimumSize?.resolve(enabledButtonStates) ??
            themeButtonStyle?.minimumSize?.resolve(enabledButtonStates) ??
            defaultButtonStyle?.minimumSize?.resolve(enabledButtonStates) ??
            Size.zero;
        final visualDensity =
            widgetButtonStyle?.visualDensity ??
            themeButtonStyle?.visualDensity ??
            defaultButtonStyle?.visualDensity ??
            Theme.of(context).visualDensity;
        final minButtonWidth = math.max(
          0.0,
          minButtonSize.width + visualDensity.baseSizeAdjustment.dx,
        );
        double buttonWidth(String label) => math.max(
          minButtonWidth,
          measureText(label, buttonStyle) + buttonPadding.horizontal,
        );
        final tierStyle = inheritedTextStyle.merge(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        );
        final tierWidth = measureText(tier, tierStyle) + 16;
        final actionWidth =
            8 +
            tierWidth +
            (tableToggle == null ? 0 : 6 + buttonWidth(tableLabel)) +
            (seeAll == null ? 0 : 4 + buttonWidth(seeAllLabel));
        final headingWidth = constraints.maxWidth - actionWidth;
        final resolvedHeadingTitle = resolvedTitle.isEmpty
            ? page.descriptor.datasetId
            : resolvedTitle;
        final compact =
            constraints.maxWidth < 440 * textScale ||
            exceedsTwoLines(resolvedHeadingTitle, titleStyle, headingWidth) ||
            (resolvedSubtitle.isNotEmpty &&
                exceedsTwoLines(resolvedSubtitle, subtitleStyle, headingWidth));
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resolvedHeadingTitle,
              maxLines: compact ? null : 2,
              overflow: compact ? null : TextOverflow.ellipsis,
              style: titleStyle,
            ),
            if (resolvedSubtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                resolvedSubtitle,
                maxLines: compact ? null : 2,
                overflow: compact ? null : TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
            ],
          ],
        );
        final tierBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(tier, style: tierStyle.copyWith(color: p.textPrimary)),
        );
        final actions = [tierBadge, ?tableToggle, ?seeAll];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading,
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: actions,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 8),
            tierBadge,
            if (tableToggle != null) ...[const SizedBox(width: 6), tableToggle],
            if (seeAll != null) ...[const SizedBox(width: 4), seeAll],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final resolvedTitle = (title ?? page.descriptor.title).trim();
    final resolvedSubtitle = (subtitle ?? page.descriptor.description).trim();
    final tier = _tierLabel(context);

    return Semantics(
      label: ChartFrame.semanticsSummary(page, title: title),
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(mode == ChartFrameMode.embed ? 6 : 8),
        ),
        padding: EdgeInsets.all(mode == ChartFrameMode.embed ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(
              context,
              p,
              resolvedTitle: resolvedTitle,
              resolvedSubtitle: resolvedSubtitle,
              tier: tier,
            ),
            const SizedBox(height: 8),
            Flexible(fit: FlexFit.loose, child: _buildBody(context, p)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(_sourceText(context), style: TextStyle(color: p.textMuted, fontSize: 11)),
                Text(_periodText(context), style: TextStyle(color: p.textMuted, fontSize: 11)),
                Text(_updatedText(context), style: TextStyle(color: p.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
