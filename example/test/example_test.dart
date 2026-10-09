import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';
import 'package:nepal_administrative_map_example/main.dart';

void main() {
  testWidgets('the bundled asset loads when the package is a dependency', (
    tester,
  ) async {
    // The path apps use, not the fallback the package's own tests use.
    final json = await tester.runAsync(
      () => rootBundle.loadString(
        'packages/nepal_administrative_map/assets/maps/nepal.topo.json',
      ),
    );
    expect(json, startsWith('{"type":"Topology"'));
  });

  testWidgets('the example shows the map and reports taps', (tester) async {
    await tester.runAsync(() => NepalMap.preload());
    await tester.pumpWidget(const ExampleApp());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Tap a region'), findsOneWidget);

    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();
    expect(find.text('नेपालको प्रशासनिक नक्सा'), findsOneWidget);
  });
}
