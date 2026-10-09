import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('NepalMap() loads and draws its layers', (tester) async {
    await pumpMap(tester, const NepalMap());
    expect(
      find.descendant(
        of: find.byType(NepalMap),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(5), // 4 layers + the screen-reader painter
    );
    expect(find.bySemanticsLabel('Nepal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the placeholder until the data loads', (tester) async {
    final source = MapDataSource.callback(
      'never',
      () => Completer<String>().future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NepalMap(
          dataSource: source,
          placeholder: (_) => const Text('Loading'),
        ),
      ),
    );
    expect(find.text('Loading'), findsOneWidget);
  });

  testWidgets('shows the error builder when loading fails', (tester) async {
    final source = MapDataSource.callback('broken', () async => 'not json');
    await tester.pumpWidget(
      MaterialApp(
        home: NepalMap(
          dataSource: source,
          errorBuilder: (_, e) => const Text('Failed'),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settleData(tester);
    expect(find.text('Failed'), findsOneWidget);
  });

  group('tapping', () {
    testWidgets('reports the region under the pointer at each level', (
      tester,
    ) async {
      final data = await loadData(tester);
      for (final (level, expected) in [
        (AdminLevel.province, Province.bagmati),
        (AdminLevel.district, District.kathmandu),
        (AdminLevel.localLevel, LocalLevel.kathmandu),
      ]) {
        Region? tapped;
        await pumpMap(
          tester,
          NepalMap(
            key: ValueKey(level),
            level: level,
            onRegionTap: (r) => tapped = r,
          ),
        );
        await tester.tapAt(pixelOf(data, durbarSquare, level: level));
        expect(tapped, expected, reason: '$level');
      }
    });

    testWidgets('outside Nepal reports nothing', (tester) async {
      Region? tapped;
      await pumpMap(tester, NepalMap(onRegionTap: (r) => tapped = r));
      await tester.tapAt(const Offset(790, 490)); // bottom-right corner: India
      expect(tapped, isNull);
    });

    testWidgets('scope limits hit-testing to the scope', (tester) async {
      final data = await loadData(tester);
      final tapped = <Region>[];
      await pumpMap(
        tester,
        NepalMap(
          level: AdminLevel.district,
          scope: Province.gandaki,
          onRegionTap: tapped.add,
        ),
      );
      await tester.tapAt(
        pixelOf(
          data,
          phewaLake,
          level: AdminLevel.district,
          scope: Province.gandaki,
        ),
      );
      await tester.tapAt(
        pixelOf(
          data,
          durbarSquare,
          level: AdminLevel.district,
          scope: Province.gandaki,
        ),
      );
      expect(tapped, [District.kaski]);
    });
  });

  group('selection', () {
    testWidgets('single: tap selects, tapping again deselects', (tester) async {
      final data = await loadData(tester);
      final changes = <Set<Region>>[];
      await pumpMap(tester, NepalMap(onSelectionChanged: changes.add));
      final ktm = pixelOf(data, durbarSquare);
      final koshi = pixelOf(data, biratnagar);
      await tapAtTime(tester, ktm, Duration.zero);
      await tapAtTime(tester, koshi, const Duration(seconds: 1));
      await tapAtTime(tester, koshi, const Duration(seconds: 2));
      expect(changes, [
        {Province.bagmati},
        {Province.koshi},
        <Region>{},
      ]);
    });

    testWidgets('multi: taps toggle', (tester) async {
      final data = await loadData(tester);
      final changes = <Set<Region>>[];
      await pumpMap(
        tester,
        NepalMap(
          selectionMode: SelectionMode.multi,
          onSelectionChanged: changes.add,
        ),
      );
      await tester.tapAt(pixelOf(data, durbarSquare));
      await tester.tapAt(pixelOf(data, biratnagar));
      await tester.tapAt(pixelOf(data, durbarSquare));
      expect(changes.last, {Province.koshi});
      expect(changes[1], {Province.bagmati, Province.koshi});
    });

    testWidgets('none: taps report but never select', (tester) async {
      final data = await loadData(tester);
      final tapped = <Region>[];
      final changes = <Set<Region>>[];
      await pumpMap(
        tester,
        NepalMap(
          selectionMode: SelectionMode.none,
          onRegionTap: tapped.add,
          onSelectionChanged: changes.add,
        ),
      );
      await tester.tapAt(pixelOf(data, durbarSquare));
      expect(tapped, [Province.bagmati]);
      expect(changes, isEmpty);
    });

    testWidgets('controlled: the map shows `selected` and reports changes', (
      tester,
    ) async {
      final data = await loadData(tester);
      final states = <RegionState>[];
      final changes = <Set<Region>>[];
      await pumpMap(
        tester,
        NepalMap(
          selected: const {Province.koshi},
          onSelectionChanged: changes.add,
          style: (region, state) {
            if (region == Province.koshi) states.add(state);
            return RegionStyle(
              fill: state.isSelected ? Colors.red : Colors.grey,
            );
          },
        ),
      );
      expect(states.last.isSelected, isTrue);
      await tester.tapAt(pixelOf(data, durbarSquare));
      await tester.pump();
      expect(changes, [
        {Province.bagmati},
      ]);
      expect(
        states.last.isSelected,
        isTrue,
        reason: 'parent did not update `selected`',
      );
    });
  });

  group('language', () {
    testWidgets('follows a Nepali app locale', (tester) async {
      await pumpMap(tester, const NepalMap(), locale: const Locale('ne'));
      expect(find.bySemanticsLabel('नेपाल'), findsOneWidget);
    });

    testWidgets('`language` overrides the locale', (tester) async {
      await pumpMap(
        tester,
        const NepalMap(language: MapLanguage.en),
        locale: const Locale('ne'),
      );
      expect(find.bySemanticsLabel('Nepal'), findsOneWidget);
    });

    testWidgets('scope is named in the active language', (tester) async {
      await pumpMap(
        tester,
        const NepalMap(
          level: AdminLevel.district,
          scope: Province.gandaki,
          language: MapLanguage.ne,
        ),
      );
      expect(find.bySemanticsLabel('गण्डकी प्रदेश'), findsOneWidget);
    });
  });

  group('attribution', () {
    testWidgets('shown by default and tappable', (tester) async {
      var taps = 0;
      await pumpMap(tester, NepalMap(onAttributionTap: () => taps++));
      await tester.tap(find.text(NepalMap.attribution));
      expect(taps, 1);
    });

    testWidgets('can be hidden', (tester) async {
      await pumpMap(tester, const NepalMap(showAttribution: false));
      expect(find.text(NepalMap.attribution), findsNothing);
    });
  });

  testWidgets('keeps Nepal\'s aspect ratio when the height is unbounded', (
    tester,
  ) async {
    await loadData(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(width: 800, child: Column(children: [NepalMap()])),
        ),
      ),
    );
    await settleData(tester);
    final size = tester.getSize(find.byType(NepalMap));
    expect(size.width, 800);
    expect(size.width / size.height, closeTo(1.74, 0.1));
  });

  testWidgets('theme comes from ThemeData.extensions', (tester) async {
    final colors = <Color>[];
    final theme = NepalMapTheme.fromColorScheme(const ColorScheme.light())
        .copyWith(regionFill: Colors.teal);
    await pumpMap(
      tester,
      Builder(
        builder: (context) {
          colors.add(NepalMapTheme.of(context).regionFill);
          return const NepalMap();
        },
      ),
      theme: ThemeData(extensions: [theme]),
    );
    expect(colors.last, Colors.teal);
  });
}
