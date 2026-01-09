import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/ble_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  String? _errorMessage;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _adapterSub = BleService.adapterStateStream.listen((state) {
      setState(() {
        _adapterState = state;
      });
    });
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _clearError() {
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _startScan() async {
    _clearError();
    try {
      await context.read<AppState>().startBleScan();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _connect(ScanResult r) async {
    _clearError();
    setState(() {
      _isConnecting = true;
    });
    try {
      await context.read<AppState>().connectBle(r);
    } catch (e) {
      _showError('Bağlantı hatası: ${e.toString()}');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final bool isConnected =
        s.connectionState == BluetoothConnectionState.connected;
    final bool bluetoothOff = _adapterState != BluetoothAdapterState.on;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bluetooth Status Card
          _buildBluetoothStatusCard(bluetoothOff, isConnected),

          const SizedBox(height: 16),

          // Error Message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearError,
                    iconSize: 18,
                  ),
                ],
              ),
            ),

          if (_errorMessage != null) const SizedBox(height: 12),

          // Scan / Disconnect Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (s.scanning || bluetoothOff || isConnected || _isConnecting)
                      ? null
                      : _startScan,
                  icon: s.scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(s.scanning ? 'Taranıyor…' : 'Tara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: s.scanning
                      ? () => context.read<AppState>().stopBleScan()
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Durdur'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isConnected)
            ElevatedButton.icon(
              onPressed: () => context.read<AppState>().disconnectBle(),
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Bağlantıyı Kes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),

          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: _buildDeviceList(s),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothStatusCard(bool bluetoothOff, bool isConnected) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (bluetoothOff) {
      statusColor = Colors.red;
      statusIcon = Icons.bluetooth_disabled;
      statusText = 'Bluetooth Kapalı';
    } else if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.bluetooth_connected;
      statusText = 'Bağlı';
    } else if (_isConnecting) {
      statusColor = Colors.orange;
      statusIcon = Icons.bluetooth_searching;
      statusText = 'Bağlanıyor…';
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.bluetooth;
      statusText = 'Bluetooth Açık';
    }

    return Card(
      color: statusColor.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (bluetoothOff)
                    const Text(
                      'Cihaz taraması için Bluetooth\'u açın',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (bluetoothOff)
              ElevatedButton(
                onPressed: () async {
                  try {
                    await BleService.turnOnBluetooth();
                  } catch (e) {
                    _showError('Bluetooth açılamadı: $e');
                  }
                },
                child: const Text('Aç'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(AppState s) {
    if (s.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Cihaz bulunamadı',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"Tara" butonuna basarak ESP32 cihazını arayın',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: s.scanResults.length,
      itemBuilder: (context, i) {
        final r = s.scanResults[i];
        final name =
            r.device.platformName.isEmpty ? '(isimsiz)' : r.device.platformName;

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: name.contains('ESP32') ? Colors.blue : Colors.grey,
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight:
                    name.contains('ESP32') ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(r.device.remoteId.toString()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RSSI ${r.rssi}',
                  style: TextStyle(
                    color: r.rssi > -60
                        ? Colors.green
                        : r.rssi > -80
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _isConnecting ? null : () => _connect(r),
          ),
        );
      },
    );
  }
}
