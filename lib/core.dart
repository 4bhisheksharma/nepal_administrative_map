/// Pure-Dart core of nepal_administrative_map: regions, names, numbers,
/// geometry and map data.
///
/// Has no Flutter dependency, so it also works in CLI tools, servers and
/// plain Dart tests.
library;

export 'src/data/gazetteer/nepal.dart';
export 'src/data/loader/map_data_source.dart';
export 'src/data/loader/nepal_map_data.dart';
export 'src/data/models/region.dart' hide regionAliases;
export 'src/geometry/bounds.dart';
export 'src/geometry/lat_lng.dart';
export 'src/geometry/polygon.dart';
export 'src/geometry/polylabel.dart';
export 'src/geometry/projection.dart';
export 'src/i18n/devanagari.dart';
export 'src/i18n/localized_name.dart';
export 'src/i18n/map_language.dart';
export 'src/i18n/nepal_map_strings.dart';
export 'src/i18n/nepal_number_format.dart';
