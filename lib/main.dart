import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

import 'firebase_options.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const GeofenceAttendanceApp());
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum AttendanceStatus {
  approved,
  rejectedOutsideRadius,
  rejectedBehindFaculty,
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

  // Directional geofence fields
  final bool directionalModeEnabled;
  final double facultyHeading;       // 0–360° compass direction faculty faces
  final double frontSectorDegrees;   // configurable arc width (30°–360°)

  AttendanceSession({
    required this.title,
    required this.facultyName,
    required this.facultyLat,
    required this.facultyLng,
    required this.radiusMeters,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.directionalModeEnabled = false,
    this.facultyHeading = 0.0,
    this.frontSectorDegrees = 180.0,
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
        'directionalModeEnabled': directionalModeEnabled,
        'facultyHeading': facultyHeading,
        'frontSectorDegrees': frontSectorDegrees,
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
              DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch),
      isActive: json['isActive'] as bool? ?? false,
      directionalModeEnabled:
          json['directionalModeEnabled'] as bool? ?? false,
      facultyHeading: (json['facultyHeading'] as num?)?.toDouble() ?? 0.0,
      frontSectorDegrees:
          (json['frontSectorDegrees'] as num?)?.toDouble() ?? 180.0,
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
  final double bearingToStudent;
  final bool isMocked;
  final bool isInFrontSector;
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
    required this.bearingToStudent,
    required this.isMocked,
    required this.isInFrontSector,
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
        'bearingToStudent': bearingToStudent,
        'isMocked': isMocked,
        'isInFrontSector': isInFrontSector,
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
      bearingToStudent:
          (json['bearingToStudent'] as num?)?.toDouble() ?? 0.0,
      isMocked: json['isMocked'] as bool? ?? false,
      isInFrontSector: json['isInFrontSector'] as bool? ?? true,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      status:
          AttendanceStatusX.fromKey(json['status'] as String? ?? 'approved'),
      remarks: json['remarks'] as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BEARING / DIRECTION UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

/// Calculates compass bearing (0–360°) from point A → point B.
double calculateBearing(
    double lat1, double lon1, double lat2, double lon2) {
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final lat1Rad = lat1 * math.pi / 180.0;
  final lat2Rad = lat2 * math.pi / 180.0;
  final y = math.sin(dLon) * math.cos(lat2Rad);
  final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
      math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
  final bearing = math.atan2(y, x) * 180.0 / math.pi;
  return (bearing + 360.0) % 360.0;
}

/// Returns true if [bearingToStudent] falls within the front sector
/// defined by [facultyHeading] ± [sectorDegrees]/2.
bool isStudentInFrontSector(
    double facultyHeading, double bearingToStudent, double sectorDegrees) {
  double diff = (bearingToStudent - facultyHeading + 360.0) % 360.0;
  if (diff > 180.0) diff = 360.0 - diff;
  return diff <= sectorDegrees / 2.0;
}

/// Returns a human-readable direction label for a compass heading.
String headingToLabel(double heading) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
  return dirs[((heading + 22.5) / 45).floor() % 8];
}

// ═══════════════════════════════════════════════════════════════════════════
// APP ROOT
// ═══════════════════════════════════════════════════════════════════════════

class GeofenceAttendanceApp extends StatelessWidget {
  const GeofenceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoAttendance',
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

// ═══════════════════════════════════════════════════════════════════════════
// ROLE SELECTOR
// ═══════════════════════════════════════════════════════════════════════════

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.school_rounded, size: 80, color: colorScheme.primary),
              const SizedBox(height: 18),
              const Text(
                'GeoAttendance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Firebase Realtime Sync',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 48),
              const Text(
                'Select your role on this device',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.manage_accounts_rounded,
                title: 'Faculty / Teacher',
                subtitle:
                    'Start session • Set geofence • View live submissions',
                color: Colors.blue.shade700,
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const MainScreen(role: AppRole.faculty))),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.person_pin_circle_rounded,
                title: 'Student',
                subtitle:
                    'View session • Mark attendance • See result instantly',
                color: Colors.green.shade700,
                onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const MainScreen(role: AppRole.student))),
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

