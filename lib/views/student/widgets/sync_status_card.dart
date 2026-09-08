import 'package:flutter/material.dart';
import '../../../services/sync_queue_service.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final queueService = SyncQueueService();

    return ValueListenableBuilder<int>(
      valueListenable: queueService.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: queueService.isSyncingNotifier,
          builder: (context, isSyncing, _) {
            final hasPending = pendingCount > 0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasPending
                    ? Colors.amber.withOpacity(0.08)
                    : Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPending
                      ? Colors.amber.shade700.withOpacity(0.35)
                      : Colors.green.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPending
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_rounded,
                    color: hasPending ? Colors.amber.shade800 : Colors.green.shade700,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPending
                              ? 'Offline Queue: $pendingCount Pending Sync'
                              : 'Cloud Sync: Active & Synced',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasPending
                                ? Colors.amber.shade900
                                : Colors.green.shade800,
                          ),
                        ),
                        Text(
                          hasPending
                              ? 'Saved safely on phone • Syncs when internet returns'
                              : 'Attendance records backed up to Firebase',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPending)
                    SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: Colors.amber.shade800),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSyncing
                            ? null
                            : () async {
                                final count = await queueService.syncAllPending();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        count > 0
                                            ? 'Successfully synced $count record(s) to cloud! ✅'
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
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync_rounded,
                                      size: 14, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sync',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
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
