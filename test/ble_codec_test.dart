import 'package:flutter_test/flutter_test.dart';
import 'package:socekt_demo/services/ble_advertiser_service.dart';
import 'package:socekt_demo/services/ble_scanner_service.dart';

void main() {
  group('24-Byte BLE Packet Codec', () {
    const testUuid = 'e58ed763-928b-4155-ac9d-fd59773ea7b9';

    test('buildManufacturerData produces exactly 24 bytes', () {
      final payload = BleAdvertiserService.buildManufacturerData(
        testUuid,
        42,
        allowedRadius: 30,
        calibratedTxPower: -59,
        remainingMinutes: 15,
        sessionFlags: 0x05,
        courseCode: 'CS-101',
        roomNumber: 'LH-2',
        facultyInitials: 'DRK',
      );
      expect(payload.length, equals(24));
    });

    test('exact byte offset layout matches 24-byte specification', () {
      final payload = BleAdvertiserService.buildManufacturerData(
        testUuid,
        42,
        allowedRadius: 45,
        calibratedTxPower: -59,
        remainingMinutes: 14,
        sessionFlags: 0x01,
        courseCode: 'CS-101',
        roomNumber: 'LH-2',
        facultyInitials: 'DRK',
      );

      // Byte 4: Rolling Code
      expect(payload[4], equals(42));

      // Byte 5: Allowed Radius (45m)
      expect(payload[5], equals(45));

      // Byte 6: Calibrated TxPower (-59 dBm -> 256 - 59 = 197)
      expect(payload[6], equals(197));

      // Byte 7: Remaining Minutes
      expect(payload[7], equals(14));

      // Byte 8: Session Flags
      expect(payload[8], equals(0x01));

      // Bytes 9-14: Course Code ("CS-101")
      final courseStr = String.fromCharCodes(payload.sublist(9, 15));
      expect(courseStr, equals('CS-101'));

      // Bytes 15-18: Room / Hall ("LH-2")
      final roomStr = String.fromCharCodes(payload.sublist(15, 19));
      expect(roomStr, equals('LH-2'));

      // Bytes 19-21: Faculty Initials ("DRK")
      final initialsStr = String.fromCharCodes(payload.sublist(19, 22));
      expect(initialsStr, equals('DRK'));

      // Bytes 22-23: CRC-16 Checksum
      final crc = (payload[22] << 8) | payload[23];
      final expectedCrc = BleAdvertiserService.computeCrc16(payload, 22);
      expect(crc, equals(expectedCrc));
    });

    test('parsePayload accurately decodes all 24 bytes and validates CRC-16', () {
      final payload = BleAdvertiserService.buildManufacturerData(
        testUuid,
        88,
        allowedRadius: 60,
        calibratedTxPower: -59,
        remainingMinutes: 25,
        sessionFlags: 0x03,
        courseCode: 'MATH2',
        roomNumber: '304A',
        facultyInitials: 'SKP',
      );

      final parsed = BleAdvertiserService.parsePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.code, equals(88));
      expect(parsed.allowedRadius, equals(60));
      expect(parsed.calibratedTxPower, equals(-59));
      expect(parsed.remainingMinutes, equals(25));
      expect(parsed.sessionFlags, equals(0x03));
      expect(parsed.courseCode, equals('MATH2'));
      expect(parsed.roomNumber, equals('304A'));
      expect(parsed.facultyInitials, equals('SKP'));
      expect(parsed.isCrcValid, isTrue);
      expect(parsed.isLegacy, isFalse);
    });

    test('CRC-16 detects corrupted/tampered bytes over the radio', () {
      final payload = BleAdvertiserService.buildManufacturerData(
        testUuid,
        50,
        allowedRadius: 30,
        calibratedTxPower: -59,
      );

      // Mutate a byte in the middle of transmission
      payload[4] = 99; // tampered code

      final parsed = BleAdvertiserService.parsePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.isCrcValid, isFalse);
    });

    test('radius is strictly clamped to [5, 60] meters in payload', () {
      final payloadLow = BleAdvertiserService.buildManufacturerData(
        testUuid,
        1,
        allowedRadius: 2, // below min
      );
      expect(payloadLow[5], equals(5));

      final payloadHigh = BleAdvertiserService.buildManufacturerData(
        testUuid,
        1,
        allowedRadius: 150, // above max 60m
      );
      expect(payloadHigh[5], equals(60));
    });

    test('gracefully handles legacy 5-byte payload with fallback defaults', () {
      final legacyPayload = [0x12, 0x34, 0x56, 0x78, 42];
      final parsed = BleAdvertiserService.parsePayload(legacyPayload);
      expect(parsed, isNotNull);
      expect(parsed!.code, equals(42));
      expect(parsed.isLegacy, isTrue);
      expect(parsed.isCrcValid, isTrue);
    });

    test('BleBeaconResult calculates distance accurately from calibrated TxPower', () {
      const beacon = BleBeaconResult(
        code: 42,
        rssi: -59, // RSSI == TxPower -> distance is exactly 1.0 meter!
        uuid: 'test-uuid',
        calibratedTxPower: -59,
        allowedRadius: 30,
      );
      expect(beacon.estimatedMeters, closeTo(1.0, 0.05));
      expect(beacon.isWithinRadius, isTrue);

      const distantBeacon = BleBeaconResult(
        code: 42,
        rssi: -90, // Weaker signal
        uuid: 'test-uuid',
        calibratedTxPower: -59,
        allowedRadius: 10,
      );
      expect(distantBeacon.estimatedMeters, greaterThan(20.0));
      expect(distantBeacon.isWithinRadius, isFalse);
    });
  });
}
