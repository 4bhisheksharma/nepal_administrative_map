import '../../i18n/localized_name.dart';
import '../../i18n/map_language.dart';

part 'region.g.dart';

/// A level of Nepal's administrative hierarchy.
enum AdminLevel {
  /// One of the 7 provinces.
  province(LocalizedName('Province', 'प्रदेश')),

  /// One of the 77 districts.
  district(LocalizedName('District', 'जिल्ला')),

  /// One of the 753 local levels.
  localLevel(LocalizedName('Local Level', 'स्थानीय तह'));

  const AdminLevel(this.label);

  /// Display name of the level, e.g. "District" / "जिल्ला".
  final LocalizedName label;
}

/// Kind of local level.
enum LocalLevelType {
  /// Metropolitan city.
  metropolitan(LocalizedName('Metropolitan City', 'महानगरपालिका')),

  /// Sub-metropolitan city.
  subMetropolitan(LocalizedName('Sub-Metropolitan City', 'उपमहानगरपालिका')),

  /// Municipality.
  municipality(LocalizedName('Municipality', 'नगरपालिका')),

  /// Rural municipality.
  ruralMunicipality(LocalizedName('Rural Municipality', 'गाउँपालिका'));

  const LocalLevelType(this.label);

  /// Display name of the type, e.g. "Rural Municipality" / "गाउँपालिका".
  final LocalizedName label;
}

/// Kind of protected area.
enum ProtectedAreaType {
  /// National park.
  nationalPark(LocalizedName('National Park', 'राष्ट्रिय निकुञ्ज')),

  /// Wildlife reserve.
  wildlifeReserve(LocalizedName('Wildlife Reserve', 'वन्यजन्तु आरक्ष')),

  /// Hunting reserve.
  huntingReserve(LocalizedName('Hunting Reserve', 'शिकार आरक्ष')),

  /// Watershed and wildlife reserve.
  watershedAndWildlifeReserve(
    LocalizedName(
      'Watershed and Wildlife Reserve',
      'जलाधार तथा वन्यजन्तु आरक्ष',
    ),
  ),

  /// Development area.
  developmentArea(LocalizedName('Development Area', 'विकास क्षेत्र'));

  const ProtectedAreaType(this.label);

  /// Display name of the type, e.g. "National Park" / "राष्ट्रिय निकुञ्ज".
  final LocalizedName label;
}

/// A province, district or local level.
///
/// Implemented only by [Province], [District] and [LocalLevel], so a `switch`
/// over a [Region] is exhaustive.
sealed class Region {
  /// Stable code, e.g. `P3`, `D305`, `L30501`. Never changes once published.
  String get code;

  /// Name without the type, e.g. "Pokhara".
  LocalizedName get name;

  /// Which level of the hierarchy this region is.
  AdminLevel get level;

  /// The province this region is in (itself, for a province).
  Province get province;

  /// Name with its type in [language], e.g. "Pokhara Metropolitan City" /
  /// "पोखरा महानगरपालिका".
  String fullName(MapLanguage language);
}

// Hand-written members of the generated enums. The generator only adds
// `with _XMembers`; everything else lives here.

String _withSuffix(
  LocalizedName name,
  LocalizedName suffix,
  MapLanguage language,
) => '${name.of(language)} ${suffix.of(language)}';

mixin _ProvinceMembers {
  Province get _self => this as Province;

  /// This province.
  Province get province => _self;

  /// Districts in this province, in code order.
  List<District> get districts => _districtsByProvince[_self]!;

  /// Local levels in this province, in code order.
  List<LocalLevel> get localLevels => [
    for (final d in districts) ...d.localLevels,
  ];

  /// e.g. "Koshi Province" / "कोशी प्रदेश".
  String fullName(MapLanguage language) =>
      _withSuffix(_self.name, AdminLevel.province.label, language);
}

mixin _DistrictMembers {
  District get _self => this as District;

  /// Local levels in this district, in code order.
  List<LocalLevel> get localLevels => _localLevelsByDistrict[_self]!;

  /// e.g. "Kaski District" / "कास्की जिल्ला".
  String fullName(MapLanguage language) =>
      _withSuffix(_self.name, AdminLevel.district.label, language);
}

mixin _LocalLevelMembers {
  LocalLevel get _self => this as LocalLevel;

  /// The province this local level is in.
  Province get province => _self.district.province;

  /// e.g. "Pokhara Metropolitan City" / "पोखरा महानगरपालिका".
  String fullName(MapLanguage language) =>
      _withSuffix(_self.name, _self.type.label, language);
}

mixin _ProtectedAreaMembers {
  ProtectedArea get _self => this as ProtectedArea;

  /// e.g. "Chitwan National Park" / "चितवन राष्ट्रिय निकुञ्ज".
  String fullName(MapLanguage language) =>
      _withSuffix(_self.name, _self.type.label, language);
}

final Map<Province, List<District>> _districtsByProvince = {
  for (final p in Province.values)
    p: List.unmodifiable(District.values.where((d) => d.province == p)),
};

final Map<District, List<LocalLevel>> _localLevelsByDistrict = {
  for (final d in District.values)
    d: List.unmodifiable(LocalLevel.values.where((l) => l.district == d)),
};
