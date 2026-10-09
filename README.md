# nepal_administrative_map

An interactive administrative map of Nepal for Flutter: **7 provinces,
77 districts and 753 local levels**, in **English and Nepali**.

- No third-party dependencies, works offline: one 422 KB data file is bundled.
- Typed regions (`District.kaski`, `LocalLevel.pokhara`) with stable codes
  and names in both languages.
- Zoom, pan, hover tooltips, labels in English and/or Nepali, drill-down
  from provinces to local levels, and a controller to drive it all.
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

### Zoom, pan and drill-down

Pinch, drag, double-tap and the mouse wheel zoom and pan (`interactive:
false` turns this off; taps still work). Hovering shows a tooltip; on touch,
long-press does.

```dart
final controller = NepalMapController();

Column(children: [
  NepalMapBreadcrumb(controller: controller),     // Nepal › Gandaki Province › Kaski
  Expanded(
    child: NepalMap(controller: controller, drillDown: true),
  ),
]);
```

With `drillDown: true`, tapping a province shows its districts and tapping a
district its local levels. Go back with the breadcrumb, Esc, or
`controller.drillUp()`. To handle Android's back gesture:

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, child) => PopScope(
    canPop: controller.scope == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) controller.drillUp();
    },
    child: child!,
  ),
  child: NepalMap(controller: controller, drillDown: true),
);
```

### Controller

```dart
controller.select(District.kaski);
controller.highlight([LocalLevel.pokhara, LocalLevel.bharatpur]);
controller.zoomTo(Province.koshi);
controller.zoomIn(); controller.zoomOut(); controller.resetView();
controller.language = MapLanguage.ne;   // overrides the widget and locale
controller.selection;                   // ValueListenable<Set<Region>>
```

### Labels

Region names are drawn where they fit, largest regions first, in the active
language. `labelMode: LabelMode.both` shows English with Nepali underneath,
`LabelMode.none` hides them, and `labelBuilder` sets custom text.

### Choropleth maps

```dart
NepalMap(
  level: AdminLevel.district,
  choropleth: Choropleth(
    values: {District.kathmandu: 1744240, District.lalitpur: 548401},
    scale: ColorScale.sequential(Colors.amber.shade50, Colors.deepOrange.shade800),
    title: LocalizedName('Population', 'जनसंख्या'),
  ),
);
```

Scales: `sequential`, `diverging` (with a midpoint), `threshold` (steps) and
`categorical` (one colour per value). Colours are interpolated in OKLab, so
equal steps in value look like equal steps in colour. A legend appears in
the corner, with Devanagari digits and lakh grouping in Nepali
(`१७,४४,२४०`), and tooltips show each region's value. Regions without a value
get the theme's `noDataFill`. Data keyed by code (from a CSV file or an API)
works too: `Choropleth.byCode({'D305': 1744240, ...}, scale: ...)`.

`NepalMapLegend` is also a standalone widget.

### Markers

```dart
NepalMap(
  markers: [
    MapMarker(point: LatLng(27.7043, 85.3070), child: Icon(Icons.place), data: 'ktm'),
    MapMarker.dot(point: LatLng(28.2096, 83.9856), color: Colors.red),  // fast for 1,000s
  ],
  onMarkerTap: (marker) => print(marker.data),
);
```

### Search

```dart
Nepal.search('pokh');        // [LocalLevel.pokhara]
Nepal.search('pokahra');     // typos are fine
Nepal.search('chitawan');    // old spellings too
Nepal.search('कास्की');       // Nepali → [District.kaski]

NepalMapSearchField(controller: controller);  // picks highlight and zoom
```

### Which local level is this point in?

```dart
final data = await NepalMap.preload();
data.localLevelAt(const LatLng(28.2156, 83.9450));  // LocalLevel.pokhara
data.districtAt(point); data.provinceAt(point); data.protectedAreaAt(point);
data.shapeOf(District.kathmandu).areaKm2;           // 415 km² (official: 413)
```

### Protected areas and custom layers

`showProtectedAreas: true` overlays the 10 protected areas outside local
levels, with hatching and labels. For your own drawing, extend `MapLayer`
and pass it in `extraLayers`; see the `MapLayer` docs and
`example/lib/city_glow_layer.dart`.

### Accessibility and keyboard

- Screen readers (TalkBack, VoiceOver) get one node per region on screen,
  read in the active language with its parent and choropleth value
  (e.g. "Kaski District, Gandaki Province, Area: 2,032"), and can select or
  drill into it.
- Keyboard: Tab / Shift-Tab step through regions, arrow keys move to the
  neighbour in that direction, Enter or Space selects (or drills down), Esc
  goes back up, `+` / `-` zoom. The focused region gets a focus ring
  (`NepalMapTheme.focusOutline`) and its tooltip.
- `MediaQuery.disableAnimations` (reduced motion) turns off every animation.

### Export

```dart
final png = await controller.toPngBytes(pixelRatio: 2);  // legend and credit included
final image = await controller.toImage();                // a dart:ui Image
```

### Animations

Drill-down and `zoomTo` fly the camera (`animationDuration`,
`animationCurve`), a fast pan keeps gliding after release, the map fades in
when its data loads, and choropleth colours blend when the values change.

### Selection

`selectionMode` is `single` (default), `multi` or `none`. The map keeps its
own selection, or pass `selected` and `onSelectionChanged` to control it.

### Language

By default the map follows the app's locale: Nepali for `ne`, English
otherwise. Set `language` (or `controller.language`) to override it.

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

## License

- **Code:** MIT. See [LICENSE](LICENSE).
- **Map data** (`assets/maps/`, and the region names and codes): CC BY 4.0,
  from OKNP LocalBoundaries. See [DATA_LICENSE.md](DATA_LICENSE.md).

## FAQ

**Nepali labels show boxes or look wrong.** The package doesn't bundle a
font. Android, iOS, macOS and Windows have Devanagari system fonts, and
Flutter web downloads Noto fonts as needed. For the same look everywhere,
set `NepalMapTheme.labelStyle: TextStyle(fontFamily: ...)`, e.g. with
`google_fonts`' Noto Sans Devanagari.

**Some local levels show English names in Nepali mode.** Nepali names of
the 753 local levels are still being added (province, district and type
names are complete). Until then those labels fall back to English.

**Does it work offline / on the web?** Yes. All data is bundled (422 KB), and
there are no network calls. On the web, decoding runs on the main thread
(about 30 ms) since there are no isolates.

**How big is it?** One 422 KB asset (about 146 KB compressed in the app
bundle) and no dependencies besides Flutter.

**Where does the data come from, and can I update it?** OKNP
LocalBoundaries (CC BY 4.0). `tool/build_data.dart` rebuilds everything from
the raw download; see `tool/README.md`.

**How fast is it?** See the benchmark (`flutter test --tags benchmark`):
pan and zoom frames take a few milliseconds of CPU, even at the local level.
