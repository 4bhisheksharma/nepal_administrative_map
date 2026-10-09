import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'test_helpers.dart';

/// Where a pixel moves when the map zooms by [factor] around [focal].
Offset zoomed(Offset pixel, Offset focal, double factor) =>
    focal + (pixel - focal) * factor;

/// Pinches around [center] by [factor].
///
/// Flutter's scale gesture starts measuring once the fingers have moved past
/// a slop distance, so the fingers first spread from [span] to [span] + 60
/// (which starts the gesture), then change by [factor] from there.
Future<void> pinch(
  WidgetTester tester,
  Offset center,
  double span,
  double factor,
) async {
  final a = await tester.startGesture(center - Offset(span / 2, 0), pointer: 1);
  final b = await tester.startGesture(center + Offset(span / 2, 0), pointer: 2);
  await tester.pump();
  final start = span + 60;
  for (final d in [
    start,
    for (var i = 1; i <= 4; i++) start + (start * factor - start) * i / 4,
  ]) {
    await a.moveTo(center - Offset(d / 2, 0));
    await b.moveTo(center + Offset(d / 2, 0));
    await tester.pump();
  }
  await a.up();
  await b.up();
  await tester.pump();
}

/// Drags by [delta] after first moving past the gesture slop.
Future<void> drag(WidgetTester tester, Offset from, Offset delta) async {
  final g = await tester.startGesture(from);
  await g.moveBy(const Offset(-60, 0)); // starts the gesture
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await g.moveBy(delta / 4);
    await tester.pump();
  }
  await g.up();
  await tester.pump();
}

