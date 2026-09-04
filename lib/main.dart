import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const MainAttendanceScreen(),
    );
  }
}

class MainAttendanceScreen extends StatefulWidget {
  const MainAttendanceScreen({super.key});

  @override
  State<MainAttendanceScreen> createState() => _MainAttendanceScreenState();
}

class _MainAttendanceScreenState extends State<MainAttendanceScreen> {
  // Shared In-Memory Backend State for Demo
  AttendanceSession? _activeSession;
  final List<AttendanceRecord> _records = [];
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _startPeriodicTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSession != null && _activeSession!.isActive) {
        if (_activeSession!.isExpired) {
          setState(() {
            _activeSession!.isActive = false;
          });
        } else {
          setState(() {}); // refresh countdown UI
        }
      }
    });
  }

  void _createSession({
    required String title,
    required String facultyName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required int durationMinutes,
  }) {
    final now = DateTime.now();
    setState(() {
      _activeSession = AttendanceSession(
        title: title,
        facultyName: facultyName,
        facultyLat: lat,
        facultyLng: lng,
        radiusMeters: radiusMeters,
        startTime: now,
        endTime: now.add(Duration(minutes: durationMinutes)),
        isActive: true,
      );
      _records.clear(); // Clear previous session records
    });
  }

  void _endSession() {
    setState(() {
      if (_activeSession != null) {
        _activeSession!.isActive = false;
      }
    });
  }

  void _submitAttendance(AttendanceRecord record) {
    setState(() {
      _records.insert(0, record);
    });
  }

  void _updateRecordStatus(String recordId, AttendanceStatus newStatus, String remark) {
    setState(() {
      final index = _records.indexWhere((r) => r.id == recordId);
      if (index != -1) {
        _records[index].status = newStatus;
        _records[index].remarks = remark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            children: [
              Text(
                'Geofenced Attendance Demo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Live GPS Distance & Mock Detection',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.school), text: 'Faculty Panel'),
              Tab(icon: Icon(Icons.person_pin_circle), text: 'Student Portal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FacultyPanelView(
              activeSession: _activeSession,
              records: _records,
              onCreateSession: _createSession,
              onEndSession: _endSession,
              onUpdateStatus: _updateRecordStatus,
            ),
            StudentPortalView(
              activeSession: _activeSession,
              onSubmitAttendance: _submitAttendance,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. FACULTY PANEL VIEW
// ---------------------------------------------------------------------------
class FacultyPanelView extends StatefulWidget {
  final AttendanceSession? activeSession;
  final List<AttendanceRecord> records;
  final Function({
    required String title,
    required String facultyName,
    required double lat,
    required double lng,
    required double radiusMeters,
    required int durationMinutes,
  }) onCreateSession;
  final VoidCallback onEndSession;
  final Function(String recordId, AttendanceStatus newStatus, String remark) onUpdateStatus;

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

  Future<void> _fetchFacultyLocation() async {
    setState(() {
      _isLoadingGPS = true;
      _gpsError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingGPS = false;
          _gpsError = 'GPS is turned off on this device.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingGPS = false;
            _gpsError = 'Location permission denied.';
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(),
      );

      if (mounted) {
        setState(() {
          _facultyPosition = position;
          _isLoadingGPS = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGPS = false;
          _gpsError = e.toString();
        });
      }
    }
  }

  void _startNewSession() {
    if (_facultyPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture faculty GPS location first!')),
      );
      return;
    }

    widget.onCreateSession(
      title: _titleController.text.trim().isEmpty ? 'Lecture Session' : _titleController.text.trim(),
      facultyName: _facultyNameController.text.trim().isEmpty ? 'Faculty' : _facultyNameController.text.trim(),
      lat: _facultyPosition!.latitude,
      lng: _facultyPosition!.longitude,
      radiusMeters: _radiusMeters,
      durationMinutes: _durationMinutes,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attendance Session Started! Students can now mark attendance.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
          // Session Status Banner
          if (isSessionRunning) ...[
            _buildActiveSessionBanner(session, colorScheme),
            const SizedBox(height: 16),
          ] else if (session != null && session.isExpired) ...[
            _buildExpiredBanner(session, colorScheme),
            const SizedBox(height: 16),
          ],

          // Start Session Form Card
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

                  // Faculty GPS Coordinates Display
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
                            const Text(
                              'Classroom Center (Faculty GPS):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            IconButton(
                              icon: _isLoadingGPS
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                              onPressed: _isLoadingGPS ? null : _fetchFacultyLocation,
                              tooltip: 'Refresh Location',
                            ),
                          ],
                        ),
                        if (_facultyPosition != null) ...[
                          Text(
                            'Lat: ${_facultyPosition!.latitude.toStringAsFixed(7)}, Lng: ${_facultyPosition!.longitude.toStringAsFixed(7)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            'Hardware GPS Accuracy: ±${_facultyPosition!.accuracy.toStringAsFixed(1)}m',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ] else if (_gpsError != null) ...[
                          Text(
                            'Error: $_gpsError',
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ] else ...[
                          const Text('Fetching current GPS coordinates...', style: TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Radius Slider
                  Text(
                    'Allowed Geofence Radius: ${_radiusMeters.toInt()} meters',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Slider(
                    value: _radiusMeters,
                    min: 10,
                    max: 150,
                    divisions: 14,
                    label: '${_radiusMeters.toInt()}m',
                    onChanged: (val) => setState(() => _radiusMeters = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('10m (Small Room)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text('50m (Hall)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text('150m (Campus)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duration Selector
                  Text(
                    'Session Duration: $_durationMinutes Minutes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [1, 2, 5, 10, 15].map((mins) {
                      final selected = _durationMinutes == mins;
                      return ChoiceChip(
                        label: Text('$mins min'),
                        selected: selected,
                        onSelected: (val) {
                          if (val) setState(() => _durationMinutes = mins);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _facultyPosition == null ? null : _startNewSession,
                      icon: const Icon(Icons.play_circle_fill),
                      label: Text(isSessionRunning ? 'Restart Session with New Settings' : 'Start Attendance Session'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (isSessionRunning) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onEndSession,
                        icon: const Icon(Icons.stop_circle, color: Colors.red),
                        label: const Text('End Current Session Now', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

          // Live Submissions & Review Queue Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Submissions (${widget.records.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (widget.records.isNotEmpty)
                Text(
                  'Approved: ${widget.records.where((r) => r.status == AttendanceStatus.approved || r.status == AttendanceStatus.manuallyApproved).length}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Submissions List
          if (widget.records.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No attendance submissions yet', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text(
                    'Switch to "Student Portal" tab to submit attendance.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...widget.records.map((record) => _buildRecordCard(record, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(AttendanceSession session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ACTIVE SESSION LIVE',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(session.remainingTime),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Faculty: ${session.facultyName} | Radius: ${session.radiusMeters.toInt()}m',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner(AttendanceSession session, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_off, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session for "${session.title}" has ended.',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record, ColorScheme colorScheme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (record.status) {
      case AttendanceStatus.approved:
        statusColor = Colors.green.shade700;
        statusText = 'Verified & Approved';
        statusIcon = Icons.check_circle;
        break;
      case AttendanceStatus.manuallyApproved:
        statusColor = Colors.teal.shade700;
        statusText = 'Manually Approved';
        statusIcon = Icons.check_circle_outline;
        break;
      case AttendanceStatus.rejectedOutsideRadius:
        statusColor = Colors.red.shade700;
        statusText = 'Rejected (Outside Geofence)';
        statusIcon = Icons.cancel;
        break;
      case AttendanceStatus.flaggedMockLocation:
        statusColor = Colors.orange.shade800;
        statusText = 'FLAGGED: Mock/Fake GPS';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case AttendanceStatus.sessionExpired:
        statusColor = Colors.grey.shade700;
        statusText = 'Rejected (Late Submission)';
        statusIcon = Icons.timer_off;
        break;
      case AttendanceStatus.manuallyRejected:
        statusColor = Colors.red.shade900;
        statusText = 'Manually Rejected';
        statusIcon = Icons.block;
        break;
    }

    final time = record.timestamp.toLocal();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  record.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Roll No: ${record.rollNo} | Submitted at: $timeStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoBadge(Icons.straighten, '${record.distanceMeters.toStringAsFixed(1)}m away'),
                const SizedBox(width: 8),
                _buildInfoBadge(
                  record.isMocked ? Icons.warning : Icons.verified,
                  record.isMocked ? 'Mock GPS: YES' : 'Mock GPS: NO',
                  isWarning: record.isMocked,
                ),
              ],
            ),
            if (record.remarks != null) ...[
              const SizedBox(height: 6),
              Text('Remarks: ${record.remarks}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            // Faculty manual review actions for suspicious or rejected submissions
            if (record.status == AttendanceStatus.flaggedMockLocation ||
                record.status == AttendanceStatus.rejectedOutsideRadius) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      widget.onUpdateStatus(
                        record.id,
                        AttendanceStatus.manuallyApproved,
                        'Faculty approved override after review',
                      );
                    },
                    icon: const Icon(Icons.check, size: 16, color: Colors.teal),
                    label: const Text('Allow / Approve', style: TextStyle(color: Colors.teal)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      widget.onUpdateStatus(
                        record.id,
                        AttendanceStatus.manuallyRejected,
                        'Faculty confirmed rejection',
                      );
                    },
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text('Confirm Reject', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, {bool isWarning = false}) {
    final color = isWarning ? Colors.red : Colors.grey.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
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
  final Function(AttendanceRecord) onSubmitAttendance;

  const StudentPortalView({
    super.key,
    required this.activeSession,
    required this.onSubmitAttendance,
  });

  @override
  State<StudentPortalView> createState() => _StudentPortalViewState();
}

class _StudentPortalViewState extends State<StudentPortalView> {
  final _nameController = TextEditingController(text: 'Rahul Verma');
  final _rollNoController = TextEditingController(text: 'CS-2024-042');

  Position? _studentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isLoadingGPS = false;
  String? _gpsError;

  // Simulation settings for easy demo testing
  bool _simulateMockGps = false;
  double _simulateOffsetMeters = 0.0; // 0 = exact real GPS, 150 = outside radius

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

  Future<void> _startLiveStudentGPS() async {
    setState(() {
      _isLoadingGPS = true;
      _gpsError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingGPS = false;
          _gpsError = 'GPS is disabled on this device.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingGPS = false;
            _gpsError = 'Location permission denied.';
          });
          return;
        }
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(),
      ).listen(
        (Position pos) {
          if (mounted) {
            setState(() {
              _studentPosition = pos;
              _isLoadingGPS = false;
              _gpsError = null;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isLoadingGPS = false;
              _gpsError = err.toString();
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGPS = false;
          _gpsError = e.toString();
        });
      }
    }
  }

  double _calculateDistance() {
    if (_studentPosition == null || widget.activeSession == null) return 0.0;

    final session = widget.activeSession!;
    final actualDistance = Geolocator.distanceBetween(
      session.facultyLat,
      session.facultyLng,
      _studentPosition!.latitude,
      _studentPosition!.longitude,
    );

    // Apply simulation offset if set in demo
    return actualDistance + _simulateOffsetMeters;
  }

  void _markAttendance() {
    final session = widget.activeSession;
    if (session == null) {
      _showResultDialog(
        title: 'No Active Session',
        message: 'There is no active attendance session right now. Please ask your faculty to start the session.',
        isSuccess: false,
      );
      return;
    }

    if (session.isExpired) {
      final record = AttendanceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentName: _nameController.text.trim(),
        rollNo: _rollNoController.text.trim(),
        studentLat: _studentPosition?.latitude ?? 0.0,
        studentLng: _studentPosition?.longitude ?? 0.0,
        distanceMeters: _calculateDistance(),
        isMocked: _simulateMockGps || (_studentPosition?.isMocked ?? false),
        timestamp: DateTime.now(),
        status: AttendanceStatus.sessionExpired,
        remarks: 'Session expired before submission',
      );
      widget.onSubmitAttendance(record);

      _showResultDialog(
        title: 'Session Expired',
        message: 'The attendance session has ended. Late submissions are rejected.',
        isSuccess: false,
      );
      return;
    }

    if (_studentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acquiring your satellite GPS location, please wait...')),
      );
      return;
    }

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
      studentName: _nameController.text.trim().isEmpty ? 'Student' : _nameController.text.trim(),
      rollNo: _rollNoController.text.trim().isEmpty ? 'N/A' : _rollNoController.text.trim(),
      studentLat: _studentPosition!.latitude,
      studentLng: _studentPosition!.longitude,
      distanceMeters: distance,
      isMocked: isMock,
      timestamp: DateTime.now(),
      status: status,
      remarks: remarks,
    );

    widget.onSubmitAttendance(record);

    if (status == AttendanceStatus.approved) {
      _showResultDialog(
        title: 'Attendance Marked Successfully!',
        message:
            'You are verified inside the classroom.\n\n• Distance: ${distance.toStringAsFixed(1)}m\n• Allowed: ${session.radiusMeters.toInt()}m\n• Mock GPS: Clean',
        isSuccess: true,
      );
    } else if (status == AttendanceStatus.flaggedMockLocation) {
      _showResultDialog(
        title: 'Suspicious Location Flagged!',
        message:
            'Mock or Fake GPS detected on your device. Your submission has been flagged and sent to faculty for manual review.',
        isSuccess: false,
      );
    } else {
      _showResultDialog(
        title: 'Outside Classroom Boundary',
        message:
            'You are ${distance.toStringAsFixed(1)} meters away from the classroom center. Maximum allowed is ${session.radiusMeters.toInt()} meters.\n\nAttendance rejected.',
        isSuccess: false,
      );
    }
  }

  void _showResultDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final session = widget.activeSession;
    final distance = _calculateDistance();
    final isWithinRadius = session != null && distance <= session.radiusMeters;
    final isMock = _simulateMockGps || (_studentPosition?.isMocked ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Student Profile Inputs
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(
                      labelText: 'Roll Number / Student ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Geofence Radar / Status Card
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
                      const Text(
                        'Live Geofence Distance Meter',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (session == null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No active session found. Faculty needs to start session from the Faculty Panel.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Active Target Details
                    Text(
                      'Target Session: ${session.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text('Faculty: ${session.facultyName} | Geofence Radius: ${session.radiusMeters.toInt()}m'),
                    const SizedBox(height: 16),

                    // Distance Gauge
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isWithinRadius
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isWithinRadius ? Colors.green : Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isWithinRadius ? Icons.check_circle : Icons.not_listed_location,
                                color: isWithinRadius ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${distance.toStringAsFixed(1)} Meters',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isWithinRadius ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isWithinRadius
                                ? '✓ You are INSIDE classroom radius (Allowed: ${session.radiusMeters.toInt()}m)'
                                : '✗ You are OUTSIDE classroom radius (Allowed: ${session.radiusMeters.toInt()}m)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isWithinRadius ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mock GPS Status Flag
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMock ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMock ? Icons.warning_rounded : Icons.shield_outlined,
                            size: 20,
                            color: isMock ? Colors.red : Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isMock
                                  ? 'Fake / Mock GPS location detected!'
                                  : 'Satellite Integrity: Hardware GPS Verified (No Mocking)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMock ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Student GPS Details
                  if (_studentPosition != null) ...[
                    Text(
                      'Your GPS: ${_studentPosition!.latitude.toStringAsFixed(6)}, ${_studentPosition!.longitude.toStringAsFixed(6)} (±${_studentPosition!.accuracy.toStringAsFixed(1)}m)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ] else if (_isLoadingGPS) ...[
                    const Row(
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Reading satellite GPS coordinates...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ] else if (_gpsError != null) ...[
                    Text('GPS Error: $_gpsError', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Button: Mark Attendance
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _studentPosition == null ? null : _markAttendance,
              icon: const Icon(Icons.touch_app, size: 24),
              label: const Text(
                'Mark My Attendance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isWithinRadius ? Colors.green.shade700 : colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // DEMO & SIMULATION TOOLS (Allows quick testing on single device)
          // -------------------------------------------------------------
          Card(
            elevation: 0,
            color: colorScheme.primary.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Demo Testing Simulator (Single Device Test)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Since you are testing on one phone, you can simulate being inside/outside or spoofing GPS:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Real GPS (0m offset)'),
                        selected: _simulateOffsetMeters == 0.0,
                        onSelected: (val) => setState(() => _simulateOffsetMeters = 0.0),
                      ),
                      ChoiceChip(
                        label: const Text('Simulate 15m away (Inside)'),
                        selected: _simulateOffsetMeters == 15.0,
                        onSelected: (val) => setState(() => _simulateOffsetMeters = 15.0),
                      ),
                      ChoiceChip(
                        label: const Text('Simulate 120m away (Outside)'),
                        selected: _simulateOffsetMeters == 120.0,
                        onSelected: (val) => setState(() => _simulateOffsetMeters = 120.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Simulate Mock/Fake GPS App', style: TextStyle(fontSize: 12)),
                    value: _simulateMockGps,
                    onChanged: (val) => setState(() => _simulateMockGps = val),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}