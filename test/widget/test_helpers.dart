import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

const mapSize = Size(800, 500);

/// Loads the bundled data outside the fake-async zone.
Future<NepalMapData> loadData(WidgetTester tester) async => (await tester
    .runAsync(() => NepalMapData.load(const AssetMapDataSource())))!;

/// Pumps [map] at [mapSize] in the top-left corner and waits for it to load.
Future<void> pumpMap(
  WidgetTester tester,
  Widget map, {
  ThemeData? theme,
  Locale? locale,
}) async {
  await loadData(tester);
  Widget child = Align(
    alignment: Alignment.topLeft,
    child: SizedBox.fromSize(size: mapSize, child: map),
  );
  if (locale != null) {
    child = Builder(
      builder: (context) =>
          Localizations.override(context: context, locale: locale, child: map),
    );
    child = Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: mapSize, child: child),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Material(child: child),
    ),
  );
  await settleData(tester);
}

/// The data future completes in the real zone, so let real time pass once.
Future<void> settleData(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // fade-in
}

/// Where [point] is drawn on a map at [mapSize] with the default padding.
Offset pixelOf(
  NepalMapData data,
  LatLng point, {
  AdminLevel level = AdminLevel.province,
  Region? scope,
}) {
  final cache = GeometryCache.of(data);
  final transform = ViewTransform.fit(
    cache.contentRect((level: level, scope: scope)),
    mapSize,
    const EdgeInsets.all(8),
  );
  return transform.toScreen(cache.plane.project(point));
}

const durbarSquare = LatLng(27.7043, 85.3070); // Kathmandu
const phewaLake = LatLng(28.2156, 83.9450); // Pokhara, Kaski
const biratnagar = LatLng(26.4525, 87.2718); // Koshi

/// Taps at [position] with pointer time stamp [at]. Taps closer together
/// than 300 ms at the same spot count as a double tap (zoom).
Future<void> tapAtTime(
  WidgetTester tester,
  Offset position,
  Duration at,
) async {
  final gesture = await tester.createGesture();
  await gesture.down(position, timeStamp: at);
  await gesture.up(timeStamp: at + const Duration(milliseconds: 50));
  await tester.pump();
}
