import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import '../services/location_service.dart';
import '../services/firebase_service.dart';

class FacultyController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // GPS State
  Position? currentPosition;
  bool isLoadingGps = false;
  String? gpsError;

  // Session Config State
  String title = 'CS101 — Lecture';
  String facultyName = 'Prof. Sharma';
  double radiusMeters = 30.0;
  int durationMinutes = 5;
  bool directionalMode = false;
  double lockedHeading = 0.0; // 0°=N, 90°=E, 180°=S, 270°=W
  double sectorDegrees = 180.0; // 30°–360°

  // Action states
  bool isStartingSession = false;

  // Live session & submissions
  AttendanceSession? activeSession;
  List<AttendanceRecord> records = [];

  StreamSubscription<AttendanceSession?>? _sessionSub;
  StreamSubscription<List<AttendanceRecord>>? _recordsSub;
  Timer? _ticker;

  void init() {
    fetchGps();
    _subscribeFirebase();
    _startTicker();
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
        }
        notifyListeners();
      }
    });
  }

  Future<void> fetchGps() async {
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

  void setTitle(String val) {
    title = val;
  }

  void setFacultyName(String val) {
    facultyName = val;
  }

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

  Future<void> startSession() async {
    if (currentPosition == null) {
      throw Exception('Please acquire GPS coordinates first.');
    }

    isStartingSession = true;
    notifyListeners();

    try {
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
      );

      await _firebaseService.createSession(session);
    } finally {
      isStartingSession = false;
      notifyListeners();
    }
  }

  Future<void> endSession() async {
    await _firebaseService.endSession();
  }

  Future<void> reviewSubmission(
      String recordId, AttendanceStatus status, String remark) async {
    await _firebaseService.updateRecordStatus(recordId, status, remark);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _recordsSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
