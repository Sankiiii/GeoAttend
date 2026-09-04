import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GeofenceAttendanceApp());
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------
enum AttendanceStatus {
  approved,
  rejectedOutsideRadius,
  flaggedMockLocation,
  sessionExpired,
  manuallyApproved,
  manuallyRejected,
}

extension AttendanceStatusX on AttendanceStatus {
  String get firebaseKey => name;

  static AttendanceStatus fromKey(String key) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == key,
      orElse: () => AttendanceStatus.approved,
    );
  }
}

class AttendanceSession {
  final String title;
  final String facultyName;
  final double facultyLat;
  final double facultyLng;
  final double radiusMeters;
  final DateTime startTime;
  final DateTime endTime;
  bool isActive;

  AttendanceSession({
    required this.title,
    required this.facultyName,
    required this.facultyLat,
    required this.facultyLng,
    required this.radiusMeters,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  bool get isExpired => DateTime.now().isAfter(endTime) || !isActive;

  Duration get remainingTime {
    if (isExpired) return Duration.zero;
    final diff = endTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'facultyName': facultyName,
        'facultyLat': facultyLat,
        'facultyLng': facultyLng,
        'radiusMeters': radiusMeters,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'isActive': isActive,
      };

  factory AttendanceSession.fromJson(Map<dynamic, dynamic> json) {
    return AttendanceSession(
      title: json['title'] as String? ?? 'Session',
      facultyName: json['facultyName'] as String? ?? 'Faculty',
      facultyLat: (json['facultyLat'] as num?)?.toDouble() ?? 0.0,
      facultyLng: (json['facultyLng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 50.0,
      startTime: DateTime.fromMillisecondsSinceEpoch(
          (json['startTime'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      endTime: DateTime.fromMillisecondsSinceEpoch(
          (json['endTime'] as int?) ??
              DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch),
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String studentName;
  final String rollNo;
  final double studentLat;
  final double studentLng;
  final double distanceMeters;
  final bool isMocked;
  final DateTime timestamp;
  AttendanceStatus status;
  String? remarks;

  AttendanceRecord({
    required this.id,
    required this.studentName,
    required this.rollNo,
    required this.studentLat,
    required this.studentLng,
    required this.distanceMeters,
    required this.isMocked,
    required this.timestamp,
    required this.status,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'rollNo': rollNo,
        'studentLat': studentLat,
        'studentLng': studentLng,
        'distanceMeters': distanceMeters,
        'isMocked': isMocked,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.firebaseKey,
        'remarks': remarks ?? '',
      };

  factory AttendanceRecord.fromJson(String id, Map<dynamic, dynamic> json) {
    return AttendanceRecord(
      id: id,
      studentName: json['studentName'] as String? ?? 'Unknown',
      rollNo: json['rollNo'] as String? ?? 'N/A',
      studentLat: (json['studentLat'] as num?)?.toDouble() ?? 0.0,
      studentLng: (json['studentLng'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      isMocked: json['isMocked'] as bool? ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      status: AttendanceStatusX.fromKey(json['status'] as String? ?? 'approved'),
      remarks: json['remarks'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// APP ENTRY
// ---------------------------------------------------------------------------
class GeofenceAttendanceApp extends StatelessWidget {
  const GeofenceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geofence Attendance Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RoleSelectorScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// ROLE SELECTOR SCREEN
// ---------------------------------------------------------------------------
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.school_rounded, size: 80, color: colorScheme.primary),
              const SizedBox(height: 20),
              const Text(
                'Geofenced Attendance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Real-Time Demo — Firebase Sync',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              const Text(
                'Who are you on this device?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.manage_accounts_rounded,
                title: 'Faculty / Teacher',
                subtitle: 'Start attendance session\nSet geofence radius\nView student submissions live',
                color: Colors.blue.shade700,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainAttendanceScreen(role: AppRole.faculty),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.person_pin_circle_rounded,
                title: 'Student',
                subtitle: 'View active session\nMark your attendance\nSee approval status',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainAttendanceScreen(role: AppRole.student),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Firebase Realtime Sync Active',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

enum AppRole { faculty, student }

// ---------------------------------------------------------------------------
// MAIN ATTENDANCE SCREEN (Firebase-backed)
// ---------------------------------------------------------------------------
class MainAttendanceScreen extends StatefulWidget {
  final AppRole role;
  const MainAttendanceScreen({super.key, required this.role});

  @override
  State<MainAttendanceScreen> createState() => _MainAttendanceScreenState();
}

class _MainAttendanceScreenState extends State<MainAttendanceScreen> {
  final _db = FirebaseDatabase.instance;
  DatabaseReference get _sessionRef => _db.ref('activeSession');
  DatabaseReference get _recordsRef => _db.ref('attendanceRecords');

  AttendanceSession? _activeSession;
  final List<AttendanceRecord> _records = [];
  Timer? _countdownTimer;
  StreamSubscription<DatabaseEvent>? _sessionSub;
  StreamSubscription<DatabaseEvent>? _recordsSub;

  @override
  void initState() {
    super.initState();
    _listenToSession();
    _listenToRecords();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _recordsSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSession != null && mounted) {
        if (_activeSession!.isExpired && _activeSession!.isActive) {
          _sessionRef.update({'isActive': false});
        }
        setState(() {});
      }
    });
  }

  void _listenToSession() {
    _sessionSub = _sessionRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) {
        setState(() => _activeSession = null);
        return;
      }
      try {
        setState(() => _activeSession = AttendanceSession.fromJson(data as Map<dynamic, dynamic>));
      } catch (_) {
        setState(() => _activeSession = null);
      }
    });
  }

  void _listenToRecords() {
    _recordsSub = _recordsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      final List<AttendanceRecord> newRecords = [];
      if (data != null && data is Map) {
        data.forEach((key, value) {
          try {
            newRecords.add(AttendanceRecord.fromJson(key.toString(), value as Map<dynamic, dynamic>));
          } catch (_) {}
        });
        newRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      setState(() {
        _records.clear();
        _records.addAll(newRecords);
      });
    });
  }

  Future<void> _createSession({
    required String title,
    required String facultyName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required int durationMinutes,
  }) async {
    final now = DateTime.now();
    final session = AttendanceSession(
      title: title,
      facultyName: facultyName,
      facultyLat: lat,
      facultyLng: lng,
      radiusMeters: radiusMeters,
      startTime: now,
      endTime: now.add(Duration(minutes: durationMinutes)),
      isActive: true,
    );
    await _recordsRef.remove();
    await _sessionRef.set(session.toJson());
  }

  Future<void> _endSession() async {
    await _sessionRef.update({'isActive': false});
  }

  Future<void> _submitAttendance(AttendanceRecord record) async {
    await _recordsRef.child(record.id).set(record.toJson());
  }

  Future<void> _updateRecordStatus(String recordId, AttendanceStatus newStatus, String remark) async {
    await _recordsRef.child(recordId).update({
      'status': newStatus.firebaseKey,
      'remarks': remark,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == AppRole.faculty) {
      return Scaffold(
        appBar: _buildAppBar('Faculty Panel', Icons.manage_accounts_rounded),
        body: FacultyPanelView(
          activeSession: _activeSession,
          records: _records,
          onCreateSession: _createSession,
          onEndSession: _endSession,
          onUpdateStatus: _updateRecordStatus,
        ),
      );
    } else {
      return Scaffold(
        appBar: _buildAppBar('Student Portal', Icons.person_pin_circle_rounded),
        body: StudentPortalView(
          activeSession: _activeSession,
          onSubmitAttendance: _submitAttendance,
        ),
      );
    }
  }

  AppBar _buildAppBar(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.swap_horiz),
        tooltip: 'Switch Role',
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectorScreen()),
          );
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  const Text('Firebase Live Sync', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
    );
  }
}

// ---------------------------------------------------------------------------
// 1. FACULTY PANEL VIEW
// ---------------------------------------------------------------------------
class FacultyPanelView extends StatefulWidget {
  final AttendanceSession? activeSession;
  final List<AttendanceRecord> records;
  final Future<void> Function({
    required String title,
    required String facultyName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required int durationMinutes,
  }) onCreateSession;
  final Future<void> Function() onEndSession;
  final Future<void> Function(String recordId, AttendanceStatus newStatus, String remark) onUpdateStatus;

  const FacultyPanelView({
    super.key,
    required this.activeSession,
    required this.records,
    required this.onCreateSession,
    required this.onEndSession,
    required this.onUpdateStatus,
  });

  @override
  State<FacultyPanelView> createState() => _FacultyPanelViewState();
}

class _FacultyPanelViewState extends State<FacultyPanelView> {
  Position? _facultyPosition;
  bool _isLoadingGPS = false;
  bool _isStartingSession = false;
  String? _gpsError;

  final _titleController = TextEditingController(text: 'Computer Networks - Lab 3');
  final _facultyNameController = TextEditingController(text: 'Prof. Sharma');
  double _radiusMeters = 30.0;
  int _durationMinutes = 5;

  @override
  void initState() {
    super.initState();
    _fetchFacultyLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _facultyNameController.dispose();
    super.dispose();
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
        distanceFilter: 0,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        distanceFilter: 0,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
  }

  Future<void> _fetchFacultyLocation() async {
    setState(() { _isLoadingGPS = true; _gpsError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _isLoadingGPS = false; _gpsError = 'GPS is turned off.'; });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _isLoadingGPS = false; _gpsError = 'Location permission denied.'; });
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(locationSettings: _buildLocationSettings());
      if (mounted) setState(() { _facultyPosition = position; _isLoadingGPS = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingGPS = false; _gpsError = e.toString(); });
    }
  }

  Future<void> _startNewSession() async {
    if (_facultyPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture faculty GPS location first!')),
      );
      return;
    }
    setState(() => _isStartingSession = true);
    await widget.onCreateSession(
      title: _titleController.text.trim().isEmpty ? 'Lecture Session' : _titleController.text.trim(),
      facultyName: _facultyNameController.text.trim().isEmpty ? 'Faculty' : _facultyNameController.text.trim(),
      lat: _facultyPosition!.latitude,
      lng: _facultyPosition!.longitude,
      radiusMeters: _radiusMeters,
      durationMinutes: _durationMinutes,
    );
    setState(() => _isStartingSession = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session started! Students can now mark attendance on their devices.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.activeSession;
    final isSessionRunning = session != null && session.isActive && !session.isExpired;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSessionRunning) ...[
            _buildActiveSessionBanner(session, colorScheme),
            const SizedBox(height: 16),
          ] else if (session != null && session.isExpired) ...[
            _buildExpiredBanner(session),
            const SizedBox(height: 16),
          ],
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_location_alt, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        isSessionRunning ? 'Configure Next Session' : 'Step 1: Start Attendance Session',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Session / Class Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.class_),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _facultyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Faculty / Teacher Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Classroom Center (Faculty GPS):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            IconButton(
                              icon: _isLoadingGPS
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 20),
                              onPressed: _isLoadingGPS ? null : _fetchFacultyLocation,
                            ),
                          ],
                        ),
                        if (_facultyPosition != null) ...[
                          Text(
                            'Lat: ${_facultyPosition!.latitude.toStringAsFixed(7)}, Lng: ${_facultyPosition!.longitude.toStringAsFixed(7)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text('Accuracy: ±${_facultyPosition!.accuracy.toStringAsFixed(1)}m', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ] else if (_gpsError != null) ...[
                          Text('GPS Error: $_gpsError', style: const TextStyle(color: Colors.red)),
                        ] else ...[
                          const Text('Acquiring GPS…'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Geofence Radius: ${_radiusMeters.toInt()} meters', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(value: _radiusMeters, min: 10, max: 150, divisions: 14, label: '${_radiusMeters.toInt()}m', onChanged: (val) => setState(() => _radiusMeters = val)),
                  Text('Session Duration: $_durationMinutes minutes', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(value: _durationMinutes.toDouble(), min: 1, max: 15, divisions: 14, label: '$_durationMinutes min', onChanged: (val) => setState(() => _durationMinutes = val.toInt())),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isStartingSession || _isLoadingGPS) ? null : _startNewSession,
                      icon: _isStartingSession
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_isStartingSession ? 'Saving to Firebase...' : 'Start Attendance Session', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (isSessionRunning) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async => await widget.onEndSession(),
                        icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                        label: const Text('End Session Now', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Attendance Submissions (${widget.records.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              if (isSessionRunning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.records.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No submissions yet.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('Student submissions will appear here in real-time.', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...widget.records.map((record) => _buildRecordCard(record, colorScheme)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(AttendanceSession session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_on, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text('Radius: ${session.radiusMeters.toInt()}m | Faculty: ${session.facultyName}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              const Text('Remaining', style: TextStyle(fontSize: 10)),
              Text(
                _formatDuration(session.remainingTime),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner(AttendanceSession session) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${session.title} — ENDED', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('${widget.records.length} total submissions recorded.', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record, ColorScheme colorScheme) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (record.status) {
      case AttendanceStatus.approved:
      case AttendanceStatus.manuallyApproved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = record.status == AttendanceStatus.manuallyApproved ? 'Manually Approved' : 'Approved';
        break;
      case AttendanceStatus.rejectedOutsideRadius:
      case AttendanceStatus.manuallyRejected:
      case AttendanceStatus.sessionExpired:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = record.status == AttendanceStatus.sessionExpired ? 'Expired' : record.status == AttendanceStatus.manuallyRejected ? 'Manually Rejected' : 'Outside Radius';
        break;
      case AttendanceStatus.flaggedMockLocation:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_rounded;
        statusLabel = 'Mock GPS Flagged';
        break;
    }

    final canReview = record.status == AttendanceStatus.flaggedMockLocation || record.status == AttendanceStatus.rejectedOutsideRadius;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.4), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withOpacity(0.12),
                  child: Text(
                    record.studentName.isNotEmpty ? record.studentName[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Roll No: ${record.rollNo}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                _buildBadge(statusLabel, statusIcon, statusColor),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _infoChip(Icons.social_distance, '${record.distanceMeters.toStringAsFixed(1)}m away', record.distanceMeters <= 50 ? Colors.green : Colors.red),
                _infoChip(record.isMocked ? Icons.location_off : Icons.location_on, record.isMocked ? 'Mock GPS' : 'Real GPS', record.isMocked ? Colors.orange : Colors.green),
                _infoChip(Icons.access_time, '${record.timestamp.hour.toString().padLeft(2,'0')}:${record.timestamp.minute.toString().padLeft(2,'0')}:${record.timestamp.second.toString().padLeft(2,'0')}', Colors.grey),
              ],
            ),
            if (record.remarks != null && record.remarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(record.remarks!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            if (canReview) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onUpdateStatus(record.id, AttendanceStatus.manuallyApproved, 'Manually approved by faculty after review'),
                      icon: const Icon(Icons.check, size: 16, color: Colors.green),
                      label: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onUpdateStatus(record.id, AttendanceStatus.manuallyRejected, 'Manually rejected by faculty'),
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. STUDENT PORTAL VIEW
// ---------------------------------------------------------------------------
class StudentPortalView extends StatefulWidget {
  final AttendanceSession? activeSession;
  final Future<void> Function(AttendanceRecord) onSubmitAttendance;

  const StudentPortalView({
    super.key,
    required this.activeSession,
    required this.onSubmitAttendance,
  });

  @override
  State<StudentPortalView> createState() => _StudentPortalViewState();
}

class _StudentPortalViewState extends State<StudentPortalView> {
  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();

  Position? _studentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isLoadingGPS = false;
  bool _isSubmitting = false;
  String? _gpsError;
  bool _hasSubmitted = false;

  bool _simulateMockGps = false;
  double _simulateOffsetMeters = 0.0;

  @override
  void initState() {
    super.initState();
    _startLiveStudentGPS();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _nameController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, forceLocationManager: true, intervalDuration: const Duration(seconds: 1), distanceFilter: 0);
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(accuracy: LocationAccuracy.bestForNavigation, activityType: ActivityType.fitness, pauseLocationUpdatesAutomatically: false, distanceFilter: 0);
    }
    return const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
  }

  Future<void> _startLiveStudentGPS() async {
    setState(() { _isLoadingGPS = true; _gpsError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _isLoadingGPS = false; _gpsError = 'GPS is disabled.'; });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() { _isLoadingGPS = false; _gpsError = 'Location permission denied.'; });
          return;
        }
      }
      _positionStream = Geolocator.getPositionStream(locationSettings: _buildLocationSettings()).listen(
        (Position pos) {
          if (mounted) setState(() { _studentPosition = pos; _isLoadingGPS = false; _gpsError = null; });
        },
        onError: (err) {
          if (mounted) setState(() { _isLoadingGPS = false; _gpsError = err.toString(); });
        },
      );
    } catch (e) {
      if (mounted) setState(() { _isLoadingGPS = false; _gpsError = e.toString(); });
    }
  }

  double _calculateDistance() {
    if (_studentPosition == null || widget.activeSession == null) return 0.0;
    final session = widget.activeSession!;
    return Geolocator.distanceBetween(session.facultyLat, session.facultyLng, _studentPosition!.latitude, _studentPosition!.longitude) + _simulateOffsetMeters;
  }

  Future<void> _markAttendance() async {
    final name = _nameController.text.trim();
    final rollNo = _rollNoController.text.trim();

    if (name.isEmpty || rollNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your Full Name and Roll Number first!'), backgroundColor: Colors.orange));
      return;
    }

    final session = widget.activeSession;
    if (session == null) {
      _showResultDialog(title: 'No Active Session', message: 'There is no active attendance session.\nAsk your faculty to start the session from their device.', isSuccess: false);
      return;
    }

    if (session.isExpired) {
      _showResultDialog(title: 'Session Expired', message: 'The attendance session has ended.', isSuccess: false);
      return;
    }

    if (_studentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acquiring GPS location, please wait...')));
      return;
    }

    setState(() => _isSubmitting = true);

    final isMock = _simulateMockGps || _studentPosition!.isMocked;
    final distance = _calculateDistance();
    final isWithinRadius = distance <= session.radiusMeters;

    AttendanceStatus status;
    String remarks;

    if (isMock) {
      status = AttendanceStatus.flaggedMockLocation;
      remarks = 'Mock/Fake GPS app detected on student device!';
    } else if (isWithinRadius) {
      status = AttendanceStatus.approved;
      remarks = 'Verified inside geofence radius (${distance.toStringAsFixed(1)}m)';
    } else {
      status = AttendanceStatus.rejectedOutsideRadius;
      remarks = 'Outside classroom boundary (${distance.toStringAsFixed(1)}m > ${session.radiusMeters.toInt()}m)';
    }

    final record = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentName: name,
      rollNo: rollNo,
      studentLat: _studentPosition!.latitude,
      studentLng: _studentPosition!.longitude,
      distanceMeters: distance,
      isMocked: isMock,
      timestamp: DateTime.now(),
      status: status,
      remarks: remarks,
    );

    await widget.onSubmitAttendance(record);
    setState(() { _isSubmitting = false; _hasSubmitted = true; });

    if (mounted) {
      if (status == AttendanceStatus.approved) {
        _showResultDialog(title: 'Attendance Marked! ✅', message: 'You are verified inside the classroom.\n\n• Distance: ${distance.toStringAsFixed(1)}m\n• Allowed: ${session.radiusMeters.toInt()}m\n• Mock GPS: Clean\n\nYour faculty can see this submission instantly on their device.', isSuccess: true);
      } else if (status == AttendanceStatus.flaggedMockLocation) {
        _showResultDialog(title: 'Suspicious Location Flagged ⚠️', message: 'Mock or Fake GPS detected. Submission flagged and sent to faculty for manual review.', isSuccess: false);
      } else {
        _showResultDialog(title: 'Outside Classroom Boundary ❌', message: 'You are ${distance.toStringAsFixed(1)}m from classroom.\nMaximum allowed: ${session.radiusMeters.toInt()}m.\n\nAttendance rejected.', isSuccess: false);
      }
    }
  }

  void _showResultDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red, size: 48),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s remaining';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final session = widget.activeSession;
    final distance = _calculateDistance();
    final isWithinRadius = session != null && distance <= session.radiusMeters;
    final isMock = _simulateMockGps || (_studentPosition?.isMocked ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Session Card (synced from Firebase)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: (session != null && session.isActive && !session.isExpired) ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Live Session from Faculty Device', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 20),
                  if (session == null) ...[
                    const Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Expanded(child: Text('Waiting for faculty to start a session on their device…', style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  ] else ...[
                    _sessionInfoRow(Icons.class_, 'Session', session.title),
                    _sessionInfoRow(Icons.person, 'Faculty', session.facultyName),
                    _sessionInfoRow(Icons.radar, 'Geofence Radius', '${session.radiusMeters.toInt()} meters'),
                    _sessionInfoRow(
                      session.isExpired ? Icons.lock_clock : Icons.timer,
                      'Status',
                      session.isExpired ? 'ENDED' : session.isActive ? 'ACTIVE — ${_formatRemaining(session.remainingTime)}' : 'INACTIVE',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Student Identity
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(labelText: 'Roll Number / Student ID *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Geofence Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Live Geofence Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  if (session == null || !session.isActive || session.isExpired) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade700)),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(child: Text('No active session yet.\nFaculty must start a session from their phone.')),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isWithinRadius ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isWithinRadius ? Colors.green : Colors.red, width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isWithinRadius ? Icons.check_circle : Icons.not_listed_location, color: isWithinRadius ? Colors.green : Colors.red, size: 28),
                              const SizedBox(width: 10),
                              Text('${distance.toStringAsFixed(1)} m', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: isWithinRadius ? Colors.green.shade800 : Colors.red.shade800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isWithinRadius ? '✓ INSIDE classroom radius (Allowed: ${session.radiusMeters.toInt()}m)' : '✗ OUTSIDE classroom radius (Allowed: ${session.radiusMeters.toInt()}m)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isWithinRadius ? Colors.green.shade800 : Colors.red.shade800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: isMock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(isMock ? Icons.warning_rounded : Icons.shield_outlined, size: 20, color: isMock ? Colors.red : Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isMock ? 'Fake / Mock GPS location detected!' : 'Hardware GPS Verified — No Mocking',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMock ? Colors.red.shade800 : Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_studentPosition != null)
                    Text('Your GPS: ${_studentPosition!.latitude.toStringAsFixed(6)}, ${_studentPosition!.longitude.toStringAsFixed(6)} (±${_studentPosition!.accuracy.toStringAsFixed(1)}m)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))
                  else if (_isLoadingGPS)
                    const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Reading satellite GPS…', style: TextStyle(fontSize: 12))])
                  else if (_gpsError != null)
                    Text('GPS Error: $_gpsError', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_hasSubmitted) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.shade300)),
              child: const Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(child: Text('Attendance submitted to Firebase.\nCheck the Faculty Panel on the other device to see your record instantly.', style: TextStyle(fontSize: 13, color: Colors.blue))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_studentPosition == null || _isSubmitting) ? null : _markAttendance,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.touch_app, size: 24),
              label: Text(_isSubmitting ? 'Saving to Firebase...' : 'Mark My Attendance', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isWithinRadius ? Colors.green.shade700 : colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Demo Tools
          Card(
            elevation: 0,
            color: colorScheme.primary.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: colorScheme.primary.withOpacity(0.2))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text('Demo Testing Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Simulate distance offset or mock GPS for demo:', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(label: const Text('0m (Real)'), selected: _simulateOffsetMeters == 0.0, onSelected: (val) => setState(() => _simulateOffsetMeters = 0.0)),
                      ChoiceChip(label: const Text('+15m (Inside)'), selected: _simulateOffsetMeters == 15.0, onSelected: (val) => setState(() => _simulateOffsetMeters = 15.0)),
                      ChoiceChip(label: const Text('+120m (Outside)'), selected: _simulateOffsetMeters == 120.0, onSelected: (val) => setState(() => _simulateOffsetMeters = 120.0)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulate Mock/Fake GPS', style: TextStyle(fontSize: 12)),
                    value: _simulateMockGps,
                    onChanged: (val) => setState(() => _simulateMockGps = val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sessionInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
