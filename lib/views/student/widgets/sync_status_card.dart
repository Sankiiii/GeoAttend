import 'package:flutter/material.dart';
import '../../../services/sync_queue_service.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final queueService = SyncQueueService();

    return ValueListenableBuilder<int>(
      valueListenable: queueService.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: queueService.isSyncingNotifier,
          builder: (context, isSyncing, _) {
            final hasPending = pendingCount > 0;
            final statusColor =
                hasPending ? Colors.amber.shade800 : Colors.green.shade700;
            final bgColor = hasPending
                ? Colors.amber.withValues(alpha: 0.07)
                : Colors.green.withValues(alpha: 0.06);
            final borderColor = hasPending
                ? Colors.amber.shade700.withValues(alpha: 0.3)
                : Colors.green.withValues(alpha: 0.25);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  // Icon with tinted square container
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      hasPending
                          ? Icons.cloud_upload_outlined
                          : Icons.cloud_done_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPending
                              ? 'Offline Queue: $pendingCount Pending'
                              : 'Cloud Sync: Active & Synced',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          hasPending
                              ? 'Saved on device  •  Auto-syncs when online'
                              : 'All attendance backed up to Firebase',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPending)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade50,
                        foregroundColor: Colors.amber.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: isSyncing
                          ? null
                          : () async {
                              final count =
                                  await queueService.syncAllPending();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      count > 0
                                          ? 'Synced $count record(s) to cloud! ✅'
                                          : 'Still offline. Will retry automatically.',
                                    ),
                                    backgroundColor: count > 0
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                );
                              }
                            },
                      child: isSyncing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.amber.shade900,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_rounded, size: 14),
                                SizedBox(width: 4),
                                Text('Sync',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
