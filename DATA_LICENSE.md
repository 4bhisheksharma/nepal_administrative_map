# Data license

The boundary data in `assets/maps/nepal.topo.json` and the region names and
codes in `lib/src/data/models/region.g.dart` are licensed under
[Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

The package's source code is licensed separately; see [LICENSE](LICENSE).

## Source

**LocalBoundaries** by Open Knowledge Foundation Nepal (OKNP),
<https://localboundries.oknp.org/download/>, licensed under CC BY 4.0.
Downloaded 2026-10-09 ("All Nepal (777 units)" local-level TopoJSON).

This package is not affiliated with or endorsed by OKNP.

## Changes made

The original data was modified as follows:

- **Simplified** with mapshaper (Visvalingam, weighted, 40% of points kept)
  and re-quantized (1e5 grid).
- **Districts and provinces rebuilt** by dissolving local-level boundaries,
  so all three levels share identical borders. (The source's own province
  file was not used.)
- **Merged** the two municipalities that the source splits into separate
  polygons (Bansagadhi, Bardiya; Binayee Tribeni, Nawalparasi East).
- **Separated** the 22 protected-area polygons (10 protected areas lying
  outside any local level) from the local levels.
- **Renamed** some regions to current or common spellings, keeping the
  source spelling as an alias: Pokhara Lekhnath → Pokhara; districts
  Chitawan → Chitwan, Kabhrepalanchok → Kavrepalanchok, Makawanpur →
  Makwanpur, Tanahu → Tanahun, Kapilbastu → Kapilvastu, Nawalparasi_E/W →
  Nawalparasi East/West, Rukum_E/W → Rukum East/West.
- **Added** stable region codes and Nepali (Devanagari) names, which are not
  part of the source data. See `tool/source/names.csv`.
- **Removed** all source attributes; each feature carries only its code.

## Attribution in apps

When you ship this package's map, credit the data, for example:

> Boundary data: © OKNP LocalBoundaries, CC BY 4.0
