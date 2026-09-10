import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import 'widgets/face_scanner_sheet.dart';

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

    if (_nameController.text.trim().isEmpty ||
        _rollController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Full Name and Roll Number.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Require registered profile photo for Layer 2 Face Verification
    if (!_controller.hasProfilePhoto) {
      final shouldSetup = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.face_retouching_natural_rounded,
              size: 44, color: Colors.blue),
          title:
              const Text('Profile Photo Required', textAlign: TextAlign.center),
          content: const Text(
            'Layer 2 requires an official profile photo to match against your live camera scan.\n\nPlease take a quick selfie to set up your profile.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Take Selfie'),
            ),
          ],
        ),
      );

      if (shouldSetup == true && mounted) {
        await _controller.pickAndRegisterProfilePhoto(source: ImageSource.camera);
      }
      return;
    }

    // ── Open Layer 2 Live Face Scanner ──────────────────────────────────
    final scanResult =
        await showModalBottomSheet<({bool verified, String? photoPath})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FaceScannerSheet(
        targetSignature: _controller.profileSignature,
        studentName: _nameController.text.trim(),
      ),
    );

    if (scanResult?.verified != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification not completed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final record = await _controller.submitAttendance(
        faceVerified: true,
      );
      if (!mounted) return;

      if (record.status == AttendanceStatus.approved) {
        final bleInfo = record.bleVerified
            ? '• Layer 1 (BLE): Code #${record.bleCodeUsed?.toString().padLeft(2, '0')} Verified ✓\n'
            : '';
        final faceInfo = record.faceVerified
            ? '• Layer 2 (Face ID): Live Scan Matched Profile ✓\n'
            : '';
        final isOffline = _controller.wasSubmittedOffline;
        _showResultDialog(
          title: isOffline
              ? 'Attendance Saved Offline! 📱'
              : 'Attendance Marked! ✅',
          message: isOffline
              ? 'All 3 layers verified!\n\n$bleInfo$faceInfo• Layer 3 (Geo/Distance): ${record.distanceMeters.toStringAsFixed(1)} m\n• Direction: ${record.isInFrontSector ? 'Front sector ✓' : 'Full 360°'}\n\nYour record is safely stored offline and will auto-sync when internet returns.'
              : 'All 3 layers verified inside classroom!\n\n$bleInfo$faceInfo• Layer 3 (Geo/Distance): ${record.distanceMeters.toStringAsFixed(1)} m\n• Direction: ${record.isInFrontSector ? 'Front sector ✓' : 'Full 360°'}\n• Hardware GPS: Clean ✓',
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
              'You are ${record.distanceMeters.toStringAsFixed(1)} m away.\nMaximum allowed is ${_controller.activeSession?.radiusMeters.toInt()} m.',
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
            title: const Text('Student Portal'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _StatusPill(
                  isActive: isSessionActive,
                  activeLabel: 'LIVE',
                  idleLabel: 'Waiting',
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSessionBanner(session, cs),
                const SizedBox(height: 10),

                const SyncStatusCard(),
                const SizedBox(height: 12),

                _buildIdentityCard(cs),
                const SizedBox(height: 12),

                // Layer 1: Number Challenge
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
                  const SizedBox(height: 10),
                ],

                _buildGpsBox(cs),
                const SizedBox(height: 12),

                if (_controller.hasSubmitted) ...[
                  _buildSubmittedNotice(),
                  const SizedBox(height: 12),
                ],

                // ── Mark Attendance Button ──────────────────────────
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
                            size: 24,
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
                                : 'Tap to submit (faculty will review)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _controller.isReadyToMark
                          ? Colors.green.shade700
                          : cs.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                DemoToolsCard(controller: _controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionBanner(AttendanceSession? s, ColorScheme cs) {
    // ── No session: BLE beacon offline ──────────────────────────────────
    if (s == null && _controller.isBeaconActive) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.blue.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classroom Beacon Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Direct BLE radio active. Tap the announced code to mark offline.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    // ── No session: waiting ──────────────────────────────────────────────
    if (s == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for Faculty…',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Searching for teacher\'s BLE beacon or cloud session...',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    // ── Active / ended session ───────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isRunning ? Colors.green : Colors.grey).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
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
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isRunning
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
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
            'BLE Range',
          ),
          const SizedBox(width: 8),
          _buildSessionStat(
            s.directionalModeEnabled
                ? Icons.navigation_rounded
                : Icons.circle_outlined,
            s.directionalModeEnabled
                ? '${s.frontSectorDegrees.toInt()}° ${GeoUtils.headingToLabel(s.facultyHeading)}'
                : '360°',
            'Zone',
          ),
          const SizedBox(width: 8),
          _buildSessionStat(
            isRunning ? Icons.timer_rounded : Icons.lock_clock_rounded,
            isRunning ? GeoUtils.formatDuration(s.remainingTime) : 'Ended',
            isRunning ? 'Left' : 'Status',
          ),
        ]),
      ]),
    );
  }

  Widget _buildSessionStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
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
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildIdentityCard(ColorScheme cs) {
    final hasPhoto = _controller.hasProfilePhoto;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.person_pin_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Student Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasPhoto
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasPhoto
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPhoto
                          ? Icons.verified_user_rounded
                          : Icons.add_a_photo_outlined,
                      size: 12,
                      color: hasPhoto ? Colors.green : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPhoto ? 'Face ID Ready' : 'Photo Needed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasPhoto ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Profile Photo Picker Row ────────────────────────────────
          InkWell(
            onTap: () => _showPhotoPickerSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPhoto
                      ? Colors.green.withValues(alpha: 0.25)
                      : cs.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: hasPhoto
                            ? FileImage(File(_controller.profilePhotoPath!))
                            : null,
                        child: !hasPhoto
                            ? Icon(Icons.person_rounded,
                                size: 32, color: cs.primary)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPhoto
                              ? 'Official Profile Photo Registered ✓'
                              : 'Set Official Profile Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasPhoto ? Colors.green.shade800 : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPhoto
                              ? 'Used as ground-truth for Layer 2 Face Scan'
                              : 'Tap to snap a selfie or choose from gallery',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),

          if (_controller.isRegisteringFace) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Detecting & registering face...',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ],

          if (_controller.faceRegistrationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _controller.faceRegistrationError!,
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
          ],

          const SizedBox(height: 14),

          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (val) {
              _controller.setStudentDetails(
                name: val.trim(),
                roll: _rollController.text.trim(),
              );
            },
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g. Rahul Sharma',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rollController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) {
              _controller.setStudentDetails(
                name: _nameController.text.trim(),
                roll: val.trim(),
              );
            },
            decoration: const InputDecoration(
              labelText: 'Roll Number / Student ID *',
              hintText: 'e.g. 22BCS045',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
          ),
        ]),
      ),
    );
  }

  void _showPhotoPickerSheet(BuildContext context) {
    if (_rollController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Roll Number first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Register Profile Photo (Layer 2 Face ID)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Make sure your face is clearly visible and well lit.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                ),
                title: const Text('Take Selfie with Camera'),
                subtitle: const Text('Recommended for best face alignment'),
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.pickAndRegisterProfilePhoto(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: const Text('Choose from Photo Gallery'),
                subtitle: const Text('Select a clear portrait photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _controller.pickAndRegisterProfilePhoto(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsBox(ColorScheme cs) {
    if (_controller.currentPosition != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(Icons.satellite_alt_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_controller.currentPosition!.latitude.toStringAsFixed(6)}, '
              '${_controller.currentPosition!.longitude.toStringAsFixed(6)}  '
              '±${_controller.currentPosition!.accuracy.toStringAsFixed(1)} m',
              style: TextStyle(fontSize: 11, color: cs.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
    } else if (_controller.isLoadingGps) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Acquiring satellite GPS… please wait',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ]),
      );
    } else if (_controller.gpsError != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.06),
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

  Widget _buildSubmittedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.07),
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
              color: Colors.green.shade700, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Submitted!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Open the Faculty Panel on the other phone to see your record.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Compact status pill for AppBar actions
class _StatusPill extends StatelessWidget {
  final bool isActive;
  final String activeLabel;
  final String idleLabel;

  const _StatusPill({
    required this.isActive,
    required this.activeLabel,
    required this.idleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? activeLabel : idleLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
