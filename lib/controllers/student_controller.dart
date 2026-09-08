import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';
import '../services/ble_scanner_service.dart';
import '../utils/geo_utils.dart';

class StudentController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final BleScannerService _bleScanner = BleScannerService();

  // Student Identity
  String studentName = '';
  String rollNo = '';

  // GPS State
  Position? currentPosition;
  bool isLoadingGps = false;
  String? gpsError;

  // Live session
  AttendanceSession? activeSession;

  // Submitting state
  bool isSubmitting = false;
  bool hasSubmitted = false;

  // Sandbox simulation tools
  double offsetMeters = 0.0;
  bool simulateMock = false;

  // Layer 1: BLE & Number Challenge State
  BleBeaconResult? detectedBeacon;
  bool isScanningBle = false;
  bool numberChallengeVerified = false;
  int? verifiedCode;
  String? challengeError;
  List<int> challengeOptions = [];

  // Manual / Simulation toggle for testing without a second hardware phone
  bool simulateBeaconFound = false;
  int simulatedCode = 42;

  StreamSubscription<AttendanceSession?>? _sessionSub;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BleBeaconResult?>? _bleSub;

  void init() {
    _startGpsStream();
    _subscribeSession();
    _subscribeBleScanner();
  }

  void _subscribeSession() {
    _sessionSub = _firebaseService.activeSessionStream.listen((session) {
      final prevUuid = activeSession?.bleSessionUuid;
      activeSession = session;

      if (session != null && session.isActive && !session.isExpired) {
        if (session.bleSessionUuid.isNotEmpty && session.bleSessionUuid != prevUuid) {
          _bleScanner.startScanning(session.bleSessionUuid);
          isScanningBle = true;
          // Reset challenge if session changed
          numberChallengeVerified = false;
          verifiedCode = null;
          challengeError = null;
          challengeOptions.clear();
        }
      } else {
        _bleScanner.stopScanning();
        isScanningBle = false;
      }
      notifyListeners();
    });
  }

  void _subscribeBleScanner() {
    _bleSub = _bleScanner.resultStream.listen((result) {
      detectedBeacon = result;
      if (result != null) {
        _updateChallengeOptions(result.code);
      }
      notifyListeners();
    });
  }

  void _updateChallengeOptions(int correctCode) {
    if (challengeOptions.contains(correctCode)) return;

    final rng = Random();
    final Set<int> options = {correctCode};
    while (options.length < 5) {
      options.add(rng.nextInt(100));
    }
    challengeOptions = options.toList()..shuffle();
  }

  Future<void> _startGpsStream() async {
    isLoadingGps = true;
    gpsError = null;
    notifyListeners();

    try {
      await LocationService.checkAndRequestPermission();
      _positionSub = LocationService.getPositionStream().listen(
        (pos) {
          currentPosition = pos;
          isLoadingGps = false;
          gpsError = null;
          notifyListeners();
        },
        onError: (err) {
          isLoadingGps = false;
          gpsError = err.toString();
          notifyListeners();
        },
        cancelOnError: false,
      );
    } on LocationServiceDisabledException {
      isLoadingGps = false;
      gpsError = 'GPS is turned off. Please enable location services.';
      notifyListeners();
    } catch (e) {
      isLoadingGps = false;
      gpsError = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  // Calculated properties
  double get distanceMeters {
    if (currentPosition == null || activeSession == null) return 0.0;
    return GeoUtils.calculateDistanceMeters(
          activeSession!.facultyLat,
          activeSession!.facultyLng,
          currentPosition!.latitude,
          currentPosition!.longitude,
        ) +
        offsetMeters;
  }

  double get bearingDegrees {
    if (currentPosition == null || activeSession == null) return 0.0;
    return GeoUtils.calculateBearing(
      activeSession!.facultyLat,
      activeSession!.facultyLng,
      currentPosition!.latitude,
      currentPosition!.longitude,
    );
  }

  bool get isInFrontSector {
    if (activeSession == null || !activeSession!.directionalModeEnabled) {
      return true;
    }
    return GeoUtils.isStudentInFrontSector(
      activeSession!.facultyHeading,
      bearingDegrees,
      activeSession!.frontSectorDegrees,
    );
  }

  bool get isWithinRadius {
    if (activeSession == null) return false;
    return distanceMeters <= activeSession!.radiusMeters;
  }

  bool get isMockDetected =>
      simulateMock || (currentPosition?.isMocked ?? false);

  bool get isBeaconActive =>
      (detectedBeacon != null) || simulateBeaconFound;

  int? get activeBeaconCode =>
      simulateBeaconFound ? simulatedCode : detectedBeacon?.code;

  int? get activeBeaconRssi =>
      simulateBeaconFound ? -62 : detectedBeacon?.rssi;

  bool get isReadyToMark {
    final basicReady = activeSession != null &&
        activeSession!.isActive &&
        !activeSession!.isExpired &&
        isWithinRadius &&
        isInFrontSector &&
        !isMockDetected;

    // If BLE session UUID is enabled on the session, student must pass Layer 1 number challenge
    if (activeSession != null && activeSession!.bleSessionUuid.isNotEmpty) {
      return basicReady && numberChallengeVerified;
    }
    return basicReady;
  }

  void setStudentDetails({required String name, required String roll}) {
    studentName = name;
    rollNo = roll;
  }

  void setOffsetMeters(double val) {
    offsetMeters = val;
    notifyListeners();
  }

  void toggleSimulateMock(bool val) {
    simulateMock = val;
    notifyListeners();
  }

  void toggleSimulateBeacon(bool val) {
    simulateBeaconFound = val;
    if (val) {
      _updateChallengeOptions(simulatedCode);
    } else {
      if (detectedBeacon == null) {
        challengeOptions.clear();
        numberChallengeVerified = false;
        verifiedCode = null;
      }
    }
    notifyListeners();
  }

  /// Verifies if student selected the right code broadcast by the faculty
  bool verifyNumberChallenge(int selectedNumber) {
    final targetCode = activeBeaconCode;
    if (targetCode == null) {
      challengeError = 'No beacon detected yet.';
      notifyListeners();
      return false;
    }

    if (selectedNumber == targetCode) {
      numberChallengeVerified = true;
      verifiedCode = selectedNumber;
      challengeError = null;
      notifyListeners();
      return true;
    } else {
      numberChallengeVerified = false;
      challengeError = 'Incorrect code! Listen carefully to the faculty.';
      notifyListeners();
      return false;
    }
  }

  void resetChallenge() {
    numberChallengeVerified = false;
    verifiedCode = null;
    challengeError = null;
    if (activeBeaconCode != null) {
      _updateChallengeOptions(activeBeaconCode!);
    }
    notifyListeners();
  }

  Future<AttendanceRecord> submitAttendance() async {
    if (studentName.trim().isEmpty || rollNo.trim().isEmpty) {
      throw Exception('Please fill in your Full Name and Roll Number.');
    }
    if (activeSession == null || !activeSession!.isActive) {
      throw Exception('No active attendance session found.');
    }
    if (activeSession!.isExpired) {
      throw Exception('The session has already expired.');
    }
    if (currentPosition == null) {
      throw Exception('Waiting for GPS coordinates.');
    }
    if (activeSession!.bleSessionUuid.isNotEmpty && !numberChallengeVerified) {
      throw Exception('Please complete the BLE Number Challenge first.');
    }

    isSubmitting = true;
    notifyListeners();

    try {
      final s = activeSession!;
      final dist = distanceMeters;
      final bear = bearingDegrees;
      final inSector = isInFrontSector;
      final mock = isMockDetected;
      final withinR = isWithinRadius;

      AttendanceStatus status;
      String remark;

      if (mock) {
        status = AttendanceStatus.flaggedMockLocation;
        remark = 'Mock / Fake GPS detected on student device!';
      } else if (!withinR) {
        status = AttendanceStatus.rejectedOutsideRadius;
        remark =
            'Outside radius: ${dist.toStringAsFixed(1)}m > ${s.radiusMeters.toInt()}m allowed.';
      } else if (s.directionalModeEnabled && !inSector) {
        status = AttendanceStatus.rejectedBehindFaculty;
        remark =
            'Student is behind teacher (bearing ${bear.toStringAsFixed(0)}°, allowed front zone: ±${(s.frontSectorDegrees / 2).toStringAsFixed(0)}°).';
      } else {
        status = AttendanceStatus.approved;
        remark =
            'Verified Layer 1 (BLE Code #$verifiedCode) & Layer 3 (GPS ${dist.toStringAsFixed(1)}m, ${inSector ? 'front sector' : '360°'}).';
      }

      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentName: studentName.trim(),
        rollNo: rollNo.trim(),
        studentLat: currentPosition!.latitude,
        studentLng: currentPosition!.longitude,
        distanceMeters: dist,
        bearingToStudent: bear,
        isMocked: mock,
        isInFrontSector: inSector,
        timestamp: DateTime.now(),
        status: status,
        remarks: remark,
        bleVerified: numberChallengeVerified,
        bleCodeUsed: verifiedCode,
      );

      await _firebaseService.submitAttendance(record);
      hasSubmitted = true;
      return record;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _positionSub?.cancel();
    _bleSub?.cancel();
    _bleScanner.dispose();
    super.dispose();
  }
}
