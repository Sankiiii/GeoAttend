import 'package:flutter/material.dart';
import '../../../controllers/student_controller.dart';
import '../../../services/ble_scanner_service.dart';
import '../../../utils/geo_utils.dart';

class NearbyBeaconsCard extends StatelessWidget {
  final StudentController controller;

  const NearbyBeaconsCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final beacons = controller.nearbyBeacons;
    final hasBeacons = beacons.isNotEmpty;
    final isScanning = controller.isScanningBle;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasBeacons
              ? Colors.indigo.shade300.withOpacity(0.5)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cell_tower_rounded,
                    color: Colors.indigo.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Nearby Classroom Beacons',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasBeacons
                                  ? Colors.indigo.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${beacons.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: hasBeacons
                                    ? Colors.indigo.shade800
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Direct offline BLE discovery • Tap to verify teacher',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.indigo,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Rescan Beacons',
                  onPressed: isScanning ? null : () => controller.rescanBle(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Beacon List or Scanning Notice
            if (!hasBeacons)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth_searching_rounded,
                      size: 22,
                      color: Colors.indigo.shade400,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.simulateBeaconFound
                            ? 'Simulated Beacon Active (#${controller.simulatedCode})'
                            : 'Scanning for teacher\'s Bluetooth radio... Keep Bluetooth ON and stay within classroom range.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: beacons.map((b) => _buildBeaconTile(context, b)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeaconTile(BuildContext context, BleBeaconResult beacon) {
    final quality = GeoUtils.rssiToSignalQuality(beacon.rssi);
    final qualityColor = _qualityColor(beacon.rssi);
    final isSelected = controller.detectedBeacon?.code == beacon.code;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.indigo.withOpacity(0.08)
            : Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Colors.indigo.shade400
              : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: qualityColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_audio_rounded,
              color: qualityColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      beacon.courseTag != null && beacon.courseTag!.isNotEmpty
                          ? beacon.courseTag!
                          : 'Faculty Beacon',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'CONNECTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 13,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '~${beacon.estimatedDistanceMeters.toStringAsFixed(1)} m away',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•  $quality (${beacon.rssi} dBm)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: qualityColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: qualityColor.withOpacity(0.4)),
            ),
            child: Text(
              quality,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: qualityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _qualityColor(int rssi) {
    if (rssi >= -65) return Colors.green.shade700;
    if (rssi >= -75) return Colors.teal.shade700;
    if (rssi >= -85) return Colors.amber.shade800;
    return Colors.red.shade700;
  }
}
