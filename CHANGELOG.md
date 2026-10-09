## Unreleased

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
