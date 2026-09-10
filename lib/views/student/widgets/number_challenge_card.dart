import 'package:flutter/material.dart';
import '../../../controllers/student_controller.dart';
import '../../../services/ble_scanner_service.dart';

class NumberChallengeCard extends StatefulWidget {
  final StudentController controller;

  const NumberChallengeCard({
    super.key,
    required this.controller,
  });

  @override
  State<NumberChallengeCard> createState() => _NumberChallengeCardState();
}

class _NumberChallengeCardState extends State<NumberChallengeCard> {
  final TextEditingController _manualInputController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isDetected = controller.isBeaconActive;
    final isVerified = controller.numberChallengeVerified;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isVerified
              ? Colors.green.shade400
              : (isDetected
                  ? cs.primary.withValues(alpha: 0.35)
                  : Colors.grey.shade200),
          width: isVerified ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.green.withValues(alpha: 0.12)
                        : (isDetected
                            ? cs.primary.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVerified
                        ? Icons.verified_rounded
                        : (isDetected
                            ? Icons.bluetooth_audio_rounded
                            : Icons.bluetooth_searching_rounded),
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
                          const Flexible(
                            child: Text(
                              'Layer 1: BLE Proximity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDetected
                                  ? Colors.blue.withValues(alpha: 0.12)
                                  : Colors.blueGrey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              controller.detectedBeacon != null
                                  ? 'BLE Active'
                                  : (isDetected ? 'Cloud Sync' : 'Searching'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDetected
                                    ? Colors.blue.shade800
                                    : Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isVerified
                            ? 'Physical presence verified ✓'
                            : (isDetected
                                ? 'Beacon detected! Listen to faculty'
                                : 'Scanning for faculty BLE beacon...'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified
                              ? Colors.green.shade700
                              : (isDetected ? cs.primary : Colors.grey.shade600),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!isVerified)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Rescan BLE',
                    onPressed: () {
                      controller.rescanBle();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Scanning for faculty BLE beacon...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Beacon observation banner ────────────────────────────────
            if (controller.detectedBeacon != null)
              _buildBeaconObservationBanner(
                  context, cs, controller.detectedBeacon!),

            // ── State 1: Verified ────────────────────────────────────────
            if (isVerified) ...[
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
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 30),
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
                            'Presence confirmed  •  RSSI: ${controller.activeBeaconRssi ?? -60} dBm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
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

            // ── State 2: Code options ────────────────────────────────────
            else if (isDetected && controller.challengeOptions.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Tap the 2-digit number announced aloud:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
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
              const SizedBox(height: 14),

              // 5 Number Options — larger and more tappable
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: controller.challengeOptions.map((code) {
                  final codeStr = code.toString().padLeft(2, '0');
                  return InkWell(
                    onTap: () => controller.verifyNumberChallenge(code),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 66,
                      height: 60,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        codeStr,
                        style: TextStyle(
                          fontSize: 22,
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
                _buildErrorRow(controller.challengeError!),
              ],
            ]

            // ── State 3: Searching / manual fallback ─────────────────────
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Searching for classroom beacon in BLE range...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showManualEntry = !_showManualEntry;
                            });
                          },
                          child: Text(
                            _showManualEntry ? 'Hide' : 'Type Code',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_showManualEntry) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualInputController,
                              keyboardType: TextInputType.number,
                              maxLength: 2,
                              decoration: const InputDecoration(
                                hintText: 'Enter 2-digit code',
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              controller
                                  .verifyManualCode(_manualInputController.text);
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (controller.challengeError != null) ...[
                const SizedBox(height: 10),
                _buildErrorRow(controller.challengeError!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRow(String error) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            error,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeaconObservationBanner(
      BuildContext context, ColorScheme cs, BleBeaconResult beacon) {
    final dist = beacon.estimatedMeters;
    final inRange = beacon.isWithinRadius;
    final crcHex =
        beacon.checksum.toRadixString(16).padLeft(4, '0').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: beacon.isCrcValid ? cs.primary : Colors.red.shade400,
            width: 3,
          ),
          right: BorderSide(
            color: beacon.isCrcValid
                ? cs.primary.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
          ),
          top: BorderSide(
            color: beacon.isCrcValid
                ? cs.primary.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
          ),
          bottom: BorderSide(
            color: beacon.isCrcValid
                ? cs.primary.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.sensors_rounded, size: 15, color: cs.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${beacon.courseCode}  •  Room ${beacon.roomNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: beacon.isCrcValid
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  beacon.isCrcValid ? 'CRC: 0x$crcHex ✓' : 'CRC Error ✗',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: beacon.isCrcValid
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Prof ${beacon.facultyInitials}  •  ⏱️ ${beacon.remainingMinutes} min left',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dist >= 0
                    ? '~${dist.toStringAsFixed(1)} m / ${beacon.allowedRadius} m'
                    : '${beacon.allowedRadius} m max',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: inRange ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
