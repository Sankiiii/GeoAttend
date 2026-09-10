import 'package:flutter/material.dart';
import '../../../controllers/faculty_controller.dart';
import '../../../utils/geo_utils.dart';
import 'sector_diagram.dart';

class SessionConfigCard extends StatelessWidget {
  final FacultyController controller;
  final TextEditingController titleController;
  final TextEditingController nameController;
  final TextEditingController? roomController;

  const SessionConfigCard({
    super.key,
    required this.controller,
    required this.titleController,
    required this.nameController,
    this.roomController,
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRunning ? 'LIVE' : 'STEP 1',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRunning ? 'Configure Next Session' : 'Start Attendance Session',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.add_location_alt_rounded, color: cs.primary, size: 20),
            ]),
            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 10),

            // ── Class Title ─────────────────────────────────────────────
            TextField(
              controller: titleController,
              onChanged: controller.setTitle,
              decoration: const InputDecoration(
                labelText: 'Class / Session Title (e.g. CS101)',
                prefixIcon: Icon(Icons.class_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // ── Faculty Name & Room ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: nameController,
                    onChanged: controller.setFacultyName,
                    decoration: const InputDecoration(
                      labelText: 'Faculty Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: roomController,
                    onChanged: controller.setRoomNumber,
                    decoration: const InputDecoration(
                      labelText: 'Room / Hall',
                      hintText: 'LH-1',
                      prefixIcon: Icon(Icons.meeting_room_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── GPS Box ─────────────────────────────────────────────────
            _buildGpsBox(context, cs),
            const SizedBox(height: 18),

            // ── BLE Range ───────────────────────────────────────────────
            _buildSectionLabel(
              context,
              icon: Icons.bluetooth_rounded,
              title: 'Bluetooth Range (BLE Proximity)',
              badge: '${controller.radiusMeters.toInt()} m',
              badgeColor: cs.primary,
            ),
            const SizedBox(height: 6),
            Slider(
              value: controller.radiusMeters.clamp(5.0, 60.0),
              min: 5,
              max: 60,
              divisions: 11,
              label: '${controller.radiusMeters.toInt()} m',
              onChanged: controller.setRadius,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [5, 15, 30, 45, 60].map((m) {
                final selected = controller.radiusMeters.toInt() == m;
                return ChoiceChip(
                  label: Text(m == 60 ? '60m (Max)' : '${m}m'),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => controller.setRadius(m.toDouble()),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              '5 m min  •  60 m max (BLE physical limit)',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // ── Session Duration ────────────────────────────────────────
            _buildSectionLabel(
              context,
              icon: Icons.timer_outlined,
              title: 'Session Duration',
              badge: '${controller.durationMinutes} min',
              badgeColor: cs.secondary,
            ),
            const SizedBox(height: 4),
            Slider(
              value: controller.durationMinutes.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              onChanged: (v) => controller.setDuration(v.toInt()),
            ),
            const SizedBox(height: 10),

            // ── Directional Mode Card ───────────────────────────────────
            _buildDirectionalCard(context, cs),
            const SizedBox(height: 18),

            // ── Start Button ────────────────────────────────────────────
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
                                      ? 'Session started! Front ${controller.sectorDegrees.toInt()}° zone active.'
                                      : 'Session started! Full 360° Bluetooth range active.',
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
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // ── End Session Button ──────────────────────────────────────
            if (isRunning) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async => controller.endSession(),
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                  label: const Text('End Session Now',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Reusable labeled section header with a colored badge
  Widget _buildSectionLabel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: badgeColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsBox(BuildContext context, ColorScheme cs) {
    final hasGps = controller.currentPosition != null;
    final hasError = controller.gpsError != null;
    final dotColor = hasGps
        ? Colors.green
        : hasError
            ? Colors.red
            : Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Classroom GPS (Faculty Location)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              GestureDetector(
                onTap: controller.isLoadingGps ? null : controller.fetchGps,
                child: controller.isLoadingGps
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded,
                        size: 18, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (hasGps) ...[
            const SizedBox(height: 6),
            Text(
              '${controller.currentPosition!.latitude.toStringAsFixed(6)}, '
              '${controller.currentPosition!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            Text(
              'Accuracy: ±${controller.currentPosition!.accuracy.toStringAsFixed(1)} m',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ] else if (hasError) ...[
            const SizedBox(height: 6),
            Text(controller.gpsError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ] else ...[
            const SizedBox(height: 6),
            Text('Acquiring GPS…',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectionalCard(BuildContext context, ColorScheme cs) {
    final isOn = controller.directionalMode;
    return Container(
      decoration: BoxDecoration(
        color: isOn
            ? Colors.blue.withValues(alpha: 0.05)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: isOn ? cs.primary : Colors.grey.shade300,
            width: 4,
          ),
          right: BorderSide(color: isOn ? cs.primary.withValues(alpha: 0.15) : Colors.grey.shade200),
          top: BorderSide(color: isOn ? cs.primary.withValues(alpha: 0.15) : Colors.grey.shade200),
          bottom: BorderSide(color: isOn ? cs.primary.withValues(alpha: 0.15) : Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                '🧭  Directional Mode (Front-Side Only)',
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
              _buildSectionLabel(
                context,
                icon: Icons.navigation_rounded,
                title: 'Facing Direction',
                badge:
                    '${controller.lockedHeading.toInt()}°  ${GeoUtils.headingToLabel(controller.lockedHeading)}',
                badgeColor: Colors.orange,
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
                '0° = North  •  90° = East  •  180° = South  •  270° = West',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Sector Angle slider
              _buildSectionLabel(
                context,
                icon: Icons.pie_chart_outline_rounded,
                title: 'Front Zone Width',
                badge: controller.sectorDegrees >= 359
                    ? '360° (Full)'
                    : '${controller.sectorDegrees.toInt()}° arc',
                badgeColor: cs.primary,
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
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

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