void main() {
  group('zoom and pan', () {
    testWidgets('pinch zooms around the fingers', (tester) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(level: AdminLevel.district, onRegionTap: regions.add),
      );
      final focal = pixelOf(data, durbarSquare, level: AdminLevel.district);
      await pinch(tester, focal, 100, 2);

      // Pokhara is far from the focal point, so it only lands on Kaski if the
      // map really zoomed by 2 around the fingers.
      final pokhara = zoomed(
        pixelOf(data, phewaLake, level: AdminLevel.district),
        focal,
        2,
      );
      await tapAtTime(tester, pokhara, const Duration(seconds: 1));
      expect(regions, [District.kaski]);
    });

    testWidgets('zooming out stops at minZoom', (tester) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(tester, NepalMap(onRegionTap: regions.add));
      await pinch(tester, const Offset(400, 250), 200, 0.25);
      await tapAtTime(
        tester,
        pixelOf(data, biratnagar),
        const Duration(seconds: 1),
      );
      expect(regions, [
        Province.koshi,
      ], reason: 'the view should not have changed');
    });

    testWidgets('drag pans the map', (tester) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(
          level: AdminLevel.district,
          minZoom: 1,
          onRegionTap: regions.add,
        ),
      );
      // Zoom in first so there is room to pan.
      await pinch(tester, const Offset(400, 250), 100, 3);
      final before = zoomed(
        pixelOf(data, phewaLake, level: AdminLevel.district),
        const Offset(400, 250),
        3,
      );
      await drag(tester, const Offset(400, 250), const Offset(-120, 0));
      await tapAtTime(
        tester,
        before + const Offset(-120, 0),
        const Duration(seconds: 1),
      );
      expect(regions, [District.kaski]);
    });

    testWidgets('mouse wheel zooms around the pointer', (tester) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(level: AdminLevel.district, onRegionTap: regions.add),
      );
      final focal = pixelOf(data, durbarSquare, level: AdminLevel.district);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(focal));
      await tester.sendEventToBinding(
        mouse.scroll(const Offset(0, -240)),
      ); // one notch in = 2x
      await tester.pump();
      final pokhara = zoomed(
        pixelOf(data, phewaLake, level: AdminLevel.district),
        focal,
        2,
      );
      await tapAtTime(tester, pokhara, const Duration(seconds: 1));
      expect(regions, [District.kaski]);
    });

    testWidgets('double tap zooms in', (tester) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(level: AdminLevel.district, onRegionTap: regions.add),
      );
      final focal = pixelOf(data, durbarSquare, level: AdminLevel.district);
      await tapAtTime(tester, focal, Duration.zero);
      await tapAtTime(tester, focal, const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(regions, [
        District.kathmandu,
      ], reason: 'the second tap zooms instead of tapping');

      final pokhara = zoomed(
        pixelOf(data, phewaLake, level: AdminLevel.district),
        focal,
        2,
      );
      await tapAtTime(tester, pokhara, const Duration(seconds: 2));
      expect(regions.last, District.kaski);
    });

    testWidgets('interactive: false ignores drags but still taps', (
      tester,
    ) async {
      final data = await loadData(tester);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(interactive: false, onRegionTap: regions.add),
      );
      await pinch(tester, const Offset(400, 250), 100, 300);
      await tapAtTime(
        tester,
        pixelOf(data, biratnagar),
        const Duration(seconds: 1),
      );
      expect(regions, [Province.koshi]);
    });
  });

  group('hover and tooltips', () {
    testWidgets('hover reports the region and shows a tooltip', (tester) async {
      final data = await loadData(tester);
      final hovered = <Region?>[];
      await pumpMap(tester, NepalMap(onRegionHover: hovered.add));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 495));
      addTearDown(mouse.removePointer);

      await mouse.moveTo(pixelOf(data, durbarSquare));
      await tester.pump();
      expect(hovered, [Province.bagmati]);
      expect(find.text('Bagmati Province'), findsOneWidget);

      await mouse.moveTo(const Offset(5, 495)); // India
      await tester.pump();
      expect(hovered, [Province.bagmati, null]);
      expect(find.text('Bagmati Province'), findsNothing);
    });

    testWidgets('long press shows a tooltip in the active language', (
      tester,
    ) async {
      final data = await loadData(tester);
      await pumpMap(
        tester,
        const NepalMap(level: AdminLevel.district, language: MapLanguage.ne),
      );
      await tester.longPressAt(
        pixelOf(data, phewaLake, level: AdminLevel.district),
      );
      await tester.pump();
      expect(find.text('कास्की जिल्ला'), findsOneWidget);
      expect(find.text('गण्डकी प्रदेश'), findsOneWidget);
    });

    testWidgets('tooltipBuilder replaces the default', (tester) async {
      final data = await loadData(tester);
      await pumpMap(
        tester,
        NepalMap(
          tooltipBuilder: (context, region, lang) =>
              Text('custom ${region.code}'),
        ),
      );
      await tester.longPressAt(pixelOf(data, durbarSquare));
      await tester.pump();
      expect(find.text('custom P3'), findsOneWidget);
    });
  });

  group('labels', () {
    test('LabelMode.textOf', () {
      expect(LabelMode.en.textOf(District.kaski), 'Kaski');
      expect(LabelMode.ne.textOf(District.kaski), 'कास्की');
      expect(LabelMode.both.textOf(District.kaski), 'Kaski\nकास्की');
      expect(LabelMode.none.textOf(District.kaski), isNull);
    });

    testWidgets('labelBuilder receives the active language', (tester) async {
      final calls = <MapLanguage>{};
      await pumpMap(
        tester,
        NepalMap(
          language: MapLanguage.ne,
          labelBuilder: (region, lang) {
            calls.add(lang);
            return null;
          },
        ),
      );
      expect(calls, {MapLanguage.ne});
    });

    testWidgets('switching language relays out labels but reuses paths', (
      tester,
    ) async {
      final data = await loadData(tester);
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await pumpMap(
        tester,
        NepalMap(controller: controller, level: AdminLevel.district),
      );
      final paths = GeometryCache.of(data).pathCount;
      controller.language = MapLanguage.ne;
      await tester.pump();
      expect(find.bySemanticsLabel('नेपाल'), findsOneWidget);
      expect(GeometryCache.of(data).pathCount, paths);
    });
  });

  group('drill-down', () {
    testWidgets('province → district → local level → back', (tester) async {
      final data = await loadData(tester);
      final scopes = <Region?>[];
      final selections = <Set<Region>>[];
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await pumpMap(
        tester,
        NepalMap(
          controller: controller,
          drillDown: true,
          onScopeChanged: scopes.add,
          onSelectionChanged: selections.add,
        ),
      );

      await tapAtTime(tester, pixelOf(data, durbarSquare), Duration.zero);
      await tester.pumpAndSettle();
      expect(scopes, [Province.bagmati]);
      expect(controller.level, AdminLevel.district);

      await tapAtTime(
        tester,
        pixelOf(
          data,
          durbarSquare,
          level: AdminLevel.district,
          scope: Province.bagmati,
        ),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(scopes.last, District.kathmandu);
      expect(selections, isEmpty, reason: 'drilling taps do not select');

      await tapAtTime(
        tester,
        pixelOf(
          data,
          durbarSquare,
          level: AdminLevel.localLevel,
          scope: District.kathmandu,
        ),
        const Duration(seconds: 2),
      );
      expect(selections, [
        {LocalLevel.kathmandu},
      ]);

      controller.drillUp().ignore();
      await tester.pumpAndSettle();
      expect(scopes.last, Province.bagmati);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(scopes.last, isNull);
      expect(controller.level, AdminLevel.province);
    });

    testWidgets('breadcrumb follows the controller in both languages', (
      tester,
    ) async {
      await loadData(tester);
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: [
                NepalMapBreadcrumb(controller: controller),
                Expanded(
                  child: NepalMap(controller: controller, drillDown: true),
                ),
              ],
            ),
          ),
        ),
      );
      await settleData(tester);
      expect(find.text('Nepal'), findsOneWidget);

      controller.drillTo(District.kaski).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Gandaki Province'), findsOneWidget);
      expect(find.text('Kaski'), findsOneWidget);

      controller.language = MapLanguage.ne;
      await tester.pump();
      expect(find.text('नेपाल'), findsOneWidget);
      expect(find.text('गण्डकी प्रदेश'), findsOneWidget);
      expect(find.text('कास्की'), findsOneWidget);

      await tester.tap(find.text('नेपाल'));
      await tester.pumpAndSettle();
      expect(controller.scope, isNull);
      expect(find.text('कास्की'), findsNothing);
    });
  });

  group('controller', () {
    testWidgets('select, highlight and clear reach the style builder', (
      tester,
    ) async {
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      final states = <Region, RegionState>{};
      await pumpMap(
        tester,
        NepalMap(
          controller: controller,
          style: (region, state) {
            states[region] = state;
            return const RegionStyle(fill: Colors.grey);
          },
        ),
      );
      controller
        ..select(Province.koshi)
        ..highlight([Province.karnali]);
      await tester.pump();
      expect(states[Province.koshi]!.isSelected, isTrue);
      expect(states[Province.karnali]!.isHighlighted, isTrue);
      expect(controller.selection.value, {Province.koshi});

      controller
        ..clearSelection()
        ..clearHighlight();
      await tester.pump();
      expect(states[Province.koshi]!.isSelected, isFalse);
      expect(states[Province.karnali]!.isHighlighted, isFalse);
    });

    testWidgets('taps update the controller selection', (tester) async {
      final data = await loadData(tester);
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await pumpMap(tester, NepalMap(controller: controller));
      await tapAtTime(tester, pixelOf(data, biratnagar), Duration.zero);
      expect(controller.selection.value, {Province.koshi});
    });

    testWidgets('zoomTo centres the region', (tester) async {
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      final regions = <Region>[];
      await pumpMap(
        tester,
        NepalMap(
          controller: controller,
          level: AdminLevel.district,
          onRegionTap: regions.add,
        ),
      );
      controller.zoomTo(District.kathmandu).ignore();
      await tester.pumpAndSettle();
      await tapAtTime(
        tester,
        const Offset(400, 250),
        const Duration(seconds: 1),
      );
      expect(regions, [District.kathmandu]);
    });

    testWidgets('language overrides the widget and the locale', (tester) async {
      final controller = NepalMapController(language: MapLanguage.ne);
      addTearDown(controller.dispose);
      await pumpMap(
        tester,
        NepalMap(controller: controller, language: MapLanguage.en),
      );
      expect(find.bySemanticsLabel('नेपाल'), findsOneWidget);
    });

    testWidgets('a replaced map hands its controller to the new one', (
      tester,
    ) async {
      await loadData(tester);
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      Widget app(Key key) => MaterialApp(
        home: NepalMap(key: key, controller: controller),
      );
      await tester.pumpWidget(app(const ValueKey(1)));
      await tester.pumpWidget(app(const ValueKey(2)));
      expect(tester.takeException(), isNull);
      expect(controller.isAttached, isTrue);
    });

    testWidgets('one controller cannot drive two maps', (tester) async {
      await loadData(tester);
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(child: NepalMap(controller: controller)),
              Expanded(child: NepalMap(controller: controller)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });
}
