import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_advertiser_service.dart';
import 'permission_service.dart';

/// Represents a parsed BLE beacon result from the faculty phone.
class BleBeaconResult {
  final int code; // 2-digit number embedded in the packet
  final int rssi; // received signal strength (negative dBm)
  final String uuid; // parsed session UUID

  const BleBeaconResult({
    required this.code,
    required this.rssi,
    required this.uuid,
  });
}

/// Student-side BLE scanner.
///
/// Scans for the faculty phone's BLE advertisement, filters by the
/// session UUID, and exposes the decoded 2-digit code for the number
/// challenge.
class BleScannerService {
  static const int _manufacturerId = 0xFFAA;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final StreamController<BleBeaconResult?> _resultController =
      StreamController<BleBeaconResult?>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  bool _isScanning = false;
  bool _isDisposed = false;
  String _targetUuid = '';
  BleBeaconResult? _lastResult;

  // ---------------------------------------------------------------------------
  // Public streams / getters
  // ---------------------------------------------------------------------------

  /// Stream of the latest parsed beacon result (null when not detected).
  Stream<BleBeaconResult?> get resultStream => _resultController.stream;

  /// Whether a scan is currently active.
  bool get isScanning => _isScanning;

  /// The most recently received beacon result.
  BleBeaconResult? get lastResult => _lastResult;

  /// True when the faculty beacon is currently visible.
  bool get beaconDetected => _lastResult != null;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Starts scanning for the faculty beacon.
  /// If [sessionUuid] is provided, matches against that UUID; otherwise detects any GeoAttend beacon.
  Future<void> startScanning(String sessionUuid) async {
    if (_isDisposed) return;

    // Check & request Bluetooth runtime permissions
    await AppPermissionService.requestBleAndLocationPermissions();

    await stopScanning();
    if (_isDisposed) return;

    _targetUuid = sessionUuid.replaceAll('-', '').toLowerCase();
    _lastResult = null;

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(hours: 2),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _isScanning = true;

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          if (_isDisposed) return;
          for (final r in results) {
            _handleScanResult(r);
          }
        },
        onError: (err) {
          debugPrint('BleScannerService scanResults error: $err');
        },
      );

      _isScanningSub?.cancel();
      _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _isScanning) {
          _isScanning = false;
          debugPrint('BleScannerService: scan stopped');
        }
      });

      debugPrint('BleScannerService: scan started for UUID $_targetUuid');
    } catch (e) {
      debugPrint('BleScannerService: startScan error: $e');
      _isScanning = false;
    }
  }

  /// Stops the scan and clears the last result.
  Future<void> stopScanning() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _isScanningSub?.cancel();
    _isScanningSub = null;

    if (_isScanning) {
      _isScanning = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        debugPrint('BleScannerService: stopScan error: $e');
      }
    }

    _lastResult = null;
    if (!_isDisposed && !_resultController.isClosed) {
      _resultController.add(null);
    }
  }

  void dispose() {
    _isDisposed = true;
    _scanSub?.cancel();
    _scanSub = null;
    _isScanningSub?.cancel();
    _isScanningSub = null;

    if (_isScanning) {
      _isScanning = false;
      FlutterBluePlus.stopScan().catchError((e) {
        debugPrint('BleScannerService: stop on dispose error: $e');
      });
    }

    if (!_resultController.isClosed) {
      _resultController.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _handleScanResult(ScanResult result) {
    if (_isDisposed) return;

    final mfData = result.advertisementData.manufacturerData;
    final payload = mfData[_manufacturerId];
    if (payload == null || payload.isEmpty) return;

    final parsedUuid = BleAdvertiserService.parseUuid(payload);
    if (parsedUuid == null) return;

    final parsedClean = parsedUuid.replaceAll('-', '').toLowerCase();
    // If target UUID is specified, filter by it; if not specified, accept any GeoAttend beacon
    if (_targetUuid.isNotEmpty && _targetUuid.length >= 8) {
      if (!parsedClean.startsWith(_targetUuid.substring(0, 8))) {
        return; // wrong session
      }
    }

    final code = BleAdvertiserService.parseCode(payload);
    if (code == null) return;

    final beaconResult = BleBeaconResult(
      code: code,
      rssi: result.rssi,
      uuid: parsedUuid,
    );

    _lastResult = beaconResult;
    if (!_isDisposed && !_resultController.isClosed) {
      _resultController.add(beaconResult);
    }

    debugPrint(
      'BleScannerService: beacon detected — code=$code, rssi=${result.rssi}',
    );
  }
}
