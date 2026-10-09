# Source data

`raw/oknp_local_levels.topojson` is the unmodified "Local Levels → All Nepal
(777 units)" TopoJSON from
[OKNP LocalBoundaries](https://localboundries.oknp.org/download/),
downloaded 2026-10-09. License: CC BY 4.0.

Properties per feature: `STATE_CODE`, `DISTRICT`, `GaPa_NaPa`, `Type_GN`,
`Province`.

The 777 features are 755 local-level polygons (753 local levels, two of which
are split in two) plus 22 pieces of 10 protected areas.

Only this file is used: districts and provinces are rebuilt from it, so all
levels share identical borders.

To update: download the new file, replace it here, update the date above,
then run the build and fix any `names.csv` mismatches it reports.
