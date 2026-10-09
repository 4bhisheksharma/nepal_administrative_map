# nepal_administrative_map

An interactive administrative map of Nepal for Flutter: 7 provinces,
77 districts and 753 local levels, in English and Nepali.

> **Status: in development.** Not yet published. The data layer and typed
> regions are in place; the map widget is next.

## What works today

```dart
import 'package:nepal_administrative_map/core.dart';

LocalLevel.pokhara.district;            // District.kaski
District.kaski.province;                // Province.gandaki
District.kathmandu.name.ne;             // काठमाडौं
LocalLevel.values.length;               // 753
```

## Data & attribution

Boundary data: **© [OKNP LocalBoundaries](https://localboundries.oknp.org/)**,
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The data has been simplified and extended with codes and Nepali names; see
[DATA_LICENSE.md](DATA_LICENSE.md) for the full list of changes. Apps that
ship this map must credit the data, e.g. in an About screen.
