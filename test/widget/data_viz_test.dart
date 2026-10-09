import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'test_helpers.dart';

const population = LocalizedName('Population', 'जनसंख्या');

Choropleth sample({ColorScale? scale}) => Choropleth(
  values: const {District.kathmandu: 1744240, District.kaski: 600000},
  scale: scale ?? const ColorScale.sequential(Colors.yellow, Colors.red),
  title: population,
);

void main() {
  group('choropleth', () {
    testWidgets('values reach the style builder', (tester) async {
      final values = <Region, Object?>{};
      await pumpMap(
        tester,
        NepalMap(
          level: AdminLevel.district,
          choropleth: sample(),
          style: (region, state) {
            values[region] = state.value;
            return const RegionStyle(fill: Colors.grey);
          },
        ),
      );
      expect(values[District.kathmandu], 1744240);
      expect(values[District.kaski], 600000);
      expect(values[District.jhapa], isNull);
    });

    test('default style uses the scale and the no-data fill', () {
      final theme = NepalMapTheme.fromColorScheme(const ColorScheme.light());
      final style = sample().defaultStyle(theme);
      expect(
        style(District.kaski, const RegionState(value: 600000)).fill,
        Colors.yellow,
      );
      expect(
        style(District.kathmandu, const RegionState(value: 1744240)).fill,
        Colors.red,
      );
      expect(style(District.jhapa, const RegionState()).fill, theme.noDataFill);
      expect(
        style(
          District.kaski,
          const RegionState(value: 600000, isSelected: true),
        ).outline,
        theme.selectedOutline,
      );
    });

    testWidgets('legend in Nepali uses Devanagari digits and lakh grouping', (
      tester,
    ) async {
      await pumpMap(
        tester,
        NepalMap(
          level: AdminLevel.district,
          choropleth: sample(),
          language: MapLanguage.ne,
        ),
      );
      expect(find.text('जनसंख्या'), findsOneWidget);
      expect(find.text('६,००,०००'), findsOneWidget);
      expect(find.text('१७,४४,२४०'), findsOneWidget);
      expect(
        find.text('डाटा उपलब्ध छैन'),
        findsOneWidget,
        reason: 'most districts have no value',
      );
    });

    testWidgets('legend in English', (tester) async {
      await pumpMap(
        tester,
        NepalMap(level: AdminLevel.district, choropleth: sample()),
      );
      expect(find.text('Population'), findsOneWidget);
      expect(find.text('600,000'), findsOneWidget);
      expect(find.text('1,744,240'), findsOneWidget);
    });

    testWidgets('tooltip shows the formatted value', (tester) async {
      final data = await loadData(tester);
      await pumpMap(
        tester,
        NepalMap(level: AdminLevel.district, choropleth: sample()),
      );
      await tester.longPressAt(
        pixelOf(data, durbarSquare, level: AdminLevel.district),
      );
      await tester.pump();
      expect(find.text('Population: 1,744,240'), findsOneWidget);
    });

    testWidgets('legend can be hidden', (tester) async {
      await pumpMap(
        tester,
        const NepalMap(
          level: AdminLevel.district,
          choropleth: Choropleth(
            values: {District.kaski: 1},
            scale: ColorScale.sequential(Colors.white, Colors.black),
            showLegend: false,
          ),
        ),
      );
      expect(find.byType(NepalMapLegend), findsNothing);
    });

    test('byCode joins codes and rejects unknown ones', () {
      final c = Choropleth.byCode(const {
        'D305': 1,
        'P1': 2,
      }, scale: const ColorScale.sequential(Colors.white, Colors.black));
      expect(c.values, {District.kathmandu: 1, Province.koshi: 2});
      expect(
        () => Choropleth.byCode(const {
          'X99': 1,
        }, scale: const ColorScale.sequential(Colors.white, Colors.black)),
        throwsAssertionError,
      );
    });
  });

  group('legend', () {
    Future<void> pumpLegend(WidgetTester tester, Widget legend) =>
        tester.pumpWidget(
          MaterialApp(
            home: Material(child: Center(child: legend)),
          ),
        );

    testWidgets('threshold ranges', (tester) async {
      await pumpLegend(
        tester,
        NepalMapLegend(
          scale: ColorScale.threshold(
            [10, 50],
            [Colors.green, Colors.yellow, Colors.red],
          ),
        ),
      );
      expect(find.text('< 10'), findsOneWidget);
      expect(find.text('10 – 50'), findsOneWidget);
      expect(find.text('≥ 50'), findsOneWidget);
    });

    testWidgets('categorical labels in the active language', (tester) async {
      await pumpLegend(
        tester,
        const NepalMapLegend(
          language: MapLanguage.ne,
          scale: ColorScale.categorical(
            {'urban': Colors.blue, 'rural': Colors.green},
            labels: {
              'urban': LocalizedName('Urban', 'शहरी'),
              'rural': LocalizedName('Rural', 'ग्रामीण'),
            },
          ),
        ),
      );
      expect(find.text('शहरी'), findsOneWidget);
      expect(find.text('ग्रामीण'), findsOneWidget);
    });

    testWidgets('diverging shows the midpoint', (tester) async {
      await pumpLegend(
        tester,
        const NepalMapLegend(
          scale: ColorScale.diverging(
            Colors.blue,
            Colors.white,
            Colors.red,
            midpoint: 0,
          ),
          extent: (min: -10, max: 30),
        ),
      );
      expect(find.text('-10'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });
  });

  group('markers', () {
    testWidgets('widget marker taps report the marker', (tester) async {
      final tapped = <MapMarker>[];
      await pumpMap(
        tester,
        NepalMap(
          markers: const [
            MapMarker(
              point: durbarSquare,
              child: Icon(Icons.place, key: Key('ktm')),
              data: 'ktm',
            ),
          ],
          onMarkerTap: tapped.add,
        ),
      );
      await tester.tap(find.byKey(const Key('ktm')));
      expect(tapped.single.data, 'ktm');
    });

    testWidgets('dot marker taps work after zooming and win over regions', (
      tester,
    ) async {
      final data = await loadData(tester);
      final markers = <MapMarker>[];
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(
          markers: const [
            MapMarker.dot(point: phewaLake, data: 'pokhara'),
            MapMarker.dot(point: biratnagar, data: 'brt'),
          ],
          onMarkerTap: markers.add,
          onRegionTap: regions.add,
        ),
      );
      final focal = pixelOf(data, durbarSquare);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(focal));
      await tester.sendEventToBinding(
        mouse.scroll(const Offset(0, -240)),
      ); // zoom 2x
      await tester.pump();

      final pokhara = focal + (pixelOf(data, phewaLake) - focal) * 2;
      await tapAtTime(
        tester,
        pokhara + const Offset(3, 2),
        const Duration(seconds: 1),
      );
      expect(markers.single.data, 'pokhara');
      expect(regions, isEmpty);
    });

    testWidgets('off-screen widget markers are not built', (tester) async {
      await pumpMap(
        tester,
        const NepalMap(
          scope: Province.koshi,
          level: AdminLevel.district,
          markers: [
            MapMarker(
              point: LatLng(28.96, 80.18),
              child: SizedBox(key: Key('far')),
            ),
          ],
        ),
      );
      expect(find.byKey(const Key('far')), findsNothing);
    });
  });

  testWidgets('protected-area overlay adds a layer', (tester) async {
    Finder paints() => find.descendant(
      of: find.byType(NepalMap),
      matching: find.byType(CustomPaint),
    );
    await pumpMap(tester, const NepalMap(key: Key('a')));
    final before = paints().evaluate().length;
    await pumpMap(
      tester,
      const NepalMap(key: Key('b'), showProtectedAreas: true),
    );
    expect(paints().evaluate().length, before + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extra layers are painted', (tester) async {
    final layer = _CountingLayer();
    await pumpMap(tester, NepalMap(extraLayers: [layer]));
    expect(layer.paints, greaterThan(0));
  });

  testWidgets(
    'search field suggests in the active language and zooms on select',
    (tester) async {
      await loadData(tester);
      final controller = NepalMapController(language: MapLanguage.en);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: [
                NepalMapSearchField(controller: controller),
                Expanded(
                  child: NepalMap(
                    controller: controller,
                    level: AdminLevel.localLevel,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await settleData(tester);
      await tester.enterText(find.byType(TextField), 'pokh');
      await tester.pumpAndSettle();
      expect(find.text('Pokhara Metropolitan City'), findsOneWidget);
      expect(find.text('Kaski District, Gandaki Province'), findsOneWidget);
      await tester.tap(find.text('Pokhara Metropolitan City'));
      await tester.pumpAndSettle();
      expect(controller.highlighted.value, {LocalLevel.pokhara});
    },
  );

  testWidgets('preload returns the data for point lookups', (tester) async {
    final data = await tester.runAsync(NepalMap.preload);
    expect(data!.localLevelAt(phewaLake), LocalLevel.pokhara);
  });
}

class _CountingLayer extends MapLayer {
  int paints = 0;

  @override
  void paint(Canvas canvas, MapPaintContext context) => paints++;

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) => false;
}
