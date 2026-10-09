@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/nepal_administrative_map.dart';

import '../widget/test_helpers.dart';

// Golden images differ slightly between operating systems (anti-aliasing),
// so these run locally only: `flutter test --tags golden`. Regenerate with
// `flutter test --tags golden --update-goldens`.
void main() {
  for (final brightness in Brightness.values) {
    for (final level in AdminLevel.values) {
      testWidgets('${level.name} ${brightness.name}', (tester) async {
        await pumpMap(
          tester,
          RepaintBoundary(
            child: ColoredBox(
              color: brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              child: NepalMap(
                level: level,
                showAttribution: false,
                selected: {_selected[level]!},
              ),
            ),
          ),
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: brightness,
          ),
        );
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('images/${level.name}_${brightness.name}.png'),
        );
      });
    }
  }

  testWidgets('scope gandaki', (tester) async {
    await pumpMap(
      tester,
      const RepaintBoundary(
        child: ColoredBox(
          color: Colors.white,
          child: NepalMap(
            level: AdminLevel.localLevel,
            scope: Province.gandaki,
            showAttribution: false,
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('images/scope_gandaki.png'),
    );
  });
}

const _selected = <AdminLevel, Region>{
  AdminLevel.province: Province.bagmati,
  AdminLevel.district: District.kaski,
  AdminLevel.localLevel: LocalLevel.pokhara,
};
