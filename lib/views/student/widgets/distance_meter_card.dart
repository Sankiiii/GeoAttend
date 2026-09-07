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

    return Container(
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
          // Status Icon & Status Headline
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
            Flexible(
              child: Text(
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
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Big Distance Counter
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
            const SizedBox(height: 4),
            Text(
              'from faculty / classroom',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Distance Linear Gauge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 m (Faculty)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Limit: ${session.radiusMeters.toInt()} m',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
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
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    inR
                        ? '${(session.radiusMeters - dist).toStringAsFixed(1)} m buffer left'
                        : '${(dist - session.radiusMeters).toStringAsFixed(1)} m over limit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    inR ? 'Inside Radius ✓' : 'Outside Radius ✗',
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
    );
  }
}
