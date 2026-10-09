/// Runs [work] on the current thread (platforms without isolates).
Future<R> runInBackground<R>(R Function() work) async => work();
