import 'package:flutter/material.dart';
import '../../controllers/student_controller.dart';
import '../../models/attendance_session.dart';
import '../../models/attendance_status.dart';
import '../../utils/geo_utils.dart';
import '../role_selector_screen.dart';
import 'widgets/distance_meter_card.dart';
import 'widgets/verification_badges.dart';
import 'widgets/demo_tools_card.dart';
import 'widgets/number_challenge_card.dart';
import 'widgets/sync_status_card.dart';
import 'widgets/nearby_beacons_card.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late final StudentController _controller;
  late final TextEditingController _nameController;
  late final TextEditingController _rollController;

  @override
  void initState() {
    super.initState();
    _controller = StudentController()..init();
    _nameController = TextEditingController();
    _rollController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onMarkPressed() async {
    _controller.setStudentDetails(
      name: _nameController.text.trim(),
      roll: _rollController.text.trim(),
    );

    try {
      final record = await _controller.submitAttendance();
      if (!mounted) return;

      if (record.status == AttendanceStatus.approved) {
        final bleInfo = record.bleVerified
            ? '• Layer 1 (BLE): Code #${record.bleCodeUsed?.toString().padLeft(2, '0')} Verified ✓\n'
            : '';
        final isOffline = _controller.wasSubmittedOffline;
        _showResultDialog(
          title: isOffline ? 'Attendance Saved Offline! 📱' : 'Attendance Marked! ✅',
          message: isOffline
              ? 'You are verified inside Bluetooth range.\n\n$bleInfo• Bluetooth Range: ${record.distanceMeters.toStringAsFixed(1)} m\n• Direction: ${record.isInFrontSector ? 'Front sector ✓' : 'Full 360°'}\n\nYour record is safely stored in your phone\'s offline queue and will automatically sync to the faculty dashboard when connected to the internet.'
              : 'You are verified inside the classroom.\n\n$bleInfo• Bluetooth Range: ${record.distanceMeters.toStringAsFixed(1)} m\n• Direction: ${record.isInFrontSector ? 'Front sector ✓' : 'Full 360°'}\n• Hardware GPS: Clean ✓\n\nYour attendance is registered live on the teacher\'s panel.',
          isSuccess: true,
        );
      } else if (record.status == AttendanceStatus.flaggedMockLocation) {
        _showResultDialog(
          title: 'Suspicious Location ⚠️',
          message:
              'Fake / Mock GPS detected on your phone!\nYour submission has been flagged and submitted to the faculty for review.',
          isSuccess: false,
        );
      } else if (record.status == AttendanceStatus.rejectedBehindFaculty) {
        _showResultDialog(
          title: 'Behind Faculty ❌',
          message:
              'You are ${record.distanceMeters.toStringAsFixed(1)} m away, but you are standing BEHIND the faculty.\n\nPlease move inside the classroom facing the faculty.',
          isSuccess: false,
        );
      } else {
        _showResultDialog(
          title: 'Outside Bluetooth Range ❌',
          message:
              'You are ${record.distanceMeters.toStringAsFixed(1)} m away from the faculty.\nMaximum allowed Bluetooth range is ${_controller.activeSession?.radiusMeters.toInt()} m.',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
          color: isSuccess ? Colors.green : Colors.red,
          size: 52,
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
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final session = _controller.activeSession;
        final isSessionActive =
            session != null && session.isActive && !session.isExpired;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Role',
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectorScreen()),
              ),
            ),
            title: Column(
              children: [
                const Text(
                  'Student Portal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Firebase Live',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSessionBanner(session, cs),
                const SizedBox(height: 10),

                if (isSessionActive) ...[
                  _buildCountdownBanner(session),
                  const SizedBox(height: 10),
                ],

                const SyncStatusCard(),
                const SizedBox(height: 14),

                NearbyBeaconsCard(controller: _controller),
                const SizedBox(height: 14),

                _buildIdentityCard(cs),
                const SizedBox(height: 14),

                // Layer 1: Number Challenge Card (Always visible when session is active or beacon is detected)
                if (isSessionActive ||
                    _controller.isBeaconActive ||
                    _controller.simulateBeaconFound) ...[
                  NumberChallengeCard(controller: _controller),
                  const SizedBox(height: 12),
                ],

                if (isSessionActive) ...[
                  DistanceMeterCard(
                    controller: _controller,
                    session: session,
                  ),
                  const SizedBox(height: 10),

                  VerificationBadges(
                    controller: _controller,
                    session: session,
                  ),
                  const SizedBox(height: 8),
                ],

                _buildGpsCoordinatesBox(cs),
                const SizedBox(height: 14),

                if (_controller.hasSubmitted) ...[
                  _buildSubmittedNotice(),
                  const SizedBox(height: 12),
                ],

                // Mark Attendance Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_controller.currentPosition == null ||
                            _controller.isSubmitting)
                        ? null
                        : _onMarkPressed,
                    icon: _controller.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _controller.isReadyToMark
                                ? Icons.how_to_reg_rounded
                                : Icons.touch_app_rounded,
                            size: 26,
                          ),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _controller.isSubmitting
                              ? 'Saving to Firebase…'
                              : 'Mark My Attendance',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_controller.isSubmitting && isSessionActive)
                          Text(
                            _controller.isReadyToMark
                                ? 'All checks passed — tap to mark'
                                : 'Tap to submit (will be reviewed by faculty)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _controller.isReadyToMark
                          ? Colors.green.shade700
                          : cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                DemoToolsCard(controller: _controller),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionBanner(AttendanceSession? s, ColorScheme cs) {
    if (s == null) {
      if (_controller.isBeaconActive) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bluetooth_connected_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Classroom Beacon Detected (Offline)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Direct BLE radio active. Tap the announced code to mark attendance locally.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for Faculty…',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                SizedBox(height: 3),
                Text(
                  'Searching for teacher\'s BLE radio or cloud session...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
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
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'by ${s.facultyName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isRunning ? Colors.green.shade700 : Colors.white,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _buildSessionStat(
              Icons.radar_rounded,
              '${s.radiusMeters.toInt()} m',
              'Radius',
            ),
            const SizedBox(width: 10),
            _buildSessionStat(
              s.directionalModeEnabled
                  ? Icons.navigation_rounded
                  : Icons.circle_outlined,
              s.directionalModeEnabled
                  ? '${s.frontSectorDegrees.toInt()}° ${GeoUtils.headingToLabel(s.facultyHeading)}'
                  : '360°',
              'Zone',
            ),
            const SizedBox(width: 10),
            if (isRunning)
              _buildSessionStat(
                Icons.timer_rounded,
                GeoUtils.formatDuration(s.remainingTime),
                'Left',
              )
            else
              _buildSessionStat(
                Icons.lock_clock_rounded,
                'Ended',
                'Status',
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSessionStat(IconData icon, String value, String label) {
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
          ),
        ]),
      ),
    );
  }

  Widget _buildIdentityCard(ColorScheme cs) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.person_pin_rounded, size: 20, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Student Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Rahul Sharma',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person_rounded),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rollController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Roll Number / Student ID *',
              hintText: 'e.g. 22BCS045',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.badge_rounded),
              filled: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGpsCoordinatesBox(ColorScheme cs) {
    if (_controller.currentPosition != null) {
      return Container(
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
              '${_controller.currentPosition!.latitude.toStringAsFixed(6)}, ${_controller.currentPosition!.longitude.toStringAsFixed(6)}  ±${_controller.currentPosition!.accuracy.toStringAsFixed(1)} m accuracy',
              style: TextStyle(fontSize: 11, color: cs.primary),
            ),
          ),
        ]),
      );
    } else if (_controller.isLoadingGps) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Acquiring satellite GPS… please wait',
            style: TextStyle(fontSize: 12),
          ),
        ]),
      );
    } else if (_controller.gpsError != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _controller.gpsError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCountdownBanner(AttendanceSession s) {
    final remaining = s.remainingTime;
    final totalSeconds = s.endTime.difference(s.startTime).inSeconds;
    final remainingSeconds = remaining.inSeconds.clamp(0, totalSeconds > 0 ? totalSeconds : 1);
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final isUrgent = remaining.inMinutes < 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent ? Colors.red.shade300 : Colors.indigo.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.alarm_rounded,
                color: isUrgent ? Colors.red.shade700 : Colors.indigo.shade700,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Countdown Timer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? Colors.red.shade900 : Colors.indigo.shade900,
                      ),
                    ),
                    Text(
                      '${GeoUtils.formatDuration(remaining)} left to mark attendance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isUrgent ? Colors.red.shade700 : Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUrgent ? Colors.red.shade100 : Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s.endTime.difference(s.startTime).inMinutes}m total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.red.shade800 : Colors.indigo.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isUrgent ? Colors.red.shade100 : Colors.indigo.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? Colors.red.shade600 : Colors.indigo.shade700,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedNotice() {
    final isOffline = _controller.wasSubmittedOffline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOffline
            ? Colors.amber.withOpacity(0.08)
            : Colors.green.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffline ? Colors.amber.shade400 : Colors.green.shade400,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOffline ? Colors.amber.shade100 : Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOffline ? Icons.phone_android_rounded : Icons.cloud_done_rounded,
            color: isOffline ? Colors.amber.shade800 : Colors.green.shade700,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOffline
                    ? '📱 Stored Offline on Device'
                    : 'Attendance Submitted & Synced! ✅',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOffline ? Colors.amber.shade900 : Colors.green,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOffline
                    ? 'Verified locally via BLE! Stored safely on phone and will automatically push to cloud when connected.'
                    : 'Open the Faculty Panel on the other phone to see your record appear live.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
