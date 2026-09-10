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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left status stripe ─────────────────────────────────────────
          Container(
            width: 5,
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),

          // ── Card content ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student identity header
                  Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        record.studentName.isNotEmpty
                            ? record.studentName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cs.onPrimaryContainer,
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
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                  ]),
                  const SizedBox(height: 10),

                  // Distance row
                  _buildDistanceRow(isWithinRadius),
                  const SizedBox(height: 8),

                  // Metrics
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _buildChip(
                      record.isInFrontSector
                          ? Icons.front_hand_rounded
                          : Icons.back_hand_rounded,
                      record.isInFrontSector
                          ? 'Front ${record.bearingToStudent.toStringAsFixed(0)}° ${GeoUtils.headingToLabel(record.bearingToStudent)}'
                          : 'Behind Teacher ${record.bearingToStudent.toStringAsFixed(0)}°',
                      record.isInFrontSector
                          ? Colors.blue.shade700
                          : Colors.deepOrange,
                    ),
                    _buildChip(
                      record.isMocked
                          ? Icons.location_off_rounded
                          : Icons.verified_user_rounded,
                      record.isMocked ? 'Mock GPS' : 'Hardware GPS',
                      record.isMocked
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                    if (record.bleVerified)
                      _buildChip(
                        Icons.bluetooth_connected_rounded,
                        'BLE #${record.bleCodeUsed?.toString().padLeft(2, '0') ?? '✓'}',
                        Colors.indigo.shade700,
                      ),
                    _buildChip(
                      Icons.access_time_rounded,
                      '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}:${record.timestamp.second.toString().padLeft(2, '0')}',
                      Colors.grey.shade600,
                    ),
                  ]),

                  // Remark
                  if (record.remarks != null && record.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.06),
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

                  // Review buttons
                  if (record.status.canReview) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => onReview(
                            record.id,
                            AttendanceStatus.manuallyApproved,
                            'Manually approved by faculty',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 15),
                              SizedBox(width: 4),
                              Text('Approve', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onReview(
                            record.id,
                            AttendanceStatus.manuallyRejected,
                            'Manually rejected by faculty',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded, size: 15),
                              SizedBox(width: 4),
                              Text('Reject', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceRow(bool isWithinRadius) {
    final color = isWithinRadius ? Colors.green.shade700 : Colors.red.shade700;
    final bufferText = isWithinRadius
        ? '${(sessionRadius - record.distanceMeters).toStringAsFixed(1)} m buffer'
        : '${(record.distanceMeters - sessionRadius).toStringAsFixed(1)} m over';

    return Row(children: [
      Icon(
        isWithinRadius ? Icons.straighten_rounded : Icons.warning_amber_rounded,
        size: 16,
        color: color,
      ),
      const SizedBox(width: 6),
      RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(
              text: '${record.distanceMeters.toStringAsFixed(1)} m  ',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            TextSpan(
              text: '($bufferText)',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }

  Widget _buildBadge(AttendanceStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status.icon, size: 11, color: status.color),
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
