import 'package:flutter/material.dart';
import '../../../models/attendance_record.dart';
import '../../../models/attendance_status.dart';
import '../../../utils/geo_utils.dart';

class SubmissionCard extends StatelessWidget {
  final AttendanceRecord record;
  final double sessionRadius;
  final Function(String id, AttendanceStatus status, String remark) onReview;

  const SubmissionCard({
    super.key,
    required this.record,
    required this.sessionRadius,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWithinRadius = record.distanceMeters <= sessionRadius;
    final statusColor = record.status.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Identity Header & Badge
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withOpacity(0.12),
                child: Text(
                  record.studentName.isNotEmpty
                      ? record.studentName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll: ${record.rollNo}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildBadge(record.status),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                tooltip: 'Faculty Override',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'approve') {
                    onReview(
                      record.id,
                      AttendanceStatus.manuallyApproved,
                      'Force-approved by faculty override',
                    );
                  } else if (val == 'reject') {
                    onReview(
                      record.id,
                      AttendanceStatus.manuallyRejected,
                      'Force-rejected by faculty override',
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'approve',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Force Approve (Override)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reject',
                    child: Row(
                      children: [
                        Icon(Icons.highlight_off_rounded, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Force Reject (Override)'),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 10),

            // Prominent Meter Distance Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isWithinRadius
                    ? Colors.green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWithinRadius
                      ? Colors.green.withOpacity(0.25)
                      : Colors.red.withOpacity(0.25),
                ),
              ),
              child: Row(children: [
                Icon(
                  isWithinRadius
                      ? Icons.straighten_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: isWithinRadius
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade900),
                      children: [
                        const TextSpan(text: 'Distance to You: '),
                        TextSpan(
                          text: '${record.distanceMeters.toStringAsFixed(1)} m  ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isWithinRadius
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                        TextSpan(
                          text: isWithinRadius
                              ? '(Inside ${sessionRadius.toInt()}m BLE range • ${(sessionRadius - record.distanceMeters).toStringAsFixed(1)}m buffer)'
                              : '(Exceeds ${sessionRadius.toInt()}m BLE range by ${(record.distanceMeters - sessionRadius).toStringAsFixed(1)}m)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isWithinRadius
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),

            // Metrics Chips
            Wrap(spacing: 8, runSpacing: 6, children: [
              _buildChip(
                record.isInFrontSector
                    ? Icons.front_hand_rounded
                    : Icons.back_hand_rounded,
                record.isInFrontSector
                    ? 'Front Zone (${record.bearingToStudent.toStringAsFixed(0)}° ${GeoUtils.headingToLabel(record.bearingToStudent)})'
                    : 'Behind Teacher (${record.bearingToStudent.toStringAsFixed(0)}° ${GeoUtils.headingToLabel(record.bearingToStudent)})',
                record.isInFrontSector
                    ? Colors.blue.shade700
                    : Colors.deepOrange,
              ),
              _buildChip(
                record.isMocked
                    ? Icons.location_off_rounded
                    : Icons.verified_user_rounded,
                record.isMocked ? 'Mock GPS Detected' : 'Hardware GPS',
                record.isMocked ? Colors.orange.shade800 : Colors.green.shade700,
              ),
              if (record.bleVerified)
                _buildChip(
                  Icons.bluetooth_connected_rounded,
                  'BLE Code #${record.bleCodeUsed?.toString().padLeft(2, '0') ?? '✓'} Verified',
                  Colors.indigo.shade700,
                ),
              _buildChip(
                Icons.access_time_rounded,
                '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}:${record.timestamp.second.toString().padLeft(2, '0')}',
                Colors.grey.shade700,
              ),
            ]),

            if (record.remarks != null && record.remarks!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.remarks!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Action buttons if submission is reviewable
            if (record.status.canReview) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onReview(
                      record.id,
                      AttendanceStatus.manuallyApproved,
                      'Manually approved by faculty',
                    ),
                    icon: const Icon(Icons.check_rounded,
                        size: 15, color: Colors.green),
                    label: const Text('Approve',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onReview(
                      record.id,
                      AttendanceStatus.manuallyRejected,
                      'Manually rejected by faculty',
                    ),
                    icon: const Icon(Icons.close_rounded,
                        size: 15, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildBadge(AttendanceStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status.icon, size: 12, color: status.color),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: status.color,
          ),
        ),
      ]),
    );
  }
}
