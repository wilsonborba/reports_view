# Changelog

## [unreleased]

### 🐛 Bug Fixes

- *(table)* Align header columns with scaled rows
- *(charts)* Keep localized headings and table controls readable on narrow cards

### 🧪 Testing

- Refresh table geometry goldens
- Cover localized headings, larger text and themed controls; capture complete narrow cards

## [0.2.0] - 2026-11-20

### 🚀 Features

- *(charts)* Add ChartFrame with source, period, update, tier and states (#46)
- *(a11y)* Add Semantics summary, built-in table toggle and keyboard legend (#49)
- *(templates)* Validate template slot mappings before rendering (#53)
- *(catalog)* Add comparison templates (catalog items 1 to 23) (#55)
- *(catalog)* Add change over time templates (catalog items 24 to 43) (#56)
- *(catalog)* Add part of a whole templates (catalog items 44 to 54) (#57)
- *(catalog)* Add distribution templates (catalog items 55 to 64) (#58)
- *(catalog)* Add relation and correlation templates (catalog items 65 to 73) (#59)

### 🐛 Bug Fixes

- *(charts)* Apply null, zero, negative and missing_means rules (#47)
- *(charts)* Add nice ticks, long-label horizontal fallback, contrast and EN/pt-BR/TH matrix (#50)
- *(catalog)* Add golden tests in EN/pt-BR/TH, size-limit checks, and true horizon/streamgraph/hierarchy layouts (#55, #56, #57)
- *(distribution)* Compute theoretical normal quantiles in qqPlot (#58)
- *(goldens)* Load Ubuntu Sans and IBM Plex Sans Thai fonts and regenerate 192 goldens (#55, #56, #57, #58)
- *(reports_view#68)* Localize ChartFrame labels via context.tr and remove em dash
- *(reports_view#68)* Apply Localizations.override in golden tests so pt-BR and TH ChartFrame labels render
- *(relation)* Replace placeholder relation painters with real data-driven renderers, add data-sensitivity tests, and avoid repeating ternary corner label with two measures (#59)

## 0.1.0

- Initial extraction of the pure Flutter chart, diagram, KPI, and table renderer from `reports_ui` with caller-supplied theme tokens and open-in-Reports link builder.
