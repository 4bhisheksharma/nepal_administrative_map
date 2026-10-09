import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nepal_administrative_map/core.dart';

void main() {
  group('Nepal.search', () {
    test('prefix, full name and case-insensitive', () {
      expect(Nepal.search('pokh').first, LocalLevel.pokhara);
      expect(Nepal.search('Pokhara').first, LocalLevel.pokhara);
      expect(Nepal.search('POKHARA metro').first, LocalLevel.pokhara);
    });

    test('typos', () {
      expect(Nepal.search('pokahra').first, LocalLevel.pokhara);
      expect(Nepal.search('biratnagr').first, LocalLevel.biratnagar);
    });

    test('old spellings via aliases', () {
      expect(Nepal.search('Pokhara Lekhnath').first, LocalLevel.pokhara);
      expect(Nepal.search('chitawan').first, District.chitwan);
      expect(Nepal.search('Sudurpaschim').first, Province.sudurpashchim);
    });

    test('exact names rank larger regions first', () {
      final results = Nepal.search('Kathmandu');
      expect(results.take(2), [District.kathmandu, LocalLevel.kathmandu]);
    });

    test('Devanagari input matches Nepali names', () {
      expect(Nepal.search('कास्की').first, District.kaski);
      expect(Nepal.search('कास').first, District.kaski);
      expect(Nepal.search('गण्डकी').first, Province.gandaki);
      // चँ/चं spelling variants compare equal.
      expect(Nepal.search('काठमाडौँ').first, District.kathmandu);
    });

    test('levels and limit', () {
      expect(
        Nepal.search('kathmandu', levels: {AdminLevel.localLevel}).first,
        LocalLevel.kathmandu,
      );
      expect(Nepal.search('a', limit: 3), hasLength(3));
      expect(Nepal.search(''), isEmpty);
      expect(Nepal.search('zzzzzz'), isEmpty);
    });

    test('protected areas are not regions', () {
      expect(
        Nepal.search('Chitwan National Park').whereType<Region>(),
        isNot(contains(isA<ProtectedArea>())),
      );
    });

    test('1,000 queries average under 2 ms', () {
      final names = [for (final r in LocalLevel.values) r.name.en];
      final random = math.Random(1);
      Nepal.search('warm up');
      final watch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final name = names[random.nextInt(names.length)];
        Nepal.search(
          name.substring(0, math.min(name.length, 1 + random.nextInt(8))),
        );
      }
      final avgMs = watch.elapsedMicroseconds / 1000 / 1000;
      expect(
        avgMs,
        lessThan(2),
        reason: 'average ${avgMs.toStringAsFixed(3)} ms',
      );
    });
  });
}
