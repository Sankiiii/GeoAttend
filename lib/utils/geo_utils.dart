import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class GeoUtils {
  /// Calculates distance in meters between two lat/lng coordinates.
  static double calculateDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculates compass bearing (0–360°) from point A (Faculty) -> point B (Student).
  static double calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Returns true if [bearingToStudent] falls within the front sector
  /// defined by [facultyHeading] ± [sectorDegrees]/2.
  static bool isStudentInFrontSector(
      double facultyHeading, double bearingToStudent, double sectorDegrees) {
    if (sectorDegrees >= 360) return true;
    double diff = (bearingToStudent - facultyHeading + 360.0) % 360.0;
    if (diff > 180.0) diff = 360.0 - diff;
    return diff <= sectorDegrees / 2.0;
  }

  /// Returns a human-readable direction label for a compass heading.
  static String headingToLabel(double heading) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    return dirs[((heading + 22.5) / 45).floor() % 8];
  }

  /// Formats Duration into mm:ss
  static String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Converts BLE RSSI into an estimated physical distance in meters using the
  /// Log-Distance Path Loss model: distance = 10 ^ ((txPower - rssi) / (10 * n))
  static double rssiToEstimatedMeters(
    int rssi, {
    int txPower = -59,
    double pathLossExponent = 2.2,
  }) {
    if (rssi == 0) return -1.0;
    final ratio = (txPower - rssi) / (10.0 * pathLossExponent);
    final distance = math.pow(10.0, ratio).toDouble();
    if (distance < 0.1) return 0.1;
    if (distance > 60.0) return 60.0;
    return double.parse(distance.toStringAsFixed(1));
  }

  /// Returns a friendly label for the BLE signal quality.
  static String rssiToSignalQuality(int rssi) {
    if (rssi >= -60) return 'Very Strong';
    if (rssi >= -70) return 'Strong';
    if (rssi >= -80) return 'Moderate';
    if (rssi >= -90) return 'Weak';
    return 'Very Weak';
  }
}
