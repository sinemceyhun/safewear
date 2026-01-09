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

  /// Check if Bluetooth adapter is on
  static Future<bool> isBluetoothOn() async {
    try {
      print('[BLE] Bluetooth adapter durumu kontrol ediliyor...');
      final state = await FlutterBluePlus.adapterState.first;
      print('[BLE] Adapter durumu: $state');
      return state == BluetoothAdapterState.on;
    } catch (e) {
      print('[BLE] Adapter durumu kontrol hatası: $e');
      return false;
    }
  }

  /// Stream for Bluetooth adapter state changes
  static Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;

  /// Request user to turn on Bluetooth (Android only)
  static Future<void> turnOnBluetooth() async {
    print('[BLE] Bluetooth açılması isteniyor...');
    await FlutterBluePlus.turnOn();
  }

  /// Check if currently connected
  bool get isConnected => _device != null && _notifyChar != null;

  /// Get connected device name
  String? get connectedDeviceName => _device?.platformName;

  Future<void> startScan({
    required void Function(List<ScanResult>) onResults,
    required void Function(Object e) onError,
    String? nameFilter,
  }) async {
    print('[BLE] ========== TARAMA BAŞLATILIYOR ==========');
    print('[BLE] Filtre: "$nameFilter"');
    
    // Cancel any existing subscription
    await _scanSub?.cancel();
    _scanSub = null;

    // Check adapter state first
    print('[BLE] Adapter kontrolü yapılıyor...');
    final adapterOn = await isBluetoothOn();
    if (!adapterOn) {
      print('[BLE] HATA: Bluetooth kapalı!');
      onError(StateError('Bluetooth kapalı. Lütfen Bluetooth\'u açın.'));
      return;
    }
    print('[BLE] Bluetooth AÇIK ✓');

    final filter = (nameFilter ?? '').trim().toLowerCase();
    print('[BLE] Filtre (lowercase): "$filter"');

    try {
      // Use onScanResults which is the newer recommended stream
      print('[BLE] onScanResults listener kaydediliyor...');
      _scanSub = FlutterBluePlus.onScanResults.listen(
        (results) {
          print('[BLE] ===== SCAN SONUÇLARI GELDİ =====');
          print('[BLE] Bulunan cihaz sayısı: ${results.length}');
          
          for (final r in results) {
            final name = r.device.platformName.isEmpty ? "(isimsiz)" : r.device.platformName;
            final advName = r.advertisementData.advName;
            print('[BLE]   - $name | advName: $advName | ${r.device.remoteId} | RSSI: ${r.rssi}');
          }
          
          final filtered = filter.isEmpty
              ? results
              : results.where((r) {
                  final name = r.device.platformName.toLowerCase();
                  final advName = r.advertisementData.advName.toLowerCase();
                  final matches = name.contains(filter) || advName.contains(filter);
                  if (matches) {
                    print('[BLE] FİLTRE EŞLEŞTİ: ${r.device.platformName}');
                  }
                  return matches;
                }).toList();

          print('[BLE] Filtreden geçen cihaz sayısı: ${filtered.length}');
          onResults(filtered);
        },
        onError: (e) {
          print('[BLE] SCAN RESULTS HATA: $e');
          onError(e);
        },
      );
      print('[BLE] Listener kayıt edildi ✓');

      // Start the scan and AWAIT it
      print('[BLE] FlutterBluePlus.startScan() BAŞLATILIYOR (timeout: 15s)...');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
      print('[BLE] Tarama timeout ile tamamlandı');
      
    } catch (e) {
      print('[BLE] TARAMA HATASI: $e');
      await _scanSub?.cancel();
      _scanSub = null;
      onError(e);
    }
  }

  Future<void> stopScan() async {
    print('[BLE] Tarama durduruluyor...');
    
    await _scanSub?.cancel();
    _scanSub = null;
    
    try {
      await FlutterBluePlus.stopScan();
      print('[BLE] Tarama durduruldu ✓');
    } catch (e) {
      print('[BLE] Tarama durdurma hatası (görmezden geliniyor): $e');
    }
  }

  Future<void> connectAndSubscribe({
    required ScanResult target,
    required BleConfig config,
    required void Function(BluetoothConnectionState s) onConnectionState,
    required void Function(String line) onLine,
    void Function(Object error)? onError,
  }) async {
    print('[BLE] ========== BAĞLANTI BAŞLATILIYOR ==========');
    print('[BLE] Cihaz: ${target.device.platformName} (${target.device.remoteId})');
    print('[BLE] Service UUID: ${config.serviceUuid}');
    print('[BLE] Notify Char UUID: ${config.notifyCharUuid}');
    
    // Stop scanning first
    await stopScan();
    await disconnect();

    final device = target.device;
    _device = device;

    await _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      print('[BLE] Bağlantı durumu değişti: $state');
      onConnectionState(state);
    });

    try {
      // Connect with timeout
      print('[BLE] Cihaza bağlanılıyor (timeout: 15s)...');
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      print('[BLE] Bağlantı kuruldu ✓');

      // Small delay for connection to stabilize
      print('[BLE] Bağlantı stabilizasyonu için bekleniyor (500ms)...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Discover services
      print('[BLE] Servisler keşfediliyor...');
      final services = await device.discoverServices();
      print('[BLE] Bulunan servis sayısı: ${services.length}');
      for (final svc in services) {
        print('[BLE]   - Service: ${svc.uuid}');
        for (final c in svc.characteristics) {
          print('[BLE]     - Char: ${c.uuid} (notify: ${c.properties.notify})');
        }
      }
      
      BluetoothService? targetService;
      for (final svc in services) {
        if (svc.uuid == config.serviceUuid) {
          targetService = svc;
          break;
        }
      }
      
      if (targetService == null) {
        print('[BLE] HATA: Hedef servis bulunamadı!');
        throw StateError('Service bulunamadı: ${config.serviceUuid}');
      }
      print('[BLE] Hedef servis bulundu ✓');

      BluetoothCharacteristic? targetChar;
      for (final c in targetService.characteristics) {
        if (c.uuid == config.notifyCharUuid) {
          targetChar = c;
          break;
        }
      }
      
      if (targetChar == null) {
        print('[BLE] HATA: Hedef characteristic bulunamadı!');
        throw StateError('Notify characteristic bulunamadı: ${config.notifyCharUuid}');
      }
      print('[BLE] Hedef characteristic bulundu ✓');

      _notifyChar = targetChar;

      // Enable notifications
      print('[BLE] Notifications aktifleştiriliyor...');
      await _notifyChar!.setNotifyValue(true);
      print('[BLE] Notifications aktif ✓');

      await Future.delayed(const Duration(milliseconds: 200));

      await _notifySub?.cancel();
      print('[BLE] Veri dinleyici kaydediliyor...');
      _notifySub = _notifyChar!.onValueReceived.listen((bytes) {
        final chunk = utf8.decode(bytes, allowMalformed: true);
        print('[BLE] VERİ ALINDI (${bytes.length} bytes): $chunk');
        _rxBuffer += chunk;

        while (true) {
          final idx = _rxBuffer.indexOf('\n');
          if (idx < 0) break;

          final line = _rxBuffer.substring(0, idx).trim();
          _rxBuffer = _rxBuffer.substring(idx + 1);

          if (line.isNotEmpty) {
            print('[BLE] SATIR PARSE EDİLDİ: $line');
            onLine(line);
          }
        }
      });
      print('[BLE] ========== BAĞLANTI TAMAMLANDI ✓ ==========');
    } catch (e) {
      print('[BLE] ========== BAĞLANTI HATASI ==========');
      print('[BLE] Hata: $e');
      await disconnect();
      if (onError != null) {
        onError(e);
      } else {
        rethrow;
      }
    }
  }

  Future<void> disconnect() async {
    print('[BLE] Bağlantı kesiliyor...');
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
        print('[BLE] Bağlantı kesildi ✓');
      } catch (_) {}
    }

    _device = null;
    _rxBuffer = '';
  }
}
