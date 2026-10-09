import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The core layers must stay pure Dart so they run outside Flutter.
void main() {
  test('core layers do not import Flutter', () {
    final offenders = <String>[];
    for (final dir in ['lib/src/i18n', 'lib/src/data', 'lib/src/geometry']) {
      for (final file in Directory(
        dir,
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains("'package:flutter/") ||
            source.contains("'dart:ui'")) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
