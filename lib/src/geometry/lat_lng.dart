/// A geographic point in degrees (WGS84).
class LatLng {
  /// Creates a point. [latitude] is in −90…90, [longitude] in −180…180.
  const LatLng(this.latitude, this.longitude)
    : assert(latitude >= -90 && latitude <= 90),
      assert(longitude >= -180 && longitude <= 180);

  /// Degrees north of the equator.
  final double latitude;

  /// Degrees east of Greenwich.
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
