import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Call this before BLE scan/connect and before showing notifications.
  static Future<void> ensurePermissions() async {
    if (!Platform.isAndroid) return;

    // Android 12+ BLE permissions (API 31+)
    final btScan = Permission.bluetoothScan;
    final btConnect = Permission.bluetoothConnect;

    // Android 13+ notifications
    final notifications = Permission.notification;

    // Only request location if needed (Android <= 11).
    // On Android 12+ with usesPermissionFlags="neverForLocation",
    // location should not be required for BLE scan results.
    final location = Permission.locationWhenInUse;

    // Build request set depending on platform state.
    final requests = <Permission>[
      btScan,
      btConnect,
      notifications,
      // SMS permission removed - we only open SMS app, don't send directly
    ];

    // If the OS doesn't support bluetoothScan/bluetoothConnect (older Android),
    // permission_handler will typically mark them as "restricted/denied".
    // In that case, fall back to requesting location.
    //
    // We detect this by checking current status.
    final scanStatus = await btScan.status;
    final connectStatus = await btConnect.status;

    final isLegacyAndroidPermModel =
        (scanStatus.isRestricted || scanStatus.isDenied) &&
            (connectStatus.isRestricted || connectStatus.isDenied);

    if (isLegacyAndroidPermModel) {
      requests.add(location);
    }

    final statuses = await requests.request();

    // Hard requirements
    final scanGranted = statuses[btScan]?.isGranted ?? false;
    final connectGranted = statuses[btConnect]?.isGranted ?? false;

    // On older Android, btScan/btConnect may not become granted; location is the gate.
    final locationGranted = statuses[location]?.isGranted ?? false;

    if ((!scanGranted || !connectGranted) && !(isLegacyAndroidPermModel && locationGranted)) {
      // If user permanently denied something, direct them to Settings
      final permanentlyDenied = (statuses[btScan]?.isPermanentlyDenied ?? false) ||
          (statuses[btConnect]?.isPermanentlyDenied ?? false) ||
          (statuses[location]?.isPermanentlyDenied ?? false);

      if (permanentlyDenied) {
        // You can call openAppSettings() from UI flow when you catch this.
        throw StateError('Permissions permanently denied. Please enable in Settings.');
      }

      throw StateError('Required permissions not granted.');
    }
  }
}
