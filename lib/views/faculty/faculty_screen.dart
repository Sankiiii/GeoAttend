import 'package:flutter/material.dart';
import '../../controllers/faculty_controller.dart';
import '../../models/attendance_session.dart';
import '../../utils/geo_utils.dart';
import '../role_selector_screen.dart';
import 'widgets/session_config_card.dart';
import 'widgets/submission_card.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  late final FacultyController _controller;
  late final TextEditingController _titleController;
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;

  @override
  void initState() {
    super.initState();
    _controller = FacultyController()..init();
    _titleController = TextEditingController(text: _controller.title);
    _nameController = TextEditingController(text: _controller.facultyName);
    _roomController = TextEditingController(text: _controller.roomNumber);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _roomController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final session = _controller.activeSession;
        final isRunning =
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
            title: const Text('Faculty Panel'),
            actions: [
              // Live / idle indicator in the actions area — no overflow risk
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _StatusPill(
                  isActive: isRunning,
                  activeLabel: 'LIVE',
                  idleLabel: 'Idle',
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isRunning) ...[
                  _buildActiveBanner(session, cs),
                  const SizedBox(height: 10),
                  _buildBleCodeBanner(session, cs),
                  const SizedBox(height: 16),
                ],
                if (!isRunning && session != null && session.isExpired) ...[
                  _buildExpiredBanner(session),
                  const SizedBox(height: 14),
                ],

                SessionConfigCard(
                  controller: _controller,
                  titleController: _titleController,
                  nameController: _nameController,
                  roomController: _roomController,
                ),
                const SizedBox(height: 20),

                _buildSubmissionsHeader(cs, isRunning),
                const SizedBox(height: 10),

                if (_controller.records.isEmpty)
                  _buildEmptyState()
                else
                  ..._controller.records.map(
                    (record) => SubmissionCard(
                      record: record,
                      sessionRadius: _controller.radiusMeters,
                      onReview: (id, status, remark) async {
                        try {
                          await _controller.reviewSubmission(id, status, remark);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Review error: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveBanner(AttendanceSession s, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          // Pulsing green dot (static visual)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
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
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${s.radiusMeters.toInt()} m BLE'
                  '${s.directionalModeEnabled ? ' • ${GeoUtils.headingToLabel(s.facultyHeading)} ${s.frontSectorDegrees.toInt()}°' : ' • 360°'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                GeoUtils.formatDuration(s.remainingTime),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  height: 1.1,
                ),
              ),
              Text(
                'remaining',
                style: TextStyle(fontSize: 10, color: Colors.green.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBleCodeBanner(AttendanceSession s, ColorScheme cs) {
    final codeStr = _controller.bleCurrentCode.toString().padLeft(2, '0');
    final secondsLeft = _controller.bleSecondsUntilRotation;
    final progress = secondsLeft / 120.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, Colors.indigo, 0.5)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.lightGreenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'BLE Broadcast Active (Layer 1)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Big Code
          Text(
            codeStr,
            style: const TextStyle(
              fontSize: 62,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),

          // Rotation progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),

          const Text(
            '🗣️ Speak this number aloud to the class',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner(AttendanceSession s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Icon(Icons.history_toggle_off_rounded, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${s.title} — Ended',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_controller.records.length} submissions recorded',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSubmissionsHeader(ColorScheme cs, bool isRunning) {
    return Row(children: [
      Icon(Icons.list_alt_rounded, color: cs.primary, size: 20),
      const SizedBox(width: 8),
      Text(
        'Submissions',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_controller.records.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
      const Spacer(),
      if (isRunning)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_tethering, size: 13, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Live',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            'No submissions yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a session and student attendance will stream here live.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing live / idle status
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
