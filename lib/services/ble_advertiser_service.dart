import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'permission_service.dart';

/// Strongly-typed model representing the complete 24-byte BLE payload.
class BlePacketPayload {
  final int sessionTag; // Bytes 0-3 (uint32)
  final int code; // Byte 4 (0-99)
  final int allowedRadius; // Byte 5 (5-60m)
  final int calibratedTxPower; // Byte 6 (signed int8, e.g. -59)
  final int remainingMinutes; // Byte 7 (0-120m)
  final int sessionFlags; // Byte 8 (bitmask)
  final String courseCode; // Bytes 9-14 (6 chars ASCII)
  final String roomNumber; // Bytes 15-18 (4 chars ASCII)
  final String facultyInitials; // Bytes 19-21 (3 chars ASCII)
  final int checksum; // Bytes 22-23 (CRC-16)
  final bool isCrcValid;
  final bool isLegacy;

  const BlePacketPayload({
    required this.sessionTag,
    required this.code,
    required this.allowedRadius,
    required this.calibratedTxPower,
    required this.remainingMinutes,
    required this.sessionFlags,
    required this.courseCode,
    required this.roomNumber,
    required this.facultyInitials,
    required this.checksum,
    required this.isCrcValid,
    this.isLegacy = false,
  });

  bool get isActive => (sessionFlags & 0x01) != 0;
  bool get isGpsRequired => (sessionFlags & 0x02) != 0;
  bool get isDirectionalRequired => (sessionFlags & 0x04) != 0;
  bool get isOfflineOnly => (sessionFlags & 0x08) != 0;
}

/// Faculty-side BLE advertiser.
///
/// Encodes a [sessionUuid], 2-digit [currentCode], and rich classroom/session
/// metadata into a complete 24-byte BLE manufacturer data payload.
/// The code rotates every [rotationSeconds] seconds automatically.
class BleAdvertiserService {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// Manufacturer ID used in the BLE packet.
  static const int _manufacturerId = 0xFFAA;

  /// Seconds between automatic code rotations (2 minutes).
  static const int rotationSeconds = 120;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final math.Random _random = math.Random();

  final StreamController<int> _codeController =
      StreamController<int>.broadcast();
  final StreamController<bool> _advertisingController =
      StreamController<bool>.broadcast();

  Timer? _rotationTimer;
  Timer? _countdownTimer;

  int _currentCode = 0;
  int _secondsUntilRotation = rotationSeconds;
  bool _isAdvertising = false;
  bool _isDisposed = false;
  String _sessionUuid = '';

  // 24-byte payload configuration state
  int _allowedRadius = 30;
  int _calibratedTxPower = -59;
  int _remainingMinutes = 60;
  int _sessionFlags = 0x01;
  String _courseCode = 'CLASS';
  String _roomNumber = 'LH-1';
  String _facultyInitials = 'FAC';

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Emits the current 2-digit code every time it rotates.
  Stream<int> get codeStream => _codeController.stream;

  /// Emits true when advertising is active, false when stopped.
  Stream<bool> get advertisingStream => _advertisingController.stream;

  /// The live 2-digit code to display and speak aloud.
  int get currentCode => _currentCode;

  /// Seconds remaining until the next code rotation.
  int get secondsUntilRotation => _secondsUntilRotation;

  /// Whether advertising is currently active.
  bool get isAdvertising => _isAdvertising;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts BLE advertising for [sessionUuid] with 24-byte metadata.
  Future<void> startAdvertising(
    String sessionUuid, {
    int allowedRadius = 30,
    int calibratedTxPower = -59,
    int remainingMinutes = 60,
    int sessionFlags = 0x01,
    String courseCode = 'CLASS',
    String roomNumber = 'LH-1',
    String facultyInitials = 'FAC',
  }) async {
    if (_isDisposed) return;

    // Check & request Bluetooth permissions
    await AppPermissionService.requestBleAndLocationPermissions();

    await stopAdvertising();
    if (_isDisposed) return;

    _sessionUuid = sessionUuid;
    _allowedRadius = allowedRadius.clamp(5, 60);
    _calibratedTxPower = calibratedTxPower.clamp(-128, 127);
    _remainingMinutes = remainingMinutes.clamp(0, 120);
    _sessionFlags = sessionFlags;
    _courseCode = courseCode;
    _roomNumber = roomNumber;
    _facultyInitials = facultyInitials;

    _generateNewCode();
    await _startBleAdvertising();
    _startRotationTimer();
    _startCountdownTimer();
  }

