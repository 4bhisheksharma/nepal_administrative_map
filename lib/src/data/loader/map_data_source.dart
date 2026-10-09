/// Where the map's TopoJSON comes from.
///
/// The Flutter widget uses the bundled asset. In plain Dart (servers, CLI
/// tools, tests) create one from a string or your own loader.
abstract class MapDataSource {
  /// Const constructor for subclasses.
  const MapDataSource();

  /// A source that returns [json] as is.
  const factory MapDataSource.string(String json, {Object cacheKey}) =
      _StringSource;

  /// A source that calls [load] (e.g. `() => File(path).readAsString()`).
  /// Sources with the same [cacheKey] share one loaded copy.
  const factory MapDataSource.callback(
    Object cacheKey,
    Future<String> Function() load,
  ) = _CallbackSource;

  /// Identifies the data: sources with equal keys are loaded only once.
  Object get cacheKey;

  /// Reads the TopoJSON text.
  Future<String> load();
}

class _StringSource extends MapDataSource {
  const _StringSource(this._json, {Object? cacheKey}) : _key = cacheKey;

  final String _json;
  final Object? _key;

  @override
  Object get cacheKey => _key ?? _json;

  @override
  Future<String> load() async => _json;
}

class _CallbackSource extends MapDataSource {
  const _CallbackSource(this.cacheKey, this._load);

  @override
  final Object cacheKey;

  final Future<String> Function() _load;

  @override
  Future<String> load() => _load();
}
