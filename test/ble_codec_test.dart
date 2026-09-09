import 'package:flutter_test/flutter_test.dart';
import 'package:socekt_demo/services/ble_advertiser_service.dart';

void main() {
  group('BLE Packet Codec', () {
    const testUuid = 'e58ed763-928b-4155-ac9d-fd59773ea7b9';

    test('buildManufacturerData produces exactly 5 bytes', () {
      final payload = BleAdvertiserService.buildManufacturerData(testUuid, 42);
      expect(payload.length, equals(5));
      expect(payload[4], equals(42));
    });

    test('parseCode correctly extracts the 2-digit number', () {
      for (int code = 0; code < 100; code++) {
        final payload = BleAdvertiserService.buildManufacturerData(testUuid, code);
        expect(BleAdvertiserService.parseCode(payload), equals(code));
      }
    });

    test('computeSessionTag and parseSessionTag roundtrip', () {
      final expectedTag = BleAdvertiserService.computeSessionTag(testUuid);
      final payload = BleAdvertiserService.buildManufacturerData(testUuid, 77);
      final parsedTag = BleAdvertiserService.parseSessionTag(payload);
      expect(parsedTag, equals(expectedTag));
    });

    test('handles invalid or short payload gracefully', () {
      expect(BleAdvertiserService.parseCode([]), isNull);
      expect(BleAdvertiserService.parseCode([1, 2, 3]), isNull);
      expect(BleAdvertiserService.parseSessionTag([]), isNull);
      expect(BleAdvertiserService.parseSessionTag([1, 2, 3]), isNull);
    });
  });
}
