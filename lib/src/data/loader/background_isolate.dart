import 'dart:isolate';

/// Runs [work] in a new isolate. The result is handed back without copying.
Future<R> runInBackground<R>(R Function() work) => Isolate.run(work);
