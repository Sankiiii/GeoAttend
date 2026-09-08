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

  @override
  void initState() {
    super.initState();
    _controller = FacultyController()..init();
    _titleController = TextEditingController(text: _controller.title);
    _nameController = TextEditingController(text: _controller.facultyName);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
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
            title: Column(
              children: [
                const Text(
                  'Faculty Panel',
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
                      'Layer 1 (BLE) + Layer 3 (GPS)',
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
                if (isRunning) ...[
                  _buildActiveBanner(session, cs),
                  const SizedBox(height: 12),
                  _buildBleCodeBanner(session, cs),
                ],
                if (!isRunning && session != null && session.isExpired)
                  _buildExpiredBanner(session),
                if (isRunning || (session != null && session.isExpired))
                  const SizedBox(height: 14),

                SessionConfigCard(
                  controller: _controller,
                  titleController: _titleController,
                  nameController: _nameController,
                ),
                const SizedBox(height: 20),

                _buildSubmissionsHeader(cs, isRunning),
                const SizedBox(height: 8),

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
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveBanner(AttendanceSession s, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
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
              '${s.directionalModeEnabled ? ' • Front ${s.frontSectorDegrees.toInt()}° (${GeoUtils.headingToLabel(s.facultyHeading)})' : ' • Full 360°'}',
              style: const TextStyle(fontSize: 12),
            ),
          ]),
        ),
        Column(children: [
          const Text('Time Left', style: TextStyle(fontSize: 10)),
          Text(
            GeoUtils.formatDuration(s.remainingTime),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildBleCodeBanner(AttendanceSession s, ColorScheme cs) {
    final codeStr = _controller.bleCurrentCode.toString().padLeft(2, '0');
    final secondsLeft = _controller.bleSecondsUntilRotation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withBlue(220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
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
                  const SizedBox(width: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Rotates in ${secondsLeft}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            codeStr,
            style: const TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
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
            Text(
              '${s.title} — ENDED',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              '${_controller.records.length} submissions recorded.',
              style: const TextStyle(fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSubmissionsHeader(ColorScheme cs, bool isRunning) {
    return Row(children: [
      Icon(Icons.list_alt_rounded, color: cs.primary),
      const SizedBox(width: 8),
      Text(
        'Submissions (${_controller.records.length})',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const Spacer(),
      if (isRunning)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
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
                    color: Colors.green),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No attendance submissions yet',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a session and student attendance marks will stream here live.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
