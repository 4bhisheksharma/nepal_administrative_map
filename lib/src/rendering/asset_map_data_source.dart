import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import '../data/loader/map_data_source.dart';

/// Loads the map data bundled with this package.
class AssetMapDataSource extends MapDataSource {
  /// Creates the source. [bundle] defaults to [rootBundle].
  const AssetMapDataSource({this.bundle});

  /// The asset bundle to read from.
  final AssetBundle? bundle;

  static const _path = 'assets/maps/nepal.topo.json';

  @override
  Object get cacheKey => (AssetMapDataSource, bundle ?? rootBundle);

  @override
  Future<String> load() async {
    // Assets can't be read before Flutter's services are set up, e.g. when
    // `NepalMap.preload()` runs in `main()` before `runApp()`.
    WidgetsFlutterBinding.ensureInitialized();
    final b = bundle ?? rootBundle;
    try {
      // How the asset is named when this package is a dependency.
      return await b.loadString(
        'packages/nepal_administrative_map/$_path',
        cache: false,
      );
    } on FlutterError catch (error, stack) {
      // How it is named in this package's own tests. If that fails too,
      // report the first error: it's the path apps actually use.
      try {
        return await b.loadString(_path, cache: false);
      } on FlutterError {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }
}
