# Changelog

## [unreleased]

### 🚀 Features

- *(catalog)* Add flow, process, and structure diagram templates (items 74 to 89) (#60)
- *(catalog)* Add sets templates (items 90 to 92: venn, euler, upset) (#61)
- *(geo)* Add geographic catalog visuals bubble_map, choropleth, geo_heatmap, flow_map, hex_tile_map (#62)
- *(catalog)* Add indicators and tables visuals kpi_sparkline, heat_table, status_scorecard, word_cloud (#63)
- *(catalog)* Add science, AI, and assessment catalog visuals (items 105 to 114) (#64)

### 🐛 Bug Fixes

- *(diagrams,sets)* Apply ReportPalette fontFamily + Thai fallback and realistic diagram fixtures (#60)
- *(sets)* Non-overlapping Venn/Euler outer labels, Euler disjointness, UpSet intersections (#61)
- *(catalog)* Compute science curves, fix KPI regression, add Natural Earth maps
- *(charts)* Equirectangular map projection, region names, and exact science assertions (#62, #64)
- *(charts)* Ensure C12 map label contrast, single-class ROC unavailability, and C8 missing-data omission (#62, #64)
- *(table)* Align header columns with scaled rows
- Wrap chart headers when localized content needs room
- *(charts)* Integrate responsive report headers
- *(charts)* Fit category labels to available slots
- *(charts)* Apply label thinning once
- *(charts)* Integrate available category label widths (#3)
- Format embedded chart numbers by host locale
- *(charts)* Propagate host locale through catalog labels and repaint
- *(charts)* Integrate reviewed host locale formatting and repaint (#4)

### 📚 Documentation

- *(changelog)* Record table column alignment fix
- *(changelog)* Record responsive chart header correction
- *(changelog)* Record category label correction

### 🎨 Styling

- *(charts)* Format touched chart files
- *(charts)* Brace guarded returns

### 🧪 Testing

- Refresh table geometry goldens
- *(goldens)* Update category label layouts

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
