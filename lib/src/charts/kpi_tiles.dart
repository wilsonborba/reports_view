import 'package:flutter/material.dart';
import '../models/report.dart';
import '../themes/report_palette.dart';
import 'format.dart';
import 'motion.dart';

/// Key figures of a selected row: renders measure tiles (ignoring text dimension
/// labels unless no numeric measure fields exist). Numbers count up from 0 when
/// animations are enabled, or render at final value immediately under reduced motion.
class KpiTiles extends StatelessWidget {
  final DatasetPage page;
  final List<FieldInfo>? measures;
  final int rowIndex;

  const KpiTiles({
    super.key,
    required this.page,
    this.measures,
    this.rowIndex = 0,
  });

  /// Resolves the ordered measure fields shown as KPI tiles for [page].
  static List<FieldInfo> selectMeasureFields(
    DatasetPage page, {
    List<FieldInfo>? overrideMeasures,
  }) {
    if (overrideMeasures != null && overrideMeasures.isNotEmpty) {
      return overrideMeasures;
    }
    final numericMeasures = [
      for (final f in page.descriptor.fields)
        if (!f.isDimension && f.isNumeric) f,
    ];
    return numericMeasures.isNotEmpty
        ? numericMeasures
        : page.descriptor.fields;
  }

  @override
  Widget build(BuildContext context) {
    if (page.rows.isEmpty) return const SizedBox.shrink();
    final safeIdx = rowIndex.clamp(0, page.rows.length - 1);
    final row = page.rows[safeIdx];
    final fields = selectMeasureFields(page, overrideMeasures: measures);
    if (fields.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final columns = (c.maxWidth / 190).floor().clamp(1, 6);
        final width = (c.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final f in fields)
              SizedBox(
                width: width,
                child: _KpiTile(field: f, value: row[f.name]),
              ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatefulWidget {
  final FieldInfo field;
  final dynamic value;

  const _KpiTile({required this.field, required this.value});

  @override
  State<_KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<_KpiTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final numberLanguage = numberLanguageFor(context);
    final f = widget.field;
    final number = asDouble(widget.value);
    Widget valueText_(dynamic v) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: valueText(v, f, language: numberLanguage),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (f.unit != null && f.unit != '%' && f.unit!.isNotEmpty)
              TextSpan(
                text: ' ${f.unit}',
                style: TextStyle(fontSize: 12.5, color: p.textMuted),
              ),
          ],
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(
          0,
          _hover && !reduceMotion(context) ? -2 : 0,
          0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.surfaceAlt.withValues(alpha: _hover ? 0.9 : 0.6),
          borderRadius: BorderRadius.circular(ReportPalette.controlRadius),
          border: Border(left: BorderSide(color: p.accent, width: 3)),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              f.label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            if (number == null)
              valueText_(widget.value)
            else
              EntryAnimation(
                duration: const Duration(milliseconds: 800),
                builder: (context, t) => valueText_(
                  t >= 1
                      ? widget.value
                      : (widget.value is int
                            ? (number * t).round()
                            : number * t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
