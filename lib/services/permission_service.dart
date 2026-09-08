import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionService {
  /// Ensures all required Bluetooth & Location permissions are granted
  /// without crashing on any Android version (Android 6 - Android 15).
  static Future<bool> requestBleAndLocationPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // 1. Location permission
        final locStatus = await Permission.location.status;
        if (!locStatus.isGranted) {
          await Permission.location.request();
        }

        // 2. Android 12+ (API 31+) Bluetooth runtime permissions
        final scanStatus = await Permission.bluetoothScan.status;
        if (!scanStatus.isGranted) {
          await Permission.bluetoothScan.request();
        }

        final advStatus = await Permission.bluetoothAdvertise.status;
        if (!advStatus.isGranted) {
          await Permission.bluetoothAdvertise.request();
        }

        final connStatus = await Permission.bluetoothConnect.status;
        if (!connStatus.isGranted) {
          await Permission.bluetoothConnect.request();
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Permission.bluetooth.request();
        await Permission.location.request();
      }

      // 3. Check if Bluetooth radio is enabled; turn on if disabled on Android
      try {
        final adapterState = await FlutterBluePlus.adapterState.first.timeout(
          const Duration(milliseconds: 800),
          onTimeout: () => BluetoothAdapterState.unknown,
        );
        if (adapterState == BluetoothAdapterState.off &&
            defaultTargetPlatform == TargetPlatform.android) {
          await FlutterBluePlus.turnOn().catchError((_) {});
        }
      } catch (e) {
        debugPrint('AppPermissionService adapter check: $e');
      }

      return true;
    } catch (e) {
      debugPrint('AppPermissionService request error: $e');
      return false;
    }
  }
}
