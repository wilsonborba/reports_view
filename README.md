# reports_view

Pure Flutter rendering package for analytical charts, diagrams, KPI tiles, and data tables.

The host application supplies the data (`DatasetPage`), theme tokens (`ReportPalette`), and optional open-in-Reports destination builder (`ReportsLinkBuilder`). The package contains no HTTP client, authentication, or application-specific hosts.

## Template-only rendering

Consumer apps (such as Certifications stats and Cortex telemetry) can render backend aggregates directly against a published `VisualTemplate` without creating any Reports dataset, report, or catalog row:

```dart
VisualChooser.buildTemplate(
  page: aggregatePage,
  template: publishedTemplate,
  binding: binding,
)
```

`VisualChooser.buildTemplate` runs `TemplateValidator.validate` before drawing:
- Verifies template ID and version match the binding.
- Rejects unknown slot names.
- Enforces `minCount` (when `isRequired`), `maxCount`, field existence, and `acceptedTypes` per slot.
- Renders `ChartFrameState.error` with the validation message when any check fails.

### Limits
- Card preview limits: `hbar` 10 rows, `table` 8 rows, `map` 8 list items; full view table page size is 50 rows.
- Geographic boundaries (`lib/src/geo/natural_earth_boundaries.dart`, 169,864 bytes / ~165.9 KiB) bundle simplified Natural Earth 1:110m admin-0 (174 countries) and 1:10m admin-1 (77 Thailand provinces, 27 Brazil states) polygons joined by ISO 3166-1/3166-2 codes. Source: Natural Earth (Public Domain).
- Published template versions are immutable (`409 Conflict` on overwrite).
