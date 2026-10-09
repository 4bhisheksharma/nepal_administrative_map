# nepal_administrative_map

An interactive administrative map of Nepal for Flutter: **7 provinces,
77 districts and 753 local levels**, in **English and Nepali**.

- No third-party dependencies, works offline: one 422 KB data file is bundled.
- Typed regions (`District.kaski`, `LocalLevel.pokhara`) with stable codes
  and names in both languages.
- Tap to select, scope to one province or district, theme with your app's
  colours (light and dark).
- A pure-Dart core for server and CLI use: point lookup, name and number
  formatting, no Flutter needed.

| Districts | Local levels (dark) |
|---|---|
| ![District map](doc/screenshots/districts.png) | ![Local-level map](doc/screenshots/local_levels_dark.png) |

## Install

```sh
flutter pub add nepal_administrative_map
```

## Usage

```dart
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

// The 7 provinces, tap to select.
const NepalMap();

// Districts of Gandaki, in Nepali.
NepalMap(
  level: AdminLevel.district,
  scope: Province.gandaki,
  language: MapLanguage.ne,
  onRegionTap: (region) => print(region.fullName(MapLanguage.ne)),
);

// Your own colours.
NepalMap(
  level: AdminLevel.localLevel,
  style: (region, state) => RegionStyle(
    fill: state.isSelected ? Colors.orange : Colors.green.shade100,
    outline: state.isSelected ? Colors.deepOrange : null,
  ),
);
```

The map fills the space it's given. With unbounded height (e.g. in a
`Column` inside a scroll view) it keeps Nepal's aspect ratio.

### Selection

`selectionMode` is `single` (default), `multi` or `none`. The map keeps its
own selection, or pass `selected` and `onSelectionChanged` to control it.

### Language

By default the map follows the app's locale: Nepali for `ne`, English
otherwise. Set `language` to override it.

```dart
LocalLevel.pokhara.fullName(MapLanguage.en);  // Pokhara Metropolitan City
LocalLevel.pokhara.fullName(MapLanguage.ne);  // पोखरा महानगरपालिका
NepalNumberFormat.format(1744240, language: MapLanguage.ne);  // १७,४४,२४०
```

> Nepali names of the 753 local levels are still being added; until then
> they show in English. Province, district and type names are in Nepali.

### Theme

Colours come from your `ColorScheme`. To customise them, add a
`NepalMapTheme` to your theme, or pass one to a single map:

```dart
ThemeData(
  extensions: [
    NepalMapTheme.fromColorScheme(scheme).copyWith(regionFill: Colors.teal.shade50),
  ],
);
```

### Preloading

The data is decoded in the background the first time a map is shown
(about 25 ms). To have it ready before the first frame:

```dart
void main() {
  NepalMap.preload();
  runApp(const MyApp());
}
```

### Without Flutter

`package:nepal_administrative_map/core.dart` has no Flutter dependency:

```dart
final data = await NepalMapData.load(
  MapDataSource.callback('nepal', () => File(pathToTopoJson).readAsString()),
);
data.regionAt(const LatLng(27.7043, 85.3070), AdminLevel.localLevel);
// LocalLevel.kathmandu
```

## Regions

| Level | Count | Example |
|---|---|---|
| `Province` | 7 | `Province.bagmati` (`P3`) |
| `District` | 77 | `District.kathmandu` (`D305`) |
| `LocalLevel` | 753 | `LocalLevel.pokhara` (`L40304`) |
| `ProtectedArea` | 10 | `ProtectedArea.chitwan` (`PA02`) |

Codes never change once published, so you can store them or join your own
data on them. Municipalities that share a name include their district:
`LocalLevel.kalikaChitwan`, `LocalLevel.bagmatiSarlahi`.

The 10 protected areas are the ones outside every local level. On
local-level maps they are drawn in a muted colour and can't be tapped.

## Data & attribution

Boundary data: **© [OKNP LocalBoundaries](https://localboundries.oknp.org/)**,
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The data has been simplified and extended with codes and Nepali names; see
[DATA_LICENSE.md](DATA_LICENSE.md) for the full list of changes.

The map shows a small credit line by default. If you hide it
(`showAttribution: false`), credit the data elsewhere in your app, for
example on an About screen, using `NepalMap.attribution` and
`NepalMap.attributionUrl`.