  /// Stops all advertising and timers without crashing if already disposed.
  Future<void> stopAdvertising() async {
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    _rotationTimer = null;
    _countdownTimer = null;

    if (_isAdvertising) {
      _isAdvertising = false;
      try {
        await _blePeripheral.stop();
      } catch (e) {
        debugPrint('BleAdvertiser: stopAdvertising error: $e');
      }
      if (!_isDisposed && !_advertisingController.isClosed) {
        _advertisingController.add(false);
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _rotationTimer?.cancel();
    _countdownTimer?.cancel();
    _rotationTimer = null;
    _countdownTimer = null;

    if (_isAdvertising) {
      _isAdvertising = false;
      _blePeripheral.stop().catchError((e) {
        debugPrint('BleAdvertiser: stop on dispose error: $e');
        return PeripheralBluetoothState.unknown;
      });
    }

    if (!_codeController.isClosed) {
      _codeController.close();
    }
    if (!_advertisingController.isClosed) {
      _advertisingController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _generateNewCode() {
    if (_isDisposed) return;
    _currentCode = _random.nextInt(100); // 0-99
    _secondsUntilRotation = rotationSeconds;
    if (!_isDisposed && !_codeController.isClosed) {
      _codeController.add(_currentCode);
    }
    debugPrint('BleAdvertiser: new code -> $_currentCode');
  }

  Future<void> _startBleAdvertising() async {
    if (_isDisposed) return;
    try {
      final payload = buildManufacturerData(
        _sessionUuid,
        _currentCode,
        allowedRadius: _allowedRadius,
        calibratedTxPower: _calibratedTxPower,
        remainingMinutes: _remainingMinutes,
        sessionFlags: _sessionFlags,
        courseCode: _courseCode,
        roomNumber: _roomNumber,
        facultyInitials: _facultyInitials,
      );
      final sessionTag = computeSessionTag(_sessionUuid);

      debugPrint(
        'BleAdvertiser: starting advertisement — code: $_currentCode, tag: 0x${sessionTag.toRadixString(16).padLeft(8, '0')}, bytes (${payload.length}): $payload',
      );

      await _blePeripheral.start(
        advertiseData: AdvertiseDataCore(
          manufacturerId: _manufacturerId,
          manufacturerData: Uint8List.fromList(payload),
        ),
        androidSettings: const AndroidAdvertiseSettings(
          advertiseSettings: AdvertiseSettings(
            advertiseMode: AdvertiseMode.advertiseModeLowLatency,
            txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
            connectable: false,
          ),
        ),
      );

      _isAdvertising = true;
      if (!_isDisposed && !_advertisingController.isClosed) {
        _advertisingController.add(true);
      }
      debugPrint('BleAdvertiser: advertising active successfully (24-byte packet)!');
    } catch (e) {
      debugPrint('BleAdvertiser: startAdvertising error: $e');
      _isAdvertising = false;
      if (!_isDisposed && !_advertisingController.isClosed) {
        _advertisingController.add(false);
      }
    }
  }

  void _startRotationTimer() {
    if (_isDisposed) return;
    _rotationTimer =
        Timer.periodic(const Duration(seconds: rotationSeconds), (_) async {
      if (_isDisposed) return;
      _generateNewCode();
      if (_remainingMinutes > 2) {
        _remainingMinutes -= 2;
      }
      if (_isAdvertising) {
        try {
          await _blePeripheral.stop();
        } catch (_) {}
        if (!_isDisposed) {
          await _startBleAdvertising();
        }
      }
    });
  }

  void _startCountdownTimer() {
    if (_isDisposed) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) return;
      if (_secondsUntilRotation > 0) {
        _secondsUntilRotation--;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 24-Byte Codec & Checksum Helpers
  // ---------------------------------------------------------------------------

  /// Computes CRC-16-CCITT (polynomial 0x1021, init 0xFFFF) across [bytes].
  static int computeCrc16(List<int> bytes, [int length = 22]) {
    int crc = 0xFFFF;
    final len = length < bytes.length ? length : bytes.length;
    for (int i = 0; i < len; i++) {
      crc ^= (bytes[i] << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  /// Encodes all session metadata into exactly 24 bytes:
  /// - Bytes 0-3: Session Tag (32-bit uint hash)
  /// - Byte 4: Rolling Code (0-99)
  /// - Byte 5: Allowed Radius (5-60m)
  /// - Byte 6: Calibrated TxPower @ 1m (signed int8, e.g. -59 dBm)
  /// - Byte 7: Remaining Minutes (0-120)
  /// - Byte 8: Session Flags (Bitmask)
  /// - Bytes 9-14: Course Code (6 ASCII chars)
  /// - Bytes 15-18: Room / Hall (4 ASCII chars)
  /// - Bytes 19-21: Faculty Initials (3 ASCII chars)
  /// - Bytes 22-23: CRC-16 Checksum (2 bytes uint16)
  static List<int> buildManufacturerData(
    String uuid,
    int code, {
    int allowedRadius = 30,
    int calibratedTxPower = -59,
    int remainingMinutes = 60,
    int sessionFlags = 0x01,
    String courseCode = 'CLASS',
    String roomNumber = 'LH-1',
    String facultyInitials = 'FAC',
  }) {
    final bytes = <int>[];

    // Bytes 0-3: Session Tag (4 bytes)
    final hexClean = uuid.replaceAll('-', '').toLowerCase();
    for (int i = 0; i < 8 && i + 1 < hexClean.length; i += 2) {
      bytes.add(int.parse(hexClean.substring(i, i + 2), radix: 16));
    }
    while (bytes.length < 4) {
      bytes.add(0);
    }

    // Byte 4: Rolling Code (0-99)
    bytes.add(code.clamp(0, 99));

    // Byte 5: Allowed Radius (5-60m)
    bytes.add(allowedRadius.clamp(5, 60));

    // Byte 6: Calibrated TxPower @ 1m (signed int8: e.g. -59 -> 197)
    final txClamped = calibratedTxPower.clamp(-128, 127);
    bytes.add(txClamped < 0 ? (256 + txClamped) : txClamped);

    // Byte 7: Remaining Minutes (0-120)
    bytes.add(remainingMinutes.clamp(0, 120));

    // Byte 8: Session Flags (Bitmask)
    bytes.add(sessionFlags & 0xFF);

    // Bytes 9-14: Course Code (6 bytes ASCII)
    final cleanCourse = courseCode.trim().toUpperCase();
    final courseBytes = cleanCourse.codeUnits;
    for (int i = 0; i < 6; i++) {
      bytes.add(i < courseBytes.length ? courseBytes[i] : 0x20); // space
    }

    // Bytes 15-18: Room / Hall (4 bytes ASCII)
    final cleanRoom = roomNumber.trim().toUpperCase();
    final roomBytes = cleanRoom.codeUnits;
    for (int i = 0; i < 4; i++) {
      bytes.add(i < roomBytes.length ? roomBytes[i] : 0x20);
    }

    // Bytes 19-21: Faculty Initials (3 bytes ASCII)
    final cleanInitials = facultyInitials.trim().toUpperCase();
    final initialsBytes = cleanInitials.codeUnits;
    for (int i = 0; i < 3; i++) {
      bytes.add(i < initialsBytes.length ? initialsBytes[i] : 0x20);
    }

    // Bytes 22-23: CRC-16 Checksum over bytes 0..21
    final crc = computeCrc16(bytes, 22);
    bytes.add((crc >> 8) & 0xFF);
    bytes.add(crc & 0xFF);

    return bytes;
  }

  /// Parses the complete 24-byte payload (with 5-byte legacy fallback).
  static BlePacketPayload? parsePayload(List<int> data) {
    if (data.length < 5) return null;

    final sessionTag =
        (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    final code = data[4];

    if (data.length < 24) {
      // Legacy 5-byte payload fallback
      return BlePacketPayload(
        sessionTag: sessionTag,
        code: code,
        allowedRadius: 30,
        calibratedTxPower: -59,
        remainingMinutes: 30,
        sessionFlags: 0x01,
        courseCode: 'CLASS',
        roomNumber: 'ROOM',
        facultyInitials: 'FAC',
        checksum: 0,
        isCrcValid: true,
        isLegacy: true,
      );
    }

    final allowedRadius = data[5];
    final rawTx = data[6];
    final calibratedTxPower = rawTx > 127 ? rawTx - 256 : rawTx;
    final remainingMinutes = data[7];
    final sessionFlags = data[8];

    final courseCode = String.fromCharCodes(data.sublist(9, 15)).trim();
    final roomNumber = String.fromCharCodes(data.sublist(15, 19)).trim();
    final facultyInitials = String.fromCharCodes(data.sublist(19, 22)).trim();

    final receivedCrc = (data[22] << 8) | data[23];
    final calculatedCrc = computeCrc16(data, 22);
    final isCrcValid = receivedCrc == calculatedCrc;

    return BlePacketPayload(
      sessionTag: sessionTag,
      code: code,
      allowedRadius: allowedRadius,
      calibratedTxPower: calibratedTxPower,
      remainingMinutes: remainingMinutes,
      sessionFlags: sessionFlags,
      courseCode: courseCode.isEmpty ? 'CLASS' : courseCode,
      roomNumber: roomNumber.isEmpty ? 'HALL' : roomNumber,
      facultyInitials: facultyInitials.isEmpty ? 'FAC' : facultyInitials,
      checksum: receivedCrc,
      isCrcValid: isCrcValid,
      isLegacy: false,
    );
  }

  /// Parses the 2-digit code from manufacturer data bytes.
  static int? parseCode(List<int> data) => parsePayload(data)?.code;

  /// Parses the 4-byte session tag from manufacturer data bytes.
  static int? parseSessionTag(List<int> data) =>
      parsePayload(data)?.sessionTag;

  /// Computes the 4-byte session tag from a session UUID string.
  static int computeSessionTag(String uuid) {
    final hexClean = uuid.replaceAll('-', '').toLowerCase();
    final bytes = <int>[];
    for (int i = 0; i < 8 && i + 1 < hexClean.length; i += 2) {
      bytes.add(int.parse(hexClean.substring(i, i + 2), radix: 16));
    }
    while (bytes.length < 4) {
      bytes.add(0);
    }
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}
