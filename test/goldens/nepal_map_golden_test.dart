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

  labelGoldens();

  for (final language in MapLanguage.values) {
    testWidgets('choropleth ${language.name}', (tester) async {
      final data = await loadData(tester);
      // District areas, computed from the boundaries.
      final areas = {
        for (final s in data.districts) s.feature as Region: s.areaKm2.round(),
      };
      await pumpMap(
        tester,
        RepaintBoundary(
          child: ColoredBox(
            color: Colors.white,
            child: NepalMap(
              level: AdminLevel.district,
              language: language,
              labelMode: LabelMode.none,
              showAttribution: false,
              choropleth: Choropleth(
                values: areas,
                scale: ColorScale.sequential(
                  Colors.amber.shade50,
                  Colors.deepOrange.shade800,
                ),
                title: const LocalizedName(
                  'Area (km²)',
                  'क्षेत्रफल (वर्ग कि.मी.)',
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('images/choropleth_${language.name}.png'),
      );
    });
  }

  testWidgets('protected areas overlay', (tester) async {
    await pumpMap(
      tester,
      const RepaintBoundary(
        child: ColoredBox(
          color: Colors.white,
          child: NepalMap(
            level: AdminLevel.province,
            showProtectedAreas: true,
            labelMode: LabelMode.none,
            showAttribution: false,
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('images/protected_areas.png'),
    );
  });

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

// Labels render as boxes in tests (the Ahem test font); these goldens check
// placement and collision avoidance, not the glyphs.
void labelGoldens() {
  for (final mode in [LabelMode.en, LabelMode.ne, LabelMode.both]) {
    testWidgets('labels ${mode.name}', (tester) async {
      await pumpMap(
        tester,
        RepaintBoundary(
          child: ColoredBox(
            color: Colors.white,
            child: NepalMap(
              level: AdminLevel.district,
              labelMode: mode,
              showAttribution: false,
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('images/labels_${mode.name}.png'),
      );
    });
  }
}

const _selected = <AdminLevel, Region>{
  AdminLevel.province: Province.bagmati,
  AdminLevel.district: District.kaski,
  AdminLevel.localLevel: LocalLevel.pokhara,
};
