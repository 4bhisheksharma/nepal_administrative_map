@Tags(['benchmark'])
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import '../widget/test_helpers.dart';

// CPU cost of decoding and of building + painting frames, measured in the
// test environment (debug JIT, no GPU). Real devices in profile mode are
// faster; these numbers are for spotting regressions, not absolute budgets.
//
//   flutter test --tags benchmark
void main() {
  test('decode', () {
    final json = File('assets/maps/nepal.topo.json').readAsStringSync();
    final times = [
      for (var i = 0; i < 10; i++)
        (Stopwatch()..start()).let((w) {
          NepalMapData.parse(json);
          return w.elapsedMicroseconds / 1000;
        }),
    ];
    _report('decode (cold, then warm median)', [
      times.first,
      _median(times.skip(1).toList()),
    ]);
  });

  for (final level in AdminLevel.values) {
    testWidgets('frames: ${level.name}', (tester) async {
      final data = await loadData(tester);
      final first = Stopwatch()..start();
      await pumpMap(tester, NepalMap(level: level));
      first.stop();

      final focal = pixelOf(data, durbarSquare, level: level);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(focal));

      // Zoom frames: borders are re-recorded at each new scale.
      final zoom = <double>[];
      for (var i = 0; i < 20; i++) {
        final w = Stopwatch()..start();
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, -24)));
        await tester.pump();
        zoom.add(w.elapsedMicroseconds / 1000);
      }

      // Pan frames: recorded pictures are replayed, only labels repaint.
      final pan = <double>[];
      final gesture = await tester.startGesture(const Offset(400, 250));
      await gesture.moveBy(const Offset(-40, 0));
      for (var i = 0; i < 30; i++) {
        final w = Stopwatch()..start();
        await gesture.moveBy(const Offset(-3, 1));
        await tester.pump();
        pan.add(w.elapsedMicroseconds / 1000);
      }
      await gesture.up();

      // Hover frames: fills re-recorded, borders reused.
      final hover = <double>[];
      for (var i = 0; i < 20; i++) {
        final w = Stopwatch()..start();
        await tester.sendEventToBinding(
          mouse.hover(Offset(200 + i * 20.0, 250)),
        );
        await tester.pump();
        hover.add(w.elapsedMicroseconds / 1000);
      }
      await tester.pumpAndSettle();

      _report('${level.name}: first frame', [first.elapsedMicroseconds / 1000]);
      _report('${level.name}: zoom frame median / max', [
        _median(zoom),
        zoom.reduce((a, b) => a > b ? a : b),
      ]);
      _report('${level.name}: pan frame median / max', [
        _median(pan),
        pan.reduce((a, b) => a > b ? a : b),
      ]);
      _report('${level.name}: hover frame median / max', [
        _median(hover),
        hover.reduce((a, b) => a > b ? a : b),
      ]);
    }, semanticsEnabled: false);
  }

  testWidgets('drill-down cycles keep caches bounded', (tester) async {
    final data = await loadData(tester);
    final controller = NepalMapController();
    addTearDown(controller.dispose);
    await pumpMap(tester, NepalMap(controller: controller, drillDown: true));
    for (var i = 0; i < 3; i++) {
      for (final province in Province.values) {
        controller.drillTo(province).ignore();
        await tester.pumpAndSettle();
        controller.drillTo(province.districts.first).ignore();
        await tester.pumpAndSettle();
        controller.drillTo(null).ignore();
        await tester.pumpAndSettle();
      }
    }
    final cache = GeometryCache.of(data);
    // Paths are built once per region; repeated cycles don't add more.
    expect(cache.pathCount, lessThanOrEqualTo(7 + 77 + 753));
    _report('paths cached after 3 drill cycles', [cache.pathCount.toDouble()]);
  });
}

double _median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

void _report(String name, List<double> values) =>
    // ignore: avoid_print
    print(
      'BENCH $name: ${values.map((v) => v.toStringAsFixed(1)).join(' / ')}',
    );

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
