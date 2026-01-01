import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final bool isConnected = s.connectionState == BluetoothConnectionState.connected;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: s.scanning ? null : () => context.read<AppState>().startBleScan(),
                  child: Text(s.scanning ? 'Scanning…' : 'Start Scan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: s.scanning ? () => context.read<AppState>().stopBleScan() : null,
                  child: const Text('Stop Scan'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isConnected ? () => context.read<AppState>().disconnectBle() : null,
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: s.scanResults.isEmpty
                ? const Center(child: Text('No devices yet. (Real phone required for BLE scan)'))
                : ListView.builder(
              itemCount: s.scanResults.length,
              itemBuilder: (context, i) {
                final r = s.scanResults[i];
                final name = r.device.localName.isEmpty ? '(no name)' : r.device.localName;

                return Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text(r.device.id.toString()),
                    trailing: Text('RSSI ${r.rssi}'),
                    onTap: () => context.read<AppState>().connectBle(r),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
