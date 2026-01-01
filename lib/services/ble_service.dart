import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleConfig {
  final String deviceNameFilter;
  final Guid serviceUuid;
  final Guid notifyCharUuid;

  const BleConfig({
    required this.deviceNameFilter,
    required this.serviceUuid,
    required this.notifyCharUuid,
  });
}

class BleService {
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyChar;

  String _rxBuffer = '';

  Future<void> startScan({
    required void Function(List<ScanResult>) onResults,
    required void Function(Object e) onError,
    String? nameFilter,
  }) async {
    // ensure a clean scan start
    await stopScan();

    final filter = (nameFilter ?? '').trim().toLowerCase();

    _scanSub = FlutterBluePlus.scanResults.listen(
          (results) {
        final filtered = filter.isEmpty
            ? results
            : results.where((r) {
          final name = r.device.localName.toLowerCase();
          return name.contains(filter);
        }).toList();

        onResults(filtered);
      },
      onError: onError,
    );

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // ignore if not scanning
    }

    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> connectAndSubscribe({
    required ScanResult target,
    required BleConfig config,
    required void Function(BluetoothConnectionState s) onConnectionState,
    required void Function(String line) onLine,
  }) async {
    await disconnect();

    final device = target.device;
    _device = device;

    await _connSub?.cancel();
    _connSub = device.connectionState.listen(onConnectionState);

    await device.connect(timeout: const Duration(seconds: 15));

    final services = await device.discoverServices();
    final svc = services.where((s) => s.uuid == config.serviceUuid).toList();
    if (svc.isEmpty) {
      throw StateError('Service not found: ${config.serviceUuid}');
    }

    final chars =
    svc.first.characteristics.where((c) => c.uuid == config.notifyCharUuid).toList();
    if (chars.isEmpty) {
      throw StateError('Notify characteristic not found: ${config.notifyCharUuid}');
    }

    _notifyChar = chars.first;

    // Enable notifications first
    await _notifyChar!.setNotifyValue(true);

    await _notifySub?.cancel();
    _notifySub = _notifyChar!.onValueReceived.listen((bytes) {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      _rxBuffer += chunk;

      while (true) {
        final idx = _rxBuffer.indexOf('\n');
        if (idx < 0) break;

        final line = _rxBuffer.substring(0, idx).trim();
        _rxBuffer = _rxBuffer.substring(idx + 1);

        if (line.isNotEmpty) onLine(line);
      }
    });
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;

    if (_notifyChar != null) {
      try {
        await _notifyChar!.setNotifyValue(false);
      } catch (_) {}
    }
    _notifyChar = null;

    await _connSub?.cancel();
    _connSub = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
        // If your flutter_blue_plus version has it, prefer:
        // await _device!.disconnectAndUpdateStream();
      } catch (_) {}
    }

    _device = null;
    _rxBuffer = '';
  }
}
