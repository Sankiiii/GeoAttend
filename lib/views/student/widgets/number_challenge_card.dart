import 'package:flutter/material.dart';
import '../../../controllers/student_controller.dart';

class NumberChallengeCard extends StatelessWidget {
  final StudentController controller;

  const NumberChallengeCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDetected = controller.isBeaconActive;
    final isVerified = controller.numberChallengeVerified;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isVerified
              ? Colors.green.shade400
              : (isDetected ? cs.primary.withOpacity(0.4) : Colors.grey.shade300),
          width: isVerified ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.withOpacity(0.12)
                        : (isDetected ? cs.primary.withOpacity(0.12) : Colors.grey.withOpacity(0.12)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified_rounded
                        : (isDetected ? Icons.bluetooth_audio_rounded : Icons.bluetooth_searching_rounded),
                    color: isVerified
                        ? Colors.green
                        : (isDetected ? cs.primary : Colors.grey),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Layer 1: BLE Number Challenge',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Offline',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isVerified
                            ? 'Physical presence verified'
                            : (isDetected
                                ? 'Beacon detected! Listen to faculty announcement'
                                : 'Scanning for faculty BLE beacon...'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified
                              ? Colors.green.shade700
                              : (isDetected ? cs.primary : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // State 1: Scanning / Not detected yet
            if (!isDetected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Searching for active classroom beacon in BLE range...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]

            // State 2: Verified Successfully
            else if (isVerified) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code #${controller.verifiedCode?.toString().padLeft(2, '0')} Matched!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green.shade900,
                            ),
                          ),
                          Text(
                            'Presence confirmed. Beacon RSSI: ${controller.activeBeaconRssi ?? -60} dBm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: controller.resetChallenge,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ]

            // State 3: Beacon Detected -> 5 Interactive Choices
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tap the 2-digit number announced aloud:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    if (controller.activeBeaconRssi != null)
                      Text(
                        '${controller.activeBeaconRssi} dBm',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 5 Number Options
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: controller.challengeOptions.map((code) {
                  final codeStr = code.toString().padLeft(2, '0');
                  return InkWell(
                    onTap: () => controller.verifyNumberChallenge(code),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 58,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.primary.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        codeStr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (controller.challengeError != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        controller.challengeError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
