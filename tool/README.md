# Data pipeline

Builds the package's map data from the raw OKNP boundaries. Only maintainers
need to run this; the output is committed.

```sh
dart run tool/build_data.dart                  # development build
dart run tool/build_data.dart --strict         # release build: every Nepali name required
dart run tool/build_data.dart --simplify=25%   # try a different detail level
```

**Requires** Node.js. mapshaper is fetched through `npx` at the pinned
version in `build_data.dart`, so there is nothing to install globally.

## Inputs

| File | What it is |
|---|---|
| `source/raw/oknp_local_levels.topojson` | Unmodified OKNP download (see `source/README.md`) |
| `source/names.csv` | Source of truth for codes, English and Nepali names, types and aliases |

## Outputs

| File | What it is |
|---|---|
| `assets/maps/nepal.topo.json` | One topology with `provinces`, `districts`, `local_levels`, `protected_areas`. Each feature's `id` is its code. |
| `lib/src/data/models/region.g.dart` | `Province`, `District`, `LocalLevel`, `ProtectedArea` enums |

## Steps

1. Validate `names.csv`: counts (7 / 77 / 753 / 10), unique codes, valid
   parents and types, Devanagari-only `name_ne`.
2. Tag every raw feature with its codes, matching on `source_keys`
   (`DISTRICT|GaPa_NaPa` from the raw file).
3. mapshaper: simplify the shared arcs once, then dissolve into provinces,
   districts, local levels (joining split municipalities) and protected areas.
4. Replace properties with the code as `id`, sort by code, check counts.
5. Generate `region.g.dart` and run `dart format` on it.

The build is deterministic. CI re-runs it and fails if the output changes.

## Editing names.csv

| Column | Notes |
|---|---|
| `code` | Never change a published code. New regions get new codes. |
| `level` | `province`, `district`, `local_level` or `protected_area` |
| `parent_code` | District → province, local level → district, empty otherwise |
| `name_en` | Short name without the type, e.g. `Pokhara` |
| `name_ne` | Devanagari short name, e.g. `पोखरा`. Empty until sourced. |
| `ne_status` | `missing` (empty), `draft` (needs native-speaker review) or `verified` |
| `type` | Local levels: `metropolitan`, `subMetropolitan`, `municipality`, `ruralMunicipality`. Protected areas: `nationalPark`, `wildlifeReserve`, `huntingReserve`, `watershedAndWildlifeReserve`, `developmentArea`. |
| `aliases` | Other spellings, `;`-separated. Used by search. |
| `source_keys` | Which raw features make up this region, `;`-separated |

Codes: `P{province}`, `D{province}{nn}`, `L{province}{nn}{mm}`, `PA{nn}`.
District and local-level numbers were assigned alphabetically within their
parent when the file was first created.

Nepali names: take them from the government's official list of local levels.
Don't copy them in bulk from OpenStreetMap or Wikipedia: their share-alike
licenses would then apply to this data.
