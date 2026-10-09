## Unreleased

* Zoom and pan: pinch, drag, double-tap, mouse wheel; `minZoom`,
  `maxZoom`, `interactive`.
* Hover highlight, `onRegionHover`, and tooltips on hover or long-press
  (`showTooltips`, `tooltipBuilder`, `RegionTooltip`).
* Labels in English, Nepali or both (`labelMode`, `labelBuilder`), placed at
  each region's pole of inaccessibility with collision avoidance.
* Drill-down (`drillDown`, `onScopeChanged`), `NepalMapBreadcrumb`, Esc to
  go back.
* `NepalMapController`: selection, highlight, `zoomTo`, `zoomIn`/`zoomOut`,
  `resetView`, `drillDown`/`drillUp`/`drillTo`, runtime `language`.
* Province borders use the stronger parent style on province maps too.
* `NepalMap` widget: provinces, districts or local levels; `scope` to one
  province or district; tap to select (`single`, `multi`, `none`, or
  controlled with `selected`); style callback; `NepalMapTheme` theme
  extension with light and dark defaults; English / Nepali following the
  app locale; data attribution line; `NepalMap.preload()`.
* Protected areas are filled in a muted colour on local-level maps.
* Bilingual data pipeline (`tool/build_data.dart`) producing a single
  422 KB topology for provinces, districts, local levels and protected areas.
* Typed regions: `Province`, `District`, `LocalLevel`, `ProtectedArea` enums
  with stable codes and English / Nepali names.
* Bilingual basics: `MapLanguage`, `LocalizedName.of`, `NepalNumberFormat`
  (Devanagari digits, lakh/crore grouping), `NepalMapStrings`, Devanagari
  normalisation.
* Regions: `fullName(lang)`, hierarchy getters (`province.districts`,
  `district.localLevels`, `region.province`), translated type and level
  labels, and the `Nepal` gazetteer (`byCode`, `aliasesOf`, …).
* `NepalMapData`: TopoJSON decoding in a background isolate, cached, with
  point lookup (`regionAt`, `protectedAreaAt`).
* Geometry: `LatLng`, `Bounds`, Web Mercator, point-in-polygon, polylabel.
