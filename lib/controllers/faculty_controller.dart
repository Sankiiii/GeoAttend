import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';
import '../services/ble_advertiser_service.dart';

class FacultyController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final BleAdvertiserService _bleAdvertiser = BleAdvertiserService();

  // ---------------------------------------------------------------------------
  // GPS State
  // ---------------------------------------------------------------------------
  Position? currentPosition;
  bool isLoadingGps = false;
  String? gpsError;

  // ---------------------------------------------------------------------------
  // Session Config State
  // ---------------------------------------------------------------------------
  String title = 'CS101 - Lecture';
  String facultyName = 'Prof. Sharma';
  double radiusMeters = 30.0;
  int durationMinutes = 5;
  bool directionalMode = false;
  double lockedHeading = 0.0;
  double sectorDegrees = 180.0;

  // ---------------------------------------------------------------------------
  // Action states
  // ---------------------------------------------------------------------------
  bool isStartingSession = false;

  // ---------------------------------------------------------------------------
  // Live session & submissions
  // ---------------------------------------------------------------------------
  AttendanceSession? activeSession;
  List<AttendanceRecord> records = [];

  // ---------------------------------------------------------------------------
  // BLE State (Layer 1)
  // ---------------------------------------------------------------------------
  int bleCurrentCode = 0;
  int bleSecondsUntilRotation = BleAdvertiserService.rotationSeconds;
  bool bleIsAdvertising = false;

  StreamSubscription<int>? _bleCodeSub;
  StreamSubscription<bool>? _bleAdvertisingSub;

  // ---------------------------------------------------------------------------
  // Firebase & Ticker
  // ---------------------------------------------------------------------------
  StreamSubscription<AttendanceSession?>? _sessionSub;
  StreamSubscription<List<AttendanceRecord>>? _recordsSub;
  Timer? _ticker;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  void init() {
    // Start GPS automatically in the background — no manual tap needed
    _fetchGpsBackground();
    _subscribeFirebase();
    _startTicker();
    _subscribeBle();
  }

  void _subscribeFirebase() {
    _sessionSub = _firebaseService.activeSessionStream.listen((session) {
      activeSession = session;
      notifyListeners();
    });

    _recordsSub = _firebaseService.attendanceRecordsStream.listen((newRecords) {
      records = newRecords;
      notifyListeners();
    });
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (activeSession != null && activeSession!.isActive) {
        if (activeSession!.isExpired) {
          _firebaseService.endSession().catchError((_) {});
          _bleAdvertiser.stopAdvertising();
        }
        notifyListeners();
      }
      // Update BLE countdown display every second
      bleSecondsUntilRotation = _bleAdvertiser.secondsUntilRotation;
    });
  }

  void _subscribeBle() {
    _bleCodeSub = _bleAdvertiser.codeStream.listen((code) {
      bleCurrentCode = code;
      if (activeSession != null && activeSession!.isActive && !activeSession!.isExpired) {
        _firebaseService.updateCurrentBleCode(code);
      }
      notifyListeners();
    });
    _bleAdvertisingSub = _bleAdvertiser.advertisingStream.listen((active) {
      bleIsAdvertising = active;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // GPS (Background auto-fetch)
  // ---------------------------------------------------------------------------

  Future<void> _fetchGpsBackground() async {
    isLoadingGps = true;
    gpsError = null;
    notifyListeners();

    try {
      currentPosition = await LocationService.getCurrentPosition();
      isLoadingGps = false;
      gpsError = null;
    } on LocationServiceDisabledException {
      isLoadingGps = false;
      gpsError = 'GPS is turned off. Please enable location services.';
    } catch (e) {
      isLoadingGps = false;
      gpsError = e.toString().replaceAll('Exception: ', '');
    }
    notifyListeners();
  }

  /// Manual GPS refresh (still available via the refresh icon in UI).
  Future<void> fetchGps() async {
    await _fetchGpsBackground();
  }

  // ---------------------------------------------------------------------------
  // Session Config Setters
  // ---------------------------------------------------------------------------

  void setTitle(String val) => title = val;
  void setFacultyName(String val) => facultyName = val;

  void setRadius(double val) {
    radiusMeters = val;
    notifyListeners();
  }

  void setDuration(int val) {
    durationMinutes = val;
    notifyListeners();
  }

  void setDirectionalMode(bool val) {
    directionalMode = val;
    notifyListeners();
  }

  void setLockedHeading(double val) {
    lockedHeading = val;
    notifyListeners();
  }

  void setSectorDegrees(double val) {
    sectorDegrees = val;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Session Control
  // ---------------------------------------------------------------------------

  Future<void> startSession() async {
    // Auto-retry GPS if not yet acquired
    if (currentPosition == null) {
      await _fetchGpsBackground();
    }

    if (currentPosition == null) {
      throw Exception('Could not acquire GPS. Please enable location services.');
    }

    isStartingSession = true;
    notifyListeners();

    try {
      // 1. Start BLE advertising first (generates initial code)
      await _bleAdvertiser.startAdvertising(bleUuid);
      bleCurrentCode = _bleAdvertiser.currentCode;

      final now = DateTime.now();
      final session = AttendanceSession(
        title: title.trim().isEmpty ? 'Lecture Session' : title.trim(),
        facultyName: facultyName.trim().isEmpty ? 'Faculty' : facultyName.trim(),
        facultyLat: currentPosition!.latitude,
        facultyLng: currentPosition!.longitude,
        radiusMeters: radiusMeters,
        startTime: now,
        endTime: now.add(Duration(minutes: durationMinutes)),
        isActive: true,
        directionalModeEnabled: directionalMode,
        facultyHeading: lockedHeading,
        frontSectorDegrees: directionalMode ? sectorDegrees : 360.0,
        bleSessionUuid: bleUuid,
        currentBleCode: bleCurrentCode,
      );

      // 2. Write session to Firebase (students will pick it up)
      await _firebaseService.createSession(session);

      debugPrint('FacultyController: session started, BLE UUID=$bleUuid, code=$bleCurrentCode');
    } finally {
      isStartingSession = false;
      notifyListeners();
    }
  }

  Future<void> endSession() async {
    await _firebaseService.endSession();
    await _bleAdvertiser.stopAdvertising();
    notifyListeners();
  }

  Future<void> reviewSubmission(
      String recordId, AttendanceStatus status, String remark) async {
    await _firebaseService.updateRecordStatus(recordId, status, remark);
  }

  // ---------------------------------------------------------------------------
  // UUID generator (RFC-4122 v4 compatible)
  // ---------------------------------------------------------------------------

  static String _generateUuid() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionSub?.cancel();
    _recordsSub?.cancel();
    _ticker?.cancel();
    _bleCodeSub?.cancel();
    _bleAdvertisingSub?.cancel();
    _bleAdvertiser.dispose();
    super.dispose();
  }
}