enum AppRole { faculty, student }

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN — Firebase state manager
// ═══════════════════════════════════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  final AppRole role;
  const MainScreen({super.key, required this.role});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _db = FirebaseDatabase.instance;
  DatabaseReference get _sessionRef => _db.ref('activeSession');
  DatabaseReference get _recordsRef => _db.ref('attendanceRecords');

  AttendanceSession? _session;
  final List<AttendanceRecord> _records = [];
  Timer? _tickTimer;
  StreamSubscription<DatabaseEvent>? _sessionSub;
  StreamSubscription<DatabaseEvent>? _recordsSub;

  @override
  void initState() {
    super.initState();
    _listenSession();
    _listenRecords();
    // 1-second tick to refresh countdown
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_session != null && _session!.isActive && _session!.isExpired) {
        _sessionRef.update({'isActive': false}).catchError((_) {});
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _recordsSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _listenSession() {
    _sessionSub = _sessionRef.onValue.listen(
      (event) {
        if (!mounted) return;
        final data = event.snapshot.value;
        if (data == null) {
          setState(() => _session = null);
          return;
        }
        try {
          setState(() =>
              _session = AttendanceSession.fromJson(data as Map<dynamic, dynamic>));
        } catch (e) {
          debugPrint('Session parse error: $e');
          setState(() => _session = null);
        }
      },
      onError: (e) => debugPrint('Session listen error: $e'),
    );
  }

  void _listenRecords() {
    _recordsSub = _recordsRef.onValue.listen(
      (event) {
        if (!mounted) return;
        final data = event.snapshot.value;
        final newRecords = <AttendanceRecord>[];
        if (data != null && data is Map) {
          for (final entry in data.entries) {
            try {
              newRecords.add(AttendanceRecord.fromJson(
                  entry.key.toString(),
                  entry.value as Map<dynamic, dynamic>));
            } catch (e) {
              debugPrint('Record parse error: $e');
            }
          }
          newRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
        setState(() {
          _records
            ..clear()
            ..addAll(newRecords);
        });
      },
      onError: (e) => debugPrint('Records listen error: $e'),
    );
  }

  Future<void> createSession(AttendanceSession session) async {
    try {
      await _recordsRef.remove();
      await _sessionRef.set(session.toJson());
    } catch (e) {
      debugPrint('Create session error: $e');
      rethrow;
    }
  }

  Future<void> endSession() async {
    try {
      await _sessionRef.update({'isActive': false});
    } catch (e) {
      debugPrint('End session error: $e');
      rethrow;
    }
  }

  Future<void> submitRecord(AttendanceRecord record) async {
    try {
      await _recordsRef.child(record.id).set(record.toJson());
    } catch (e) {
      debugPrint('Submit record error: $e');
      rethrow;
    }
  }

  Future<void> updateRecordStatus(
      String id, AttendanceStatus status, String remark) async {
    try {
      await _recordsRef.child(id).update({
        'status': status.firebaseKey,
        'remarks': remark,
      });
    } catch (e) {
      debugPrint('Update status error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz_rounded),
          tooltip: 'Switch Role',
          onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const RoleSelectorScreen())),
        ),
        title: Column(
          children: [
            Text(
              widget.role == AppRole.faculty
                  ? 'Faculty Panel'
                  : 'Student Portal',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('Firebase Live',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: widget.role == AppRole.faculty
          ? FacultyPanel(
              session: _session,
              records: _records,
              onCreateSession: createSession,
              onEndSession: endSession,
              onUpdateStatus: updateRecordStatus,
            )
          : StudentPanel(
              session: _session,
              onSubmit: submitRecord,
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FACULTY PANEL
// ═══════════════════════════════════════════════════════════════════════════

class FacultyPanel extends StatefulWidget {
  final AttendanceSession? session;
  final List<AttendanceRecord> records;
  final Future<void> Function(AttendanceSession) onCreateSession;
  final Future<void> Function() onEndSession;
  final Future<void> Function(String, AttendanceStatus, String) onUpdateStatus;

  const FacultyPanel({
    super.key,
    required this.session,
    required this.records,
    required this.onCreateSession,
    required this.onEndSession,
    required this.onUpdateStatus,
  });

  @override
  State<FacultyPanel> createState() => _FacultyPanelState();
}

class _FacultyPanelState extends State<FacultyPanel> {
  // GPS
  Position? _pos;
  bool _gpsLoading = false;
  String? _gpsError;

  // Compass / direction — manual slider (works on all devices)
  double _lockedHeading = 0.0; // 0°=North, 90°=East, 180°=South, 270°=West


  // Session config
  final _titleCtrl = TextEditingController(text: 'CS101 — Lecture');
  final _nameCtrl = TextEditingController(text: 'Prof. Sharma');
  double _radiusMeters = 30.0;
  int _durationMinutes = 5;
  bool _directionalMode = false;
  double _sectorDegrees = 180.0; // configurable: 30°–360°

  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _fetchGPS();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }



  // ── GPS ──────────────────────────────────────────────────────────────────

  LocationSettings _locationSettings() {
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
        accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
  }

  Future<void> _fetchGPS() async {
    setState(() {
      _gpsLoading = true;
      _gpsError = null;
    });
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() {
          _gpsLoading = false;
          _gpsError = 'GPS is turned off. Please enable it in Settings.';
        });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _gpsLoading = false;
          _gpsError = perm == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable from Settings.'
              : 'Location permission denied.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings());
      if (mounted) setState(() {
        _pos = pos;
        _gpsLoading = false;
      });
    } on LocationServiceDisabledException {
      if (mounted) setState(() {
        _gpsLoading = false;
        _gpsError = 'Location service disabled.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _gpsLoading = false;
        _gpsError = 'GPS Error: ${e.toString()}';
      });
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    if (_pos == null) {
      _snack('Capture GPS location first!');
      return;
    }


    setState(() => _starting = true);
    try {
      final now = DateTime.now();
      final session = AttendanceSession(
        title: _titleCtrl.text.trim().isEmpty
            ? 'Lecture Session'
            : _titleCtrl.text.trim(),
        facultyName: _nameCtrl.text.trim().isEmpty
            ? 'Faculty'
            : _nameCtrl.text.trim(),
        facultyLat: _pos!.latitude,
        facultyLng: _pos!.longitude,
        radiusMeters: _radiusMeters,
        startTime: now,
        endTime: now.add(Duration(minutes: _durationMinutes)),
        isActive: true,
        directionalModeEnabled: _directionalMode,
        facultyHeading: _lockedHeading,
        frontSectorDegrees: _directionalMode ? _sectorDegrees : 360.0,
      );
      await widget.onCreateSession(session);
      _snack(
        _directionalMode
            ? 'Session started! Directional mode ON — only front ${_sectorDegrees.toInt()}° zone is active.'
            : 'Session started! Full 360° geofence is active.',
        isError: false,
      );
    } catch (e) {
      _snack('Failed to start session: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: const Duration(seconds: 4),
    ));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = widget.session;
    final running = session != null && session.isActive && !session.isExpired;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Session status banner ──
          if (running) _activeBanner(session, cs),
          if (!running && session != null && session.isExpired)
            _expiredBanner(session),
          if (running || (session != null && session.isExpired))
            const SizedBox(height: 14),

          // ── Session config card ──
          _configCard(cs, running),
          const SizedBox(height: 20),

          // ── Submissions ──
          _submissionsHeader(cs, running),
          const SizedBox(height: 8),
          if (widget.records.isEmpty) _emptyState() 
          else ...widget.records.map((r) => _recordCard(r, cs)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Config card ───────────────────────────────────────────────────────────

  Widget _configCard(ColorScheme cs, bool running) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.add_location_alt_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                running ? 'Configure Next Session' : 'Step 1: Start Session',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
            const Divider(height: 24),

            // Title & Name
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Class / Session Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Faculty Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // GPS box
            _gpsBox(cs),
            const SizedBox(height: 16),

            // Radius slider
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Geofence Radius',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_radiusMeters.toInt()} m',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ),
            ]),
            Slider(
              value: _radiusMeters,
              min: 10,
              max: 200,
              divisions: 38,
              onChanged: (v) => setState(() => _radiusMeters = v),
            ),

            // Duration slider
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Session Duration',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_durationMinutes min',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ),
            ]),
            Slider(
              value: _durationMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => setState(() => _durationMinutes = v.toInt()),
            ),
            const SizedBox(height: 8),

            // ── Directional mode toggle ──────────────────────────────────
            Card(
              elevation: 0,
              color: _directionalMode
                  ? Colors.blue.withOpacity(0.07)
                  : Colors.grey.withOpacity(0.07),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: _directionalMode
                          ? cs.primary.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.2))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        '🧭 Directional Mode (Front-Side Only)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Only students in front of you can mark attendance',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _directionalMode,
                      onChanged: (v) => setState(() => _directionalMode = v),
                    ),

                    if (_directionalMode) ...[
                      const Divider(height: 16),

                      // ── Facing Direction slider ──────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Facing Direction',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(
                                  angle: _lockedHeading * math.pi / 180,
                                  child: const Icon(
                                      Icons.navigation_rounded,
                                      size: 16,
                                      color: Colors.orange),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_lockedHeading.toInt()}°  ${headingToLabel(_lockedHeading)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _lockedHeading,
                        min: 0,
                        max: 359,
                        divisions: 359,
                        activeColor: Colors.orange,
                        onChanged: (v) =>
                            setState(() => _lockedHeading = v),
                      ),
                      Text(
                        'Drag to set which direction you face  (0°=N  90°=E  180°=S  270°=W)',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // ── Sector angle slider ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Front Zone Width',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _sectorDegrees >= 360
                                  ? '360° (Full Circle)'
                                  : '${_sectorDegrees.toInt()}° arc',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _sectorDegrees,
                        min: 30,
                        max: 360,
                        divisions: 33,
                        onChanged: (v) => setState(() => _sectorDegrees = v),
                      ),
                      // Sector description
                      Text(
                        _sectorDescription(_sectorDegrees),
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Visual sector diagram
                      Center(
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: CustomPaint(
                            painter: SectorDiagramPainter(
                              sectorDegrees: _sectorDegrees,
                              headingDeg: _lockedHeading,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),


                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Start button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _starting ? null : _startSession,
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _starting ? 'Saving to Firebase…' : 'Start Attendance Session',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // End session button
            if (widget.session != null &&
                widget.session!.isActive &&
                !widget.session!.isExpired) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await widget.onEndSession();
                    } catch (e) {
                      _snack('Failed to end session: $e');
                    }
                  },
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Colors.red),
                  label: const Text('End Session Now',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── GPS box ────────────────────────────────────────────────────────────

  Widget _gpsBox(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Classroom GPS (Faculty Location)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              iconSize: 20,
              icon: _gpsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              onPressed: _gpsLoading ? null : _fetchGPS,
              tooltip: 'Refresh GPS',
            ),
          ]),
          if (_pos != null) ...[
            Text(
              'Lat: ${_pos!.latitude.toStringAsFixed(7)}\nLng: ${_pos!.longitude.toStringAsFixed(7)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text('Accuracy: ±${_pos!.accuracy.toStringAsFixed(1)} m',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ] else if (_gpsError != null)
            Text(_gpsError!,
                style: const TextStyle(color: Colors.red, fontSize: 12))
          else
            const Text('Acquiring GPS…', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }


  // ── Sector description helper ──────────────────────────────────────────

  String _sectorDescription(double deg) {
    if (deg >= 360) return 'Full 360° circle — no directional restriction';
    if (deg >= 270) return 'Three-quarter arc — very wide front zone';
    if (deg >= 180) return 'Half-circle (${deg.toInt()}°) — students must be in front';
    if (deg >= 90)
      return 'Quarter-arc (${deg.toInt()}°) — narrow front zone, very strict';
    return 'Very narrow (${deg.toInt()}°) — students must face faculty directly';
  }

  // ── Banners ────────────────────────────────────────────────────────────

  Widget _activeBanner(AttendanceSession s, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green, width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.radio_button_on_rounded, color: Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            Text(
              '${s.radiusMeters.toInt()}m radius'
              '${s.directionalModeEnabled ? ' • Directional ${s.frontSectorDegrees.toInt()}° ${headingToLabel(s.facultyHeading)}' : ' • Full 360°'}',
              style: const TextStyle(fontSize: 12),
            ),
          ]),
        ),
        Column(children: [
          const Text('Left', style: TextStyle(fontSize: 10)),
          Text(_fmt(s.remainingTime),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green)),
        ]),
      ]),
    );
  }

  Widget _expiredBanner(AttendanceSession s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(children: [
        const Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.title} — ENDED',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            Text('${widget.records.length} submissions recorded.',
                style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ── Submissions ────────────────────────────────────────────────────────

  Widget _submissionsHeader(ColorScheme cs, bool running) {
    return Row(children: [
      Icon(Icons.list_alt_rounded, color: cs.primary),
      const SizedBox(width: 8),
      Text('Submissions (${widget.records.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(width: 6),
      if (running)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.green, borderRadius: BorderRadius.circular(10)),
          child: const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
    ]);
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(children: [
        Icon(Icons.inbox_rounded, size: 44, color: Colors.grey),
        SizedBox(height: 8),
        Text('No submissions yet',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
        Text('Student entries will appear here in real-time.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _recordCard(AttendanceRecord r, ColorScheme cs) {
    final sessionRadius = widget.session?.radiusMeters ?? 50.0;
    final isWithinRadius = r.distanceMeters <= sessionRadius;

    // Color/icon/label based on status
    Color sc;
    IconData si;
    String sl;
    switch (r.status) {
      case AttendanceStatus.approved:
        sc = Colors.green; si = Icons.check_circle_rounded; sl = 'Approved';
        break;
      case AttendanceStatus.manuallyApproved:
        sc = Colors.green; si = Icons.check_circle_rounded; sl = 'Manually Approved';
        break;
      case AttendanceStatus.rejectedOutsideRadius:
        sc = Colors.red; si = Icons.cancel_rounded; sl = 'Outside Radius';
        break;
      case AttendanceStatus.rejectedBehindFaculty:
        sc = Colors.deepOrange; si = Icons.back_hand_rounded; sl = 'Behind Teacher';
        break;
      case AttendanceStatus.manuallyRejected:
        sc = Colors.red; si = Icons.cancel_rounded; sl = 'Manually Rejected';
        break;
      case AttendanceStatus.sessionExpired:
        sc = Colors.grey; si = Icons.timer_off_rounded; sl = 'Session Expired';
        break;
      case AttendanceStatus.flaggedMockLocation:
        sc = Colors.orange; si = Icons.warning_rounded; sl = 'Mock GPS Detected';
        break;
    }

    final canReview = r.status == AttendanceStatus.flaggedMockLocation ||
        r.status == AttendanceStatus.rejectedOutsideRadius ||
        r.status == AttendanceStatus.rejectedBehindFaculty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.withOpacity(0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primary.withOpacity(0.12),
              child: Text(
                r.studentName.isNotEmpty
                    ? r.studentName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: cs.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(r.studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Roll: ${r.rollNo}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ]),
            ),
            _badge(sl, si, sc),
          ]),
          const SizedBox(height: 10),

          // ── Prominent Meter Distance Box ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isWithinRadius
                  ? Colors.green.withOpacity(0.08)
                  : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWithinRadius
                    ? Colors.green.withOpacity(0.25)
                    : Colors.red.withOpacity(0.25),
              ),
            ),
            child: Row(children: [
              Icon(
                isWithinRadius ? Icons.straighten_rounded : Icons.warning_amber_rounded,
                size: 18,
                color: isWithinRadius ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                    children: [
                      const TextSpan(text: 'Distance to You: '),
                      TextSpan(
                        text: '${r.distanceMeters.toStringAsFixed(1)} m  ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isWithinRadius ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                      TextSpan(
                        text: isWithinRadius
                            ? '(Inside ${sessionRadius.toInt()}m limit • ${(sessionRadius - r.distanceMeters).toStringAsFixed(1)}m buffer)'
                            : '(Exceeds ${sessionRadius.toInt()}m limit by ${(r.distanceMeters - sessionRadius).toStringAsFixed(1)}m)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isWithinRadius ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Info chips
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(
                r.isInFrontSector
                    ? Icons.front_hand_rounded
                    : Icons.back_hand_rounded,
                r.isInFrontSector
                    ? 'Front Zone (${r.bearingToStudent.toStringAsFixed(0)}° ${headingToLabel(r.bearingToStudent)})'
                    : 'Behind Teacher (${r.bearingToStudent.toStringAsFixed(0)}° ${headingToLabel(r.bearingToStudent)})',
                r.isInFrontSector ? Colors.blue.shade700 : Colors.deepOrange),
            _chip(
                r.isMocked ? Icons.location_off_rounded : Icons.verified_user_rounded,
                r.isMocked ? 'Mock GPS Detected' : 'Hardware GPS',
                r.isMocked ? Colors.orange.shade800 : Colors.green.shade700),
            _chip(Icons.access_time_rounded,
                '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}:${r.timestamp.second.toString().padLeft(2, '0')}',
                Colors.grey.shade700),
          ]),

          if (r.remarks != null && r.remarks!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.remarks!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Review buttons
          if (canReview) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await widget.onUpdateStatus(r.id,
                          AttendanceStatus.manuallyApproved,
                          'Manually approved by faculty');
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.check_rounded,
                      size: 15, color: Colors.green),
                  label: const Text('Approve',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await widget.onUpdateStatus(r.id,
                          AttendanceStatus.manuallyRejected,
                          'Manually rejected by faculty');
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.close_rounded,
                      size: 15, color: Colors.red),
                  label: const Text('Reject',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _badge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTOR DIAGRAM — CustomPainter
// ═══════════════════════════════════════════════════════════════════════════

class SectorDiagramPainter extends CustomPainter {
  final double sectorDegrees;
  final double headingDeg;

  SectorDiagramPainter({
    required this.sectorDegrees,
    required this.headingDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle (back zone — red)
    canvas.drawCircle(
        center, radius, Paint()..color = Colors.red.withOpacity(0.12));

    // Front sector (green)
    if (sectorDegrees < 360) {
      final startAngle =
          (headingDeg - sectorDegrees / 2 - 90) * math.pi / 180;
      final sweepAngle = sectorDegrees * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = Colors.green.withOpacity(0.25),
      );
    } else {
      // Full circle green
      canvas.drawCircle(
          center, radius, Paint()..color = Colors.green.withOpacity(0.2));
    }

    // Outer circle border
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Faculty arrow (direction pointer)
    final arrowAngle = (headingDeg - 90) * math.pi / 180;
    final arrowEnd = Offset(
      center.dx + (radius * 0.7) * math.cos(arrowAngle),
      center.dy + (radius * 0.7) * math.sin(arrowAngle),
    );
    canvas.drawLine(
      center,
      arrowEnd,
      Paint()
        ..color = Colors.orange
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Faculty dot
    canvas.drawCircle(
        center,
        8,
        Paint()
          ..color = Colors.orange);

    // Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, Offset offset, Color color) {
      tp.text = TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
    }

    drawLabel('🎓', center - const Offset(0, 0), Colors.transparent);

    // N/S/E/W compass labels
    drawLabel('N', center + Offset(0, -radius + 12), Colors.grey.shade600);
    drawLabel('S', center + Offset(0, radius - 12), Colors.grey.shade600);
    drawLabel('E', center + Offset(radius - 12, 0), Colors.grey.shade600);
    drawLabel('W', center + Offset(-radius + 12, 0), Colors.grey.shade600);
  }

  @override
  bool shouldRepaint(SectorDiagramPainter old) =>
      old.sectorDegrees != sectorDegrees ||
      old.headingDeg != headingDeg;
}

// ═══════════════════════════════════════════════════════════════════════════
// STUDENT PANEL
// ═══════════════════════════════════════════════════════════════════════════

class StudentPanel extends StatefulWidget {
  final AttendanceSession? session;
  final Future<void> Function(AttendanceRecord) onSubmit;

  const StudentPanel({super.key, required this.session, required this.onSubmit});

  @override
  State<StudentPanel> createState() => _StudentPanelState();
}

class _StudentPanelState extends State<StudentPanel> {
  final _nameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();

  Position? _pos;
  StreamSubscription<Position>? _posSub;
  bool _gpsLoading = false;
  String? _gpsError;

  bool _submitting = false;
  bool _submitted = false;

  // Demo tools
  double _offsetMeters = 0.0;
  bool _simulateMock = false;

  @override
  void initState() {
    super.initState();
    _startGPS();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _nameCtrl.dispose();
    _rollCtrl.dispose();
    super.dispose();
  }

  LocationSettings _locationSettings() {
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
        accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
  }

  Future<void> _startGPS() async {
    setState(() { _gpsLoading = true; _gpsError = null; });
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() {
          _gpsLoading = false;
          _gpsError = 'GPS is turned off. Please enable it.';
        });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _gpsLoading = false;
          _gpsError = perm == LocationPermission.deniedForever
              ? 'Permission permanently denied. Enable from Settings.'
              : 'Location permission denied.';
        });
        return;
      }
      _posSub = Geolocator.getPositionStream(
              locationSettings: _locationSettings())
          .listen(
        (p) {
          if (mounted) setState(() { _pos = p; _gpsLoading = false; _gpsError = null; });
        },
        onError: (e) {
          if (mounted) setState(() { _gpsLoading = false; _gpsError = 'GPS Error: $e'; });
        },
        cancelOnError: false,
      );
    } on LocationServiceDisabledException {
      if (mounted) setState(() { _gpsLoading = false; _gpsError = 'Location service disabled.'; });
    } catch (e) {
      if (mounted) setState(() { _gpsLoading = false; _gpsError = 'GPS Error: ${e.toString()}'; });
    }
  }

  // ── Calculated values ─────────────────────────────────────────────────

  double get _distance {
    if (_pos == null || widget.session == null) return 0.0;
    return Geolocator.distanceBetween(
          widget.session!.facultyLat, widget.session!.facultyLng,
          _pos!.latitude, _pos!.longitude) +
        _offsetMeters;
  }

  double get _bearing {
    if (_pos == null || widget.session == null) return 0.0;
    return calculateBearing(
      widget.session!.facultyLat, widget.session!.facultyLng,
      _pos!.latitude, _pos!.longitude,
    );
  }

  bool get _inFrontSector {
    final s = widget.session;
    if (s == null || !s.directionalModeEnabled) return true;
    return isStudentInFrontSector(s.facultyHeading, _bearing, s.frontSectorDegrees);
  }

  bool get _withinRadius {
    final s = widget.session;
    if (s == null) return false;
    return _distance <= s.radiusMeters;
  }

  bool get _isMock => _simulateMock || (_pos?.isMocked ?? false);

  // ── Mark attendance ────────────────────────────────────────────────────

  Future<void> _mark() async {
    final name = _nameCtrl.text.trim();
    final roll = _rollCtrl.text.trim();

    if (name.isEmpty || roll.isEmpty) {
      _snack('Please enter your Full Name and Roll Number!');
      return;
    }
    if (widget.session == null) {
      _dialog('No Active Session',
          'No attendance session is running right now.\nAsk your faculty to start a session from their device.',
          false);
      return;
    }
    if (widget.session!.isExpired) {
      _dialog('Session Expired',
          'The attendance session has ended.\nLate submissions are not accepted.', false);
      return;
    }
    if (_pos == null) {
      _snack('Waiting for GPS… please wait a moment.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final s = widget.session!;
      final dist = _distance;
      final bear = _bearing;
      final inSector = _inFrontSector;
      final mock = _isMock;
      final withinR = dist <= s.radiusMeters;

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
            'Student is behind the faculty (bearing ${bear.toStringAsFixed(0)}°, front zone ±${(s.frontSectorDegrees / 2).toStringAsFixed(0)}° of ${s.facultyHeading.toStringAsFixed(0)}°).';
      } else {
        status = AttendanceStatus.approved;
        remark =
            'Verified inside geofence: ${dist.toStringAsFixed(1)}m, ${inSector ? 'front sector' : 'sector check skipped'}.';
      }

      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentName: name,
        rollNo: roll,
        studentLat: _pos!.latitude,
        studentLng: _pos!.longitude,
        distanceMeters: dist,
        bearingToStudent: bear,
        isMocked: mock,
        isInFrontSector: inSector,
        timestamp: DateTime.now(),
        status: status,
        remarks: remark,
      );

      await widget.onSubmit(record);
      setState(() { _submitting = false; _submitted = true; });

      // Result dialog
      if (status == AttendanceStatus.approved) {
        _dialog('Attendance Marked ✅',
            'You are verified inside the classroom.\n\n• Distance: ${dist.toStringAsFixed(1)} m\n• Zone: Front sector ✓\n• Mock GPS: Clean ✓\n\nYour faculty can see this now on their device.',
            true);
      } else if (status == AttendanceStatus.flaggedMockLocation) {
        _dialog('Suspicious Location ⚠️',
            'Fake/Mock GPS detected on your device.\nYour entry has been flagged and sent to faculty for review.',
            false);
      } else if (status == AttendanceStatus.rejectedBehindFaculty) {
        _dialog('Behind Faculty ❌',
            'You are within the radius (${dist.toStringAsFixed(1)} m) but you are BEHIND the faculty.\n\nOnly students in front of the faculty (within the ${s.frontSectorDegrees.toInt()}° front zone) are allowed.',
            false);
      } else {
        _dialog('Outside Radius ❌',
            'You are ${dist.toStringAsFixed(1)} m from the classroom.\nMaximum allowed is ${s.radiusMeters.toInt()} m.',
            false);
      }
    } catch (e) {
      setState(() { _submitting = false; });
      _snack('Submission failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange.shade700));
  }

  void _dialog(String title, String msg, bool success) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: success ? Colors.green : Colors.red, size: 52),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = widget.session;
    final active = s != null && s.isActive && !s.isExpired;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Live session card ──
          _sessionCard(s, active, cs),
          const SizedBox(height: 14),

          // ── Identity card ──
          _identityCard(),
          const SizedBox(height: 14),

          // ── Geofence status card ──
          if (active) ...[
            _geofenceCard(s, cs),
            const SizedBox(height: 14),
          ],

          // ── Submitted notice ──
          if (_submitted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade400, width: 1.5),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_done_rounded,
                      color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance Submitted!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14)),
                      SizedBox(height: 2),
                      Text(
                          'Open the Faculty Panel on the other device to see your record appear live.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // ── Mark button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_pos == null || _submitting) ? null : _mark,
              icon: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Icon(
                      (active && _withinRadius && _inFrontSector && !_isMock)
                          ? Icons.how_to_reg_rounded
                          : Icons.touch_app_rounded,
                      size: 26,
                    ),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _submitting ? 'Saving to Firebase…' : 'Mark My Attendance',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (!_submitting && active)
                    Text(
                      (active && _withinRadius && _inFrontSector && !_isMock)
                          ? 'All checks passed — tap to submit'
                          : 'Tap to submit (will be reviewed by faculty)',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.85)),
                    ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: (active && _withinRadius && _inFrontSector && !_isMock)
                    ? Colors.green.shade700
                    : cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Demo tools ──
          _demoTools(cs),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Session card ───────────────────────────────────────────────────────

  Widget _sessionCard(AttendanceSession? s, bool active, ColorScheme cs) {
    if (s == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waiting for Faculty…',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 3),
              Text('The faculty must start a session on their device first.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ]),
      );
    }

    final isRunning = s.isActive && !s.isExpired;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isRunning
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.grey.shade600, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white, size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                Text('by ${s.facultyName}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isRunning ? Colors.white : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isRunning ? 'LIVE' : 'ENDED',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11,
                  color: isRunning ? Colors.green.shade700 : Colors.white,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // Stats row
          Row(children: [
            _sessionStat(Icons.radar_rounded, '${s.radiusMeters.toInt()} m', 'Radius'),
            const SizedBox(width: 10),
            _sessionStat(
              s.directionalModeEnabled ? Icons.navigation_rounded : Icons.circle_outlined,
              s.directionalModeEnabled
                  ? '${s.frontSectorDegrees.toInt()}° ${headingToLabel(s.facultyHeading)}'
                  : '360°',
              'Zone',
            ),
            const SizedBox(width: 10),
            if (isRunning)
              _sessionStat(Icons.timer_rounded, _fmtDurationShort(s.remainingTime), 'Left')
            else
              _sessionStat(Icons.lock_clock_rounded, 'Ended', 'Status'),
          ]),
        ]),
      ),
    );
  }

  Widget _sessionStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
        ]),
      ),
    );
  }



  String _fmtDurationShort(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Identity card ──────────────────────────────────────────────────────

  Widget _identityCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.person_pin_rounded, size: 20, color: Colors.blue),
            SizedBox(width: 8),
            Text('Student Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Rahul Sharma',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person_rounded),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rollCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Roll Number / Student ID *',
              hintText: 'e.g. 22BCS045',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.badge_rounded),
              filled: true,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Geofence card ──────────────────────────────────────────────────────

  Widget _geofenceCard(AttendanceSession s, ColorScheme cs) {
    final dist = _distance;
    final inR = _withinRadius;
    final inF = _inFrontSector;
    final mock = _isMock;
    final allowed = inR && inF && !mock;

    // Progress bar clamped from 0.0 to 1.0 (1.0 = at radius limit)
    final progress = s.radiusMeters > 0 ? (dist / s.radiusMeters).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // ── Big Distance Meter Card ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: allowed
                  ? [Colors.green.shade700, Colors.green.shade400]
                  : mock
                      ? [Colors.orange.shade700, Colors.orange.shade400]
                      : [Colors.red.shade700, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Status icon + label
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  allowed
                      ? Icons.check_circle_rounded
                      : mock
                          ? Icons.warning_rounded
                          : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  allowed
                      ? 'You can mark attendance ✓'
                      : mock
                          ? 'Mock GPS Detected — Not Allowed'
                          : !inR
                              ? 'Too Far from Classroom'
                              : 'Behind Faculty — Move Forward',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Big Distance Number ──────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Column(children: [
                  Text(
                    dist >= 1000
                        ? '${(dist / 1000).toStringAsFixed(2)} km'
                        : '${dist.toStringAsFixed(1)} m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 52,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'from faculty / classroom',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 12),
                  ),
                ]),
              ]),
              const SizedBox(height: 16),

              // ── Distance Progress Bar ──────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0 m  (Faculty)',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10)),
                      Text('Allowed limit: ${s.radiusMeters.toInt()} m',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      // Background track
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Filled bar
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      // Radius limit marker (at 50% of bar = at radius)
                      Positioned(
                        left: null,
                        right: null,
                        child: Align(
                          alignment: const Alignment(0, 0),
                          child: Container(
                            width: 2,
                            height: 12,
                            color: Colors.yellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Distance breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inR
                            ? '${(s.radiusMeters - dist).toStringAsFixed(1)} m buffer left'
                            : '${(dist - s.radiusMeters).toStringAsFixed(1)} m over limit',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        inR ? 'Inside ✓' : 'Outside ✗',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // ── Status Checks Row ────────────────────────────────────────────
        Row(children: [
          // Radius check
          Expanded(
            child: _miniStatusCard(
              icon: inR ? Icons.my_location_rounded : Icons.location_off_rounded,
              color: inR ? Colors.green : Colors.red,
              label: inR ? 'In Range' : 'Out of Range',
              sub: '${s.radiusMeters.toInt()} m limit',
            ),
          ),
          const SizedBox(width: 8),
          // Direction check (if directional mode ON)
          if (s.directionalModeEnabled) ...[
            Expanded(
              child: _miniStatusCard(
                icon: inF ? Icons.front_hand_rounded : Icons.back_hand_rounded,
                color: inF ? Colors.blue : Colors.deepOrange,
                label: inF ? 'Front Zone' : 'Behind',
                sub: '${s.frontSectorDegrees.toInt()}° arc',
              ),
            ),
            const SizedBox(width: 8),
          ],
          // GPS integrity
          Expanded(
            child: _miniStatusCard(
              icon: mock ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
              color: mock ? Colors.orange : Colors.green,
              label: mock ? 'Fake GPS' : 'Real GPS',
              sub: mock ? 'Flagged!' : 'Verified',
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // ── GPS Coordinates ──────────────────────────────────────────────
        if (_pos != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.satellite_alt_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}  ±${_pos!.accuracy.toStringAsFixed(1)} m accuracy',
                  style: TextStyle(fontSize: 11, color: cs.primary),
                ),
              ),
            ]),
          )
        else if (_gpsLoading)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Acquiring satellite GPS… please wait',
                  style: TextStyle(fontSize: 12)),
            ]),
          )
        else if (_gpsError != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.red),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_gpsError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _miniStatusCard({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 11),
            textAlign: TextAlign.center),
        Text(sub,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Demo tools ─────────────────────────────────────────────────────────

  Widget _demoTools(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.primary.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.science_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 6),
            Text('Demo Testing Tools',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: cs.primary)),
          ]),
          const SizedBox(height: 6),
          Text('Simulate distance offset for testing:',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ChoiceChip(
              label: const Text('0 m (exact)'),
              selected: _offsetMeters == 0,
              onSelected: (_) => setState(() => _offsetMeters = 0),
            ),
            ChoiceChip(
              label: const Text('+15 m'),
              selected: _offsetMeters == 15,
              onSelected: (_) => setState(() => _offsetMeters = 15),
            ),
            ChoiceChip(
              label: const Text('+50 m'),
              selected: _offsetMeters == 50,
              onSelected: (_) => setState(() => _offsetMeters = 50),
            ),
            ChoiceChip(
              label: const Text('+150 m'),
              selected: _offsetMeters == 150,
              onSelected: (_) => setState(() => _offsetMeters = 150),
            ),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Simulate Mock/Fake GPS',
                style: TextStyle(fontSize: 12)),
            value: _simulateMock,
            onChanged: (v) => setState(() => _simulateMock = v),
          ),
        ]),
      ),
    );
  }
}
