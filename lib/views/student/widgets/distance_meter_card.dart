import 'package:flutter/material.dart';
import '../../../models/attendance_session.dart';
import '../../../controllers/student_controller.dart';

class DistanceMeterCard extends StatelessWidget {
  final StudentController controller;
  final AttendanceSession session;

  const DistanceMeterCard({
    super.key,
    required this.controller,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final dist = controller.distanceMeters;
    final inR = controller.isWithinRadius;
    final inF = controller.isInFrontSector;
    final mock = controller.isMockDetected;
    final allowed = inR && inF && !mock;

    final progress = session.radiusMeters > 0
        ? (dist / session.radiusMeters).clamp(0.0, 1.0)
        : 0.0;

    final List<Color> gradientColors = allowed
        ? [Colors.green.shade700, Colors.green.shade400]
        : mock
            ? [Colors.orange.shade700, Colors.orange.shade400]
            : [Colors.red.shade700, Colors.red.shade400];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Status headline ──────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              allowed
                  ? Icons.check_circle_rounded
                  : mock
                      ? Icons.warning_rounded
                      : Icons.cancel_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                allowed
                    ? 'You can mark attendance ✓'
                    : mock
                        ? 'Mock GPS Detected — Not Allowed'
                        : !inR
                            ? 'Outside Bluetooth Range'
                            : 'Behind Faculty — Move Forward',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
          const SizedBox(height: 18),

          // ── Big Distance Counter ─────────────────────────────────────
          Text(
            dist >= 1000
                ? '${(dist / 1000).toStringAsFixed(2)} km'
                : '${dist.toStringAsFixed(1)} m',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 56,
              height: 1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'from faculty / classroom',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),

          // BLE proximity badge
          if (controller.detectedBeacon != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bluetooth_audio_rounded,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'BLE: ~${controller.detectedBeacon!.estimatedMeters.toStringAsFixed(1)} m  •  ${controller.detectedBeacon!.courseCode} (${controller.detectedBeacon!.roomNumber})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // ── Distance progress bar ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 m (Faculty)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
              Text(
                'Max: ${session.radiusMeters.toInt()} m',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inR
                    ? '${(session.radiusMeters - dist).toStringAsFixed(1)} m buffer left'
                    : '${(dist - session.radiusMeters).toStringAsFixed(1)} m over limit',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                inR ? 'Inside Radius ✓' : 'Outside Radius ✗',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
