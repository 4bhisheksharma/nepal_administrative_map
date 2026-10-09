import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Every widget test fails if it leaves disposable objects (pictures, text
/// painters, notifiers, controllers) undisposed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnoredAll().copyWith(
    ignore: false,
  );
  await testMain();
}
