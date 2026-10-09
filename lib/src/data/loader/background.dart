// Runs work off the UI thread where isolates exist (mobile, desktop, VM),
// and inline on the web, which has none.
export 'background_inline.dart'
    if (dart.library.isolate) 'background_isolate.dart';
