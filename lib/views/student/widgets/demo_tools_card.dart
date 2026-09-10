import 'package:flutter/material.dart';
import '../../../controllers/student_controller.dart';

class DemoToolsCard extends StatelessWidget {
  final StudentController controller;

  const DemoToolsCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.science_rounded, color: cs.primary, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Demo Sandbox Testing Tools',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.primary,
                ),
              ),
            ),
            // Dev-only warning badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: const Text(
                '⚠️ Dev Only',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Simulate distance offset to test in-range / out-of-range scenarios:',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ChoiceChip(
              label: const Text('0 m (exact)'),
              selected: controller.offsetMeters == 0,
              onSelected: (_) => controller.setOffsetMeters(0),
            ),
            ChoiceChip(
              label: const Text('+15 m'),
              selected: controller.offsetMeters == 15,
              onSelected: (_) => controller.setOffsetMeters(15),
            ),
            ChoiceChip(
              label: const Text('+50 m'),
              selected: controller.offsetMeters == 50,
              onSelected: (_) => controller.setOffsetMeters(50),
            ),
            ChoiceChip(
              label: const Text('+150 m'),
              selected: controller.offsetMeters == 150,
              onSelected: (_) => controller.setOffsetMeters(150),
            ),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Simulate Fake / Mock GPS',
              style: TextStyle(fontSize: 12),
            ),
            value: controller.simulateMock,
            onChanged: controller.toggleSimulateMock,
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Simulate BLE Beacon Found (#42)',
              style: TextStyle(fontSize: 12),
            ),
            subtitle: const Text(
              'Tests Layer 1 challenge without a 2nd physical device',
              style: TextStyle(fontSize: 10),
            ),
            value: controller.simulateBeaconFound,
            onChanged: controller.toggleSimulateBeacon,
          ),
        ],
      ),
    );
  }
}
