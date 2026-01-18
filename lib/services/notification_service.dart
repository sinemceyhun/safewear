import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  Future<void> requestPermissionIfNeeded() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ✅ Always returns a valid 32-bit signed notification ID
  int _safeId() {
    // max signed 32-bit int = 2147483647
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;

    // avoid 0 (just to be safe)
    return id == 0 ? 1 : id;
  }

  Future<void> showAlert({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'safewear_alerts',
      'SafeWear Alerts',
      channelDescription: 'Emergency and risk notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    // ✅ FIX: must fit in 32-bit int
    final id = _safeId();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
