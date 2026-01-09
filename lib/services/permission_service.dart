import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Call this before BLE scan/connect and before showing notifications.
  static Future<void> ensurePermissions() async {
    print('[İZİN] ========== İZİN KONTROLÜ ==========');
    
    if (!Platform.isAndroid) {
      print('[İZİN] Android değil, atlanıyor');
      return;
    }

    // Get Android SDK version
    final isAndroid12Plus = await _isAndroid12OrHigher();
    print('[İZİN] Android 12+: $isAndroid12Plus');

    final requests = <Permission>[];

    if (isAndroid12Plus) {
      // Android 12+ (API 31+) - BLE specific permissions
      print('[İZİN] Android 12+ izinleri isteniyor: bluetoothScan, bluetoothConnect');
      requests.add(Permission.bluetoothScan);
      requests.add(Permission.bluetoothConnect);
    } else {
      // Android 11 and below - Location required for BLE
      print('[İZİN] Eski Android izinleri isteniyor: bluetooth, locationWhenInUse');
      requests.add(Permission.bluetooth);
      requests.add(Permission.locationWhenInUse);
    }

    // Android 13+ notifications
    requests.add(Permission.notification);

    print('[İZİN] İzinler isteniyor: ${requests.map((p) => p.toString()).join(", ")}');
    
    // Request all permissions
    final statuses = await requests.request();
    
    print('[İZİN] İzin durumları:');
    statuses.forEach((permission, status) {
      print('[İZİN]   - $permission: $status');
    });

    // Check if critical permissions are granted
    if (isAndroid12Plus) {
      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;

      print('[İZİN] bluetoothScan granted: $scanGranted');
      print('[İZİN] bluetoothConnect granted: $connectGranted');

      if (!scanGranted || !connectGranted) {
        final permanentlyDenied =
            (statuses[Permission.bluetoothScan]?.isPermanentlyDenied ?? false) ||
            (statuses[Permission.bluetoothConnect]?.isPermanentlyDenied ?? false);

        if (permanentlyDenied) {
          print('[İZİN] HATA: İzinler kalıcı olarak reddedildi!');
          throw StateError('Bluetooth izinleri kalıcı olarak reddedildi. Lütfen Ayarlar\'dan izin verin.');
        }
        print('[İZİN] HATA: İzinler verilmedi!');
        throw StateError('Bluetooth izinleri verilmedi.');
      }
    } else {
      final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      print('[İZİN] locationWhenInUse granted: $locationGranted');

      if (!locationGranted) {
        if (statuses[Permission.locationWhenInUse]?.isPermanentlyDenied ?? false) {
          print('[İZİN] HATA: Konum izni kalıcı olarak reddedildi!');
          throw StateError('Konum izni kalıcı olarak reddedildi. Lütfen Ayarlar\'dan izin verin.');
        }
        print('[İZİN] HATA: Konum izni verilmedi!');
        throw StateError('BLE taraması için konum izni gerekli.');
      }
    }
    
    print('[İZİN] ========== İZİNLER TAMAM ✓ ==========');
  }

  static Future<bool> _isAndroid12OrHigher() async {
    // Check if Android 12+ specific permissions are available
    try {
      final status = await Permission.bluetoothScan.status;
      print('[İZİN] bluetoothScan.status: $status (restricted: ${status.isRestricted})');
      // If the permission is not restricted, we're on Android 12+
      return !status.isRestricted;
    } catch (e) {
      print('[İZİN] Android sürüm tespiti hatası: $e');
      return false;
    }
  }

  /// Check if all required permissions are granted
  static Future<bool> hasPermissions() async {
    if (!Platform.isAndroid) return true;

    final isAndroid12Plus = await _isAndroid12OrHigher();

    if (isAndroid12Plus) {
      final scan = await Permission.bluetoothScan.isGranted;
      final connect = await Permission.bluetoothConnect.isGranted;
      print('[İZİN] hasPermissions - scan: $scan, connect: $connect');
      return scan && connect;
    } else {
      final location = await Permission.locationWhenInUse.isGranted;
      print('[İZİN] hasPermissions - location: $location');
      return location;
    }
  }

  /// Check if Bluetooth is actually enabled
  static Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    print('[İZİN] Bluetooth durumu: $state');
    return state == BluetoothAdapterState.on;
  }
}
