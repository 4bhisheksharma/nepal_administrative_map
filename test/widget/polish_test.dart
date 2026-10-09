import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'test_helpers.dart';

void main() {
  group('accessibility', () {
    testWidgets('each region is a screen-reader node in the active language', (
      tester,
    ) async {
      await pumpMap(tester, const NepalMap(language: MapLanguage.ne));
      expect(find.semantics.byLabel('गण्डकी प्रदेश'), findsOne);
      expect(find.semantics.byLabel('कोशी प्रदेश'), findsOne);
    });

    testWidgets('nodes include the parent and the choropleth value', (
      tester,
    ) async {
      await pumpMap(
        tester,
        const NepalMap(
          level: AdminLevel.district,
          choropleth: Choropleth(
            values: {District.kaski: 2000},
            scale: ColorScale.sequential(Colors.white, Colors.black),
            title: LocalizedName('Area', 'क्षेत्रफल'),
          ),
        ),
      );
      expect(
        find.semantics.byLabel('Kaski District, Gandaki Province, Area: 2,000'),
        findsOne,
      );
    });

    testWidgets('the screen reader can select a region', (tester) async {
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      await pumpMap(tester, NepalMap(controller: controller));
      tester.semantics.tap(find.semantics.byLabel('Koshi Province'));
      await tester.pump();
      expect(controller.selection.value, {Province.koshi});
      expect(
        find.semantics
            .byLabel('Koshi Province')
            .evaluate()
            .single
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });
  });

  group('keyboard', () {
    Future<NepalMapController> focusMap(
      WidgetTester tester, {
      bool drillDown = false,
    }) async {
      final controller = NepalMapController();
      addTearDown(controller.dispose);
      final states = <Region, RegionState>{};
      await pumpMap(
        tester,
        NepalMap(
          controller: controller,
          drillDown: drillDown,
          style: (region, state) {
            states[region] = state;
            return RegionStyle(
              fill: Colors.grey,
              outline: state.isFocused ? Colors.black : null,
            );
          },
        ),
      );
      // Focus the map the way a keyboard user would.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      return controller;
    }

    testWidgets('Tab steps through regions and Enter selects', (tester) async {
      final controller = await focusMap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // first province
      await tester.pump();
      expect(
        find.text('Koshi Province'),
        findsOneWidget,
        reason: 'tooltip follows focus',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.text('Madhesh Province'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.selection.value, {Province.madhesh});
    });

    testWidgets('arrow keys move to the neighbour in that direction', (
      tester,
    ) async {
      await focusMap(tester);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.tab,
      ); // Koshi, the easternmost
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        find.text('Koshi Province'),
        findsOneWidget,
        reason: 'nothing further east',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        find.text('Madhesh Province'),
        findsOneWidget,
        reason: 'directly west of Koshi',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('Koshi Province'), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      }
      await tester.pump();
      expect(
        find.text('Sudurpashchim Province'),
        findsOneWidget,
        reason: 'the westernmost',
      );
    });

    testWidgets('Enter drills down and Esc comes back', (tester) async {
      final controller = await focusMap(tester, drillDown: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.scope, Province.koshi);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.scope, isNull);
    });

    testWidgets('focus ring only while using the keyboard', (tester) async {
      final states = <Region, RegionState>{};
      await pumpMap(
        tester,
        NepalMap(
          style: (region, state) {
            states[region] = state;
            return const RegionStyle(fill: Colors.grey);
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(states[Province.koshi]!.isFocused, isTrue);

      // A touch switches Flutter to touch mode, which hides the ring.
      await tester.tapAt(const Offset(5, 495));
      await tester.pump();
      expect(states[Province.koshi]!.isFocused, isFalse);
    });
  });

  testWidgets('export renders the map to PNG', (tester) async {
    final controller = NepalMapController();
    addTearDown(controller.dispose);
    await pumpMap(tester, NepalMap(controller: controller));
    final png = await tester.runAsync(
      () => controller.toPngBytes(pixelRatio: 0.5),
    );
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    expect(png.length, greaterThan(1000));
  });

  test('export without a map is a StateError', () {
    final controller = NepalMapController();
    addTearDown(controller.dispose);
    expect(controller.toImage, throwsStateError);
  });

  testWidgets('a fling keeps gliding after release', (tester) async {
    final data = await loadData(tester);
    final regions = <Region>[];
    await pumpMap(
      tester,
      NepalMap(level: AdminLevel.district, onRegionTap: regions.add),
    );
    // Zoom in so there's room to move, then fling left.
    final focal = pixelOf(data, durbarSquare, level: AdminLevel.district);
    await tapAtTime(tester, focal, Duration.zero);
    await tapAtTime(tester, focal, const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final before =
        focal +
        (pixelOf(data, phewaLake, level: AdminLevel.district) - focal) * 2;
    await tester.flingFrom(const Offset(400, 250), const Offset(-100, 0), 2000);
    await tester.pumpAndSettle();
    // A plain 100 px drag would leave Pokhara at before - 100 (minus the slop);
    // the fling carries it much further left.
    await tapAtTime(
      tester,
      before - const Offset(100, 0),
      const Duration(seconds: 5),
    );
    expect(regions.last, isNot(District.kaski));
  });

  testWidgets('choropleth colours transition when the data changes', (
    tester,
  ) async {
    final probe = _FillProbe(District.kaski);
    Widget map(int value) => NepalMap(
      level: AdminLevel.district,
      extraLayers: [probe],
      choropleth: Choropleth(
        values: {District.kaski: value, District.jhapa: 0, District.humla: 100},
        scale: const ColorScale.sequential(
          Color(0xFF000000),
          Color(0xFFFFFFFF),
        ),
      ),
    );
    var value = 0;
    late StateSetter setValue;
    await pumpMap(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setValue = setState;
          return map(value);
        },
      ),
    );
    expect(probe.fills.last, const Color(0xFF000000));

    setValue(() => value = 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final mid = probe.fills.last;
    expect(
      mid.r,
      inExclusiveRange(0.05, 0.95),
      reason: 'halfway between black and white',
    );

    await tester.pumpAndSettle();
    expect(probe.fills.last, const Color(0xFFFFFFFF));
  });

  testWidgets('animationCurve is used for zoom animations', (tester) async {
    final controller = NepalMapController();
    addTearDown(controller.dispose);
    await pumpMap(
      tester,
      NepalMap(controller: controller, animationCurve: Curves.linear),
    );
    controller.zoomIn().ignore();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

/// Records the fill a region gets in each frame.
class _FillProbe extends MapLayer {
  _FillProbe(this.region);

  final Region region;
  final fills = <Color>[];

  @override
  void paint(Canvas canvas, MapPaintContext context) =>
      fills.add(context.styles[region]!.fill);

  @override
  bool needsRepaint(MapPaintContext old, MapPaintContext current) => true;
}
