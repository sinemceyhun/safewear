import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/emergency_actions_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sample = s.latest;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _kv('Mode', s.dataSource.name)),
            const SizedBox(width: 12),
            Expanded(child: _kv('BLE', s.connectionState.name)),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest sample', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _kv('HR', sample?.hr?.toString() ?? '—'),
                _kv('SpO₂', sample?.spo2 != null ? '${sample!.spo2}%' : '—'),
                _kv('Accel |a|', sample?.accelMag?.toStringAsFixed(2) ?? '—'),
                _kv('Timestamp', sample?.ts.toIso8601String() ?? '—'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: ListTile(
            title: const Text('Alerts (latest)'),
            subtitle: Text(s.alerts.isEmpty ? 'No alerts' : '${s.alerts.first.type}: ${s.alerts.first.message}'),
          ),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          icon: const Icon(Icons.warning_amber),
          label: const Text('Emergency'),
          onPressed: () async {
            const reason = 'In-app emergency button';
            await context.read<AppState>().triggerEmergency(reason: reason);

            if (!context.mounted) return;

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const EmergencyActionsSheet(reason: reason),
            );
          },
        ),
      ],
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
