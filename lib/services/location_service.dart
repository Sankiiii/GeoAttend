import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

class LocationService {
  /// Build platform-tuned high accuracy settings that bypass caches.
  static LocationSettings get highAccuracySettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        distanceFilter: 0,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        distanceFilter: 0,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  /// Verifies permission and service status before retrieving location.
  static Future<void> checkAndRequestPermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Please enable it in device Settings.');
    }
  }

  /// One-shot GPS fix for Classroom / Faculty location.
  static Future<Position> getCurrentPosition() async {
    await checkAndRequestPermission();
    return await Geolocator.getCurrentPosition(
      locationSettings: highAccuracySettings,
    );
  }

  /// Continuous GPS stream for student position tracking.
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: highAccuracySettings,
    );
  }
}
