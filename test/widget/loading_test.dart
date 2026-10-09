import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import 'test_helpers.dart';

/// A bundle with no assets at all.
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      throw FlutterError('Unable to load asset: "$key".');
}

void main() {
  test(
    'a missing asset reports the path apps use, not the test fallback',
    () async {
      final source = AssetMapDataSource(bundle: _EmptyBundle());
      await expectLater(
        source.load(),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('packages/nepal_administrative_map/'),
          ),
        ),
      );
    },
  );

  testWidgets('a map whose first load fails retries and shows up', (
    tester,
  ) async {
    // Regression: NepalMap.preload() in main() before runApp() failed, the
    // map joined that failed load and stayed blank until it was rebuilt.
    var calls = 0;
    final source = MapDataSource.callback('fails-once', () async {
      if (calls++ == 0) throw const FileSystemException('too early');
      return File('assets/maps/nepal.topo.json').readAsString();
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NepalMap(dataSource: source, showAttribution: false),
      ),
    );
    for (
      var i = 0;
      i < 10 && find.byType(CustomPaint).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 2);
    expect(
      find.descendant(
        of: find.byType(NepalMap),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });

  testWidgets('a map that keeps failing shows the error builder', (
    tester,
  ) async {
    final source = MapDataSource.callback(
      'always-fails',
      () async => throw const FileSystemException('nope'),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NepalMap(
          dataSource: source,
          errorBuilder: (context, error) => const Text('failed'),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('failed'), findsOneWidget);
  });

  testWidgets('preload works before the app starts', (tester) async {
    final data = await tester.runAsync(NepalMap.preload);
    expect(data!.provinces, hasLength(7));
    expect(mapSize, isNotNull);
  });
}
