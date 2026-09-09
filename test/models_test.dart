import 'package:flutter_test/flutter_test.dart';
import 'package:socekt_demo/models/attendance_session.dart';
import 'package:socekt_demo/models/attendance_record.dart';
import 'package:socekt_demo/models/attendance_status.dart';

void main() {
  group('AttendanceSession Model', () {
    test('serializes and deserializes accurately with currentBleCode', () {
      final now = DateTime.now();
      final end = now.add(const Duration(minutes: 10));
      final session = AttendanceSession(
        title: 'Network Systems',
        facultyName: 'Dr. Rao',
        facultyLat: 19.123456,
        facultyLng: 72.987654,
        radiusMeters: 35.0,
        startTime: now,
        endTime: end,
        isActive: true,
        directionalModeEnabled: true,
        facultyHeading: 45.0,
        frontSectorDegrees: 120.0,
        bleSessionUuid: 'test-session-uuid-1234',
        currentBleCode: 88,
      );

      final json = session.toJson();
      expect(json['title'], equals('Network Systems'));
      expect(json['facultyName'], equals('Dr. Rao'));
      expect(json['currentBleCode'], equals(88));
      expect(json['bleSessionUuid'], equals('test-session-uuid-1234'));

      final parsed = AttendanceSession.fromJson(json);
      expect(parsed.title, equals(session.title));
      expect(parsed.facultyName, equals(session.facultyName));
      expect(parsed.currentBleCode, equals(88));
      expect(parsed.bleSessionUuid, equals('test-session-uuid-1234'));
      expect(parsed.isExpired, isFalse);
    });

    test('isExpired is true when ended in past or isActive is false', () {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      final expiredSession = AttendanceSession(
        title: 'History',
        facultyName: 'Prof. X',
        facultyLat: 0.0,
        facultyLng: 0.0,
        radiusMeters: 50.0,
        startTime: past.subtract(const Duration(minutes: 30)),
        endTime: past,
        isActive: true,
      );
      expect(expiredSession.isExpired, isTrue);

      final inactiveSession = AttendanceSession(
        title: 'History',
        facultyName: 'Prof. X',
        facultyLat: 0.0,
        facultyLng: 0.0,
        radiusMeters: 50.0,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
        isActive: false,
      );
      expect(inactiveSession.isExpired, isTrue);
    });
  });

  group('AttendanceRecord Model', () {
    test('serializes and deserializes record with BLE fields', () {
      final now = DateTime.now();
      final record = AttendanceRecord(
        id: 'rec-001',
        studentName: 'Aarav Patel',
        rollNo: '22CS102',
        studentLat: 19.1235,
        studentLng: 72.9877,
        distanceMeters: 8.5,
        bearingToStudent: 32.0,
        isMocked: false,
        isInFrontSector: true,
        timestamp: now,
        status: AttendanceStatus.approved,
        remarks: 'Layer 1 & Layer 3 passed',
        bleVerified: true,
        bleCodeUsed: 88,
      );

      final json = record.toJson();
      expect(json['studentName'], equals('Aarav Patel'));
      expect(json['rollNo'], equals('22CS102'));
      expect(json['bleVerified'], isTrue);
      expect(json['bleCodeUsed'], equals(88));

      final parsed = AttendanceRecord.fromJson('rec-001', json);
      expect(parsed.id, equals('rec-001'));
      expect(parsed.studentName, equals('Aarav Patel'));
      expect(parsed.bleVerified, isTrue);
      expect(parsed.bleCodeUsed, equals(88));
      expect(parsed.status, equals(AttendanceStatus.approved));
    });
  });
}
