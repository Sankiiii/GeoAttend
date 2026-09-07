import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../controllers/faculty_controller.dart';
import '../../../utils/geo_utils.dart';
import 'sector_diagram.dart';

class SessionConfigCard extends StatelessWidget {
  final FacultyController controller;
  final TextEditingController titleController;
  final TextEditingController nameController;

  const SessionConfigCard({
    super.key,
    required this.controller,
    required this.titleController,
    required this.nameController,
  });

  String _sectorDescription(double deg) {
    if (deg >= 359) return 'Full 360° circle — no directional restriction';
    if (deg >= 270) return 'Three-quarter arc — very wide front zone';
    if (deg >= 180) return 'Half-circle (${deg.toInt()}°) — students must be in front';
    if (deg >= 90) return 'Quarter-arc (${deg.toInt()}°) — narrow front zone, strict';
    return 'Very narrow (${deg.toInt()}°) — students must face faculty directly';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRunning = controller.activeSession != null &&
        controller.activeSession!.isActive &&
        !controller.activeSession!.isExpired;

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
                isRunning ? 'Configure Next Session' : 'Step 1: Start Session',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
            const Divider(height: 24),

            // Class Title & Faculty Name
            TextField(
              controller: titleController,
              onChanged: controller.setTitle,
              decoration: const InputDecoration(
                labelText: 'Class / Session Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              onChanged: controller.setFacultyName,
              decoration: const InputDecoration(
                labelText: 'Faculty Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // GPS Status Box
            _buildGpsBox(context, cs),
            const SizedBox(height: 16),

            // Geofence Radius Slider
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Geofence Radius',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${controller.radiusMeters.toInt()} m',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ),
            ]),
            Slider(
              value: controller.radiusMeters,
              min: 10,
              max: 200,
              divisions: 38,
              onChanged: controller.setRadius,
            ),

            // Session Duration Slider
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Session Duration',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${controller.durationMinutes} min',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: cs.primary)),
              ),
            ]),
            Slider(
              value: controller.durationMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => controller.setDuration(v.toInt()),
            ),
            const SizedBox(height: 8),

            // Directional Mode Card
            _buildDirectionalCard(context, cs),
            const SizedBox(height: 16),

            // Start Session Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isStartingSession
                    ? null
                    : () async {
                        try {
                          await controller.startSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  controller.directionalMode
                                      ? 'Session started! Directional front ${controller.sectorDegrees.toInt()}° zone active.'
                                      : 'Session started! Full 360° geofence active.',
                                ),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                icon: controller.isStartingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  controller.isStartingSession
                      ? 'Saving to Firebase…'
                      : 'Start Attendance Session',
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

            // End Session Button
            if (isRunning) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await controller.endSession();
                  },
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
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

  Widget _buildGpsBox(BuildContext context, ColorScheme cs) {
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
              icon: controller.isLoadingGps
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              onPressed: controller.isLoadingGps ? null : controller.fetchGps,
              tooltip: 'Refresh GPS',
            ),
          ]),
          if (controller.currentPosition != null) ...[
            Text(
              'Lat: ${controller.currentPosition!.latitude.toStringAsFixed(7)}\nLng: ${controller.currentPosition!.longitude.toStringAsFixed(7)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              'Accuracy: ±${controller.currentPosition!.accuracy.toStringAsFixed(1)} m',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ] else if (controller.gpsError != null)
            Text(controller.gpsError!,
                style: const TextStyle(color: Colors.red, fontSize: 12))
          else
            const Text('Acquiring GPS…', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDirectionalCard(BuildContext context, ColorScheme cs) {
    return Card(
      elevation: 0,
      color: controller.directionalMode
          ? Colors.blue.withOpacity(0.07)
          : Colors.grey.withOpacity(0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: controller.directionalMode
              ? cs.primary.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Only students in front of you can mark attendance',
                style: TextStyle(fontSize: 11),
              ),
              value: controller.directionalMode,
              onChanged: controller.setDirectionalMode,
            ),
            if (controller.directionalMode) ...[
              const Divider(height: 16),
              // Facing Direction slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Facing Direction',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: controller.lockedHeading * math.pi / 180,
                          child: const Icon(Icons.navigation_rounded,
                              size: 16, color: Colors.orange),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${controller.lockedHeading.toInt()}°  ${GeoUtils.headingToLabel(controller.lockedHeading)}',
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
                value: controller.lockedHeading,
                min: 0,
                max: 359,
                divisions: 359,
                activeColor: Colors.orange,
                onChanged: controller.setLockedHeading,
              ),
              Text(
                'Drag to set which direction you face  (0°=N  90°=E  180°=S  270°=W)',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Sector Angle slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Front Zone Width',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      controller.sectorDegrees >= 359
                          ? '360° (Full Circle)'
                          : '${controller.sectorDegrees.toInt()}° arc',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              Slider(
                value: controller.sectorDegrees,
                min: 30,
                max: 360,
                divisions: 33,
                onChanged: controller.setSectorDegrees,
              ),
              Text(
                _sectorDescription(controller.sectorDegrees),
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
                      sectorDegrees: controller.sectorDegrees,
                      headingDeg: controller.lockedHeading,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
