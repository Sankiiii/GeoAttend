import 'package:flutter/material.dart';
import '../../../controllers/student_controller.dart';
import '../../../models/attendance_session.dart';

class VerificationBadges extends StatelessWidget {
  final StudentController controller;
  final AttendanceSession session;

  const VerificationBadges({
    super.key,
    required this.controller,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final inR = controller.isWithinRadius;
    final inF = controller.isInFrontSector;
    final mock = controller.isMockDetected;
    final isBleVerified = controller.numberChallengeVerified;
    final isBeaconFound = controller.isBeaconActive;

    return Column(
      children: [
        // Row 1: BLE + Radius
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.bleSessionUuid.isNotEmpty) ...[
              Expanded(
                child: _buildBadge(
                  context,
                  icon: isBleVerified
                      ? Icons.verified_rounded
                      : (isBeaconFound
                          ? Icons.bluetooth_audio_rounded
                          : Icons.bluetooth_searching_rounded),
                  color: isBleVerified
                      ? Colors.green
                      : (isBeaconFound ? Colors.blue : Colors.grey),
                  label: isBleVerified
                      ? 'BLE Verified'
                      : (isBeaconFound ? 'Beacon Found' : 'Scanning BLE'),
                  sub: isBleVerified
                      ? 'Code #${controller.verifiedCode?.toString().padLeft(2, '0')}'
                      : (isBeaconFound ? 'Enter Code' : 'Searching…'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _buildBadge(
                context,
                icon: inR
                    ? Icons.my_location_rounded
                    : Icons.location_off_rounded,
                color: inR ? Colors.green : Colors.red,
                label: inR ? 'In Range' : 'Out of Range',
                sub: '${session.radiusMeters.toInt()} m BLE',
              ),
            ),
          ],
        ),

        // Row 2: Direction + Mock (only if directional mode or always show mock)
        if (session.directionalModeEnabled || true) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session.directionalModeEnabled) ...[
                Expanded(
                  child: _buildBadge(
                    context,
                    icon: inF
                        ? Icons.front_hand_rounded
                        : Icons.back_hand_rounded,
                    color: inF ? Colors.blue : Colors.deepOrange,
                    label: inF ? 'Front Zone' : 'Behind Teacher',
                    sub: '${session.frontSectorDegrees.toInt()}° arc',
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _buildBadge(
                  context,
                  icon: mock ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
                  color: mock ? Colors.orange : Colors.green,
                  label: mock ? 'Fake GPS' : 'Real GPS',
                  sub: mock ? 'Flagged!' : 'Verified',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: color, width: 3),
          left: BorderSide(color: color.withValues(alpha: 0.2)),
          right: BorderSide(color: color.withValues(alpha: 0.2)),
          bottom: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          sub,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}
