import 'package:flutter/material.dart';
import '../models/report.dart';
import '../themes/report_palette.dart';
import 'chart_parts.dart';

enum ChartFrameMode { card, full, embed }

enum ChartFrameState { ready, loading, empty, restricted, error, offline }

/// Standard chart frame wrapping any visual (C1, C2, C18, C19, C22).
class ChartFrame extends StatelessWidget {
  final DatasetPage page;
  final Widget child;
  final ChartFrameMode mode;
  final ChartFrameState state;
  final String? title;
  final String? subtitle;
  final String? snapshotDate;
  final bool showAxisTitles;
  final bool showAsTable;
  final VoidCallback? onToggleTable;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRetry;
  final double? fixedHeight;

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
    this.onToggleTable,
    this.onSeeAll,
    this.onRetry,
    this.fixedHeight,
  });

  static (String?, String?) axisTitlesFor(DatasetPage page) {
    final x = page.descriptor.fields.where((f) => f.isDimension || f.isTime).firstOrNull;
    final y = page.descriptor.fields.where((f) => f.isNumeric).firstOrNull;
    return (
      x == null ? null : ChartParts.labelWithUnit(x),
      y == null ? null : ChartParts.labelWithUnit(y),
    );
  }

  String _sourceText() {
    final s = page.descriptor.meta?.source.trim() ?? '';
    return s.isEmpty ? 'Source unavailable' : 'Source: $s';
  }

  String _periodText() {
    final m = page.descriptor.meta;
    if (m == null || (m.periodStart.isEmpty && m.periodEnd.isEmpty)) {
      return 'Period unavailable';
    }
    final tz = m.timezone.isEmpty ? 'UTC' : m.timezone;
    if (m.periodStart.isNotEmpty && m.periodEnd.isNotEmpty) {
      return 'Period: ${m.periodStart} to ${m.periodEnd} ($tz)';
    }
    return 'Period: ${m.periodStart}${m.periodEnd} ($tz)';
  }

  String _updatedText() {
    if (snapshotDate != null && snapshotDate!.trim().isNotEmpty) {
      return 'Snapshot: ${snapshotDate!.trim()}';
    }
    final calcAt = page.lineage?.calculatedAt.trim() ?? '';
    final m = page.descriptor.meta;
    final tz = (m?.timezone.isNotEmpty ?? false) ? m!.timezone : 'UTC';
    if (calcAt.isNotEmpty) {
      return state == ChartFrameState.offline
          ? 'Offline — last updated $calcAt ($tz)'
          : 'Updated: $calcAt ($tz)';
    }
    if (m != null && m.updatedAt > 0) {
      return state == ChartFrameState.offline
          ? 'Offline — last updated ${m.updatedAt} ($tz)'
          : 'Updated: ${m.updatedAt} ($tz)';
    }
    return 'Last update unavailable';
  }

  String _tierLabel() {
    final raw = (page.descriptor.meta?.tier.isNotEmpty ?? false)
        ? page.descriptor.meta!.tier
        : page.descriptor.dataTier;
    return switch (raw) {
      'real' => 'Real',
      'hybrid' => 'Hybrid',
      _ => 'Sample',
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
              Text('Loading chart...', style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ChartFrameState.empty => Center(
          child: Text(
            'No data for this period',
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
                'Restricted chart',
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
                'Could not load chart',
                style: TextStyle(color: p.negative, fontSize: 12),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 6),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
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
    if (!showAxisTitles) return child;
    final (xTitle, yTitle) = axisTitlesFor(page);
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final resolvedTitle = (title ?? page.descriptor.title).trim();
    final resolvedSubtitle = (subtitle ?? page.descriptor.description).trim();
    final tier = _tierLabel();

    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedTitle.isEmpty ? page.descriptor.datasetId : resolvedTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: mode == ChartFrameMode.full ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (resolvedSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        resolvedSubtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tier,
                  style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              if (onToggleTable != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onToggleTable,
                  child: Text(showAsTable ? 'Show as chart' : 'Show as table'),
                ),
              ],
              if (mode == ChartFrameMode.card && onSeeAll != null) ...[
                const SizedBox(width: 4),
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Flexible(fit: FlexFit.loose, child: _buildBody(context, p)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(_sourceText(), style: TextStyle(color: p.textMuted, fontSize: 11)),
              Text(_periodText(), style: TextStyle(color: p.textMuted, fontSize: 11)),
              Text(_updatedText(), style: TextStyle(color: p.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
