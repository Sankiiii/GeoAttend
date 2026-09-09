import 'package:flutter_test/flutter_test.dart';
import 'package:socekt_demo/utils/geo_utils.dart';

void main() {
  group('GeoUtils Tests', () {
    test('calculateDistanceMeters returns 0 for same points', () {
      final dist = GeoUtils.calculateDistanceMeters(19.0760, 72.8777, 19.0760, 72.8777);
      expect(dist, closeTo(0.0, 0.01));
    });

    test('calculateDistanceMeters calculates accurate distance', () {
      // 1 degree latitude is approx 111 km
      final dist = GeoUtils.calculateDistanceMeters(0.0, 0.0, 1.0, 0.0);
      expect(dist, closeTo(111195, 2000));
    });

    test('calculateBearing calculates standard compass directions', () {
      // Direct North: bearing should be ~0 or 360
      final bearingNorth = GeoUtils.calculateBearing(0.0, 0.0, 1.0, 0.0);
      expect(bearingNorth, closeTo(0.0, 1.0));

      // Direct East: bearing should be ~90
      final bearingEast = GeoUtils.calculateBearing(0.0, 0.0, 0.0, 1.0);
      expect(bearingEast, closeTo(90.0, 1.0));

      // Direct South: bearing should be ~180
      final bearingSouth = GeoUtils.calculateBearing(1.0, 0.0, 0.0, 0.0);
      expect(bearingSouth, closeTo(180.0, 1.0));

      // Direct West: bearing should be ~270
      final bearingWest = GeoUtils.calculateBearing(0.0, 1.0, 0.0, 0.0);
      expect(bearingWest, closeTo(270.0, 1.0));
    });

    test('isStudentInFrontSector accurately handles front vs back sectors', () {
      // Faculty faces North (0°), 180° sector (±90°, from 270° to 90°)
      // Student is directly North (0°) -> in front
      expect(GeoUtils.isStudentInFrontSector(0.0, 0.0, 180.0), isTrue);

      // Student is North-East (45°) -> in front
      expect(GeoUtils.isStudentInFrontSector(0.0, 45.0, 180.0), isTrue);

      // Student is North-West (315°) -> in front
      expect(GeoUtils.isStudentInFrontSector(0.0, 315.0, 180.0), isTrue);

      // Student is South (180°) -> behind teacher
      expect(GeoUtils.isStudentInFrontSector(0.0, 180.0, 180.0), isFalse);

      // Student is South-East (135°) -> behind teacher
      expect(GeoUtils.isStudentInFrontSector(0.0, 135.0, 180.0), isFalse);
    });

    test('headingToLabel converts degrees to cardinal direction', () {
      expect(GeoUtils.headingToLabel(0), equals('N'));
      expect(GeoUtils.headingToLabel(90), equals('E'));
      expect(GeoUtils.headingToLabel(180), equals('S'));
      expect(GeoUtils.headingToLabel(270), equals('W'));
    });
  });
}
