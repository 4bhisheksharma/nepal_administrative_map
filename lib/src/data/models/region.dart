import '../../i18n/localized_name.dart';

part 'region.g.dart';

/// A level of Nepal's administrative hierarchy.
enum AdminLevel {
  /// One of the 7 provinces (प्रदेश).
  province,

  /// One of the 77 districts (जिल्ला).
  district,

  /// One of the 753 local levels (स्थानीय तह).
  localLevel,
}

/// Kind of local level.
enum LocalLevelType {
  /// Metropolitan city (महानगरपालिका).
  metropolitan,

  /// Sub-metropolitan city (उपमहानगरपालिका).
  subMetropolitan,

  /// Municipality (नगरपालिका).
  municipality,

  /// Rural municipality (गाउँपालिका).
  ruralMunicipality,
}

/// Kind of protected area.
enum ProtectedAreaType {
  /// National park (राष्ट्रिय निकुञ्ज).
  nationalPark,

  /// Wildlife reserve (वन्यजन्तु आरक्ष).
  wildlifeReserve,

  /// Hunting reserve (शिकार आरक्ष).
  huntingReserve,

  /// Watershed and wildlife reserve.
  watershedAndWildlifeReserve,

  /// Development area.
  developmentArea,
}

/// A province, district or local level.
///
/// Implemented only by [Province], [District] and [LocalLevel], so a `switch`
/// over a [Region] is exhaustive.
sealed class Region {
  /// Stable code, e.g. `P3`, `D305`, `L30501`. Never changes once published.
  String get code;

  /// Name without the type suffix, e.g. "Pokhara".
  LocalizedName get name;

  /// Which level of the hierarchy this region is.
  AdminLevel get level;
}
