import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'permission_service.dart';

/// Faculty-side BLE advertiser.
///
/// Encodes a [sessionUuid] and a random 2-digit [currentCode] into the
/// BLE manufacturer data payload and starts advertising. The code rotates
/// every [rotationSeconds] seconds automatically.
class BleAdvertiserService {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// Manufacturer ID used in the BLE packet.
  static const int _manufacturerId = 0xFFAA;

  /// Seconds between automatic code rotations.
  static const int rotationSeconds = 45;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final Random _random = Random();

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

  /// Starts BLE advertising for [sessionUuid].
  Future<void> startAdvertising(String sessionUuid) async {
    if (_isDisposed) return;

    // Check & request Bluetooth permissions
    await AppPermissionService.requestBleAndLocationPermissions();

    await stopAdvertising();
    if (_isDisposed) return;

    _sessionUuid = sessionUuid;
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
      final payload = _buildManufacturerData(_sessionUuid, _currentCode);

      await _blePeripheral.start(
        advertiseData: AdvertiseDataCore(
          localName: 'GeoAttend',
          serviceUuid: _sessionUuid.isNotEmpty ? _sessionUuid : null,
          manufacturerId: _manufacturerId,
          manufacturerData: Uint8List.fromList(payload),
        ),
      );

      _isAdvertising = true;
      if (!_isDisposed && !_advertisingController.isClosed) {
        _advertisingController.add(true);
      }
      debugPrint('BleAdvertiser: advertising started');
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

  /// Encodes [uuid] (first 16 bytes) and [code] (1 byte) into manufacturer data.
  static List<int> _buildManufacturerData(String uuid, int code) {
    final hexClean = uuid.replaceAll('-', '');
    final bytes = <int>[];

    final length = min(32, hexClean.length);
    for (int i = 0; i < length; i += 2) {
      if (i + 1 < hexClean.length) {
        bytes.add(int.parse(hexClean.substring(i, i + 2), radix: 16));
      }
    }

    while (bytes.length < 16) {
      bytes.add(0);
    }

    bytes.add(code & 0xFF);
    return bytes;
  }

  /// Parses the 2-digit code from manufacturer data bytes.
  static int? parseCode(List<int> data) {
    if (data.length < 17) return null;
    return data[16];
  }

  /// Parses the session UUID from manufacturer data bytes.
  static String? parseUuid(List<int> data) {
    if (data.length < 16) return null;
    final hex = data
        .sublist(0, 16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
