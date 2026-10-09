# nepal_administrative_map example

A demo of every feature: levels and scopes, drill-down with a breadcrumb,
English / नेपाली, light and dark, bilingual labels, choropleths (area,
number of local levels, local-level types), protected areas, city markers,
a custom map layer, search, zoom buttons, PNG export and the credit line.

Try it in your browser: **[live demo](https://4bhisheksharma.github.io/nepal_administrative_map/)**, or run it locally:

```sh
cd example
flutter run
```

The smallest possible app:

```dart
import 'package:flutter/material.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

void main() => runApp(
      MaterialApp(
        home: Scaffold(
          body: NepalMap(
            level: AdminLevel.district,
            onRegionTap: (region) => debugPrint(region.fullName(MapLanguage.en)),
          ),
        ),
      ),
    );
```

See [`lib/main.dart`](https://github.com/4bhisheksharma/nepal_administrative_map/blob/main/example/lib/main.dart) for the full demo.
