import 'dart:math' as math;

/// Spherical geodesic calculations for cockpit flight navigation.
class GeodesicNavigation {
  const GeodesicNavigation._();

  static const double earthRadiusMeters = 6371000.0;

  static double _toRadians(double deg) => deg * (math.pi / 180.0);
  static double _toDegrees(double rad) => rad * (180.0 / math.pi);

  /// Computes geodesic distance in meters between two lat/lng coordinates (Haversine formula).
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _toRadians(lat1);
    final phi2 = _toRadians(lat2);
    final deltaPhi = _toRadians(lat2 - lat1);
    final deltaLambda = _toRadians(lon2 - lon1);

    final sinHalfPhi = math.sin(deltaPhi / 2.0);
    final sinHalfLambda = math.sin(deltaLambda / 2.0);
    final a = sinHalfPhi * sinHalfPhi +
        math.cos(phi1) * math.cos(phi2) * sinHalfLambda * sinHalfLambda;
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1.0 - a)));
    return earthRadiusMeters * c;
  }

  /// Computes true initial bearing in degrees from point 1 (origin) to point 2 (destination).
  /// Normalised to [0, 360).
  static double bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _toRadians(lat1);
    final phi2 = _toRadians(lat2);
    final deltaLambda = _toRadians(lon2 - lon1);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (_toDegrees(theta) + 360.0) % 360.0;
  }

  /// Computes required glide ratio (L/D) given horizontal distance (m) and vertical altitude margin (m).
  ///
  /// Returns null if margin <= 0 (at or below target elevation) or distance <= 15m.
  static double? requiredGlide(double distanceMeters, double altitudeMarginMeters) {
    if (distanceMeters <= 15.0 || altitudeMarginMeters <= 0.0) {
      return null;
    }
    return distanceMeters / altitudeMarginMeters;
  }
}
