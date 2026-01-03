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

  Future<void> showAlert({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'safewear_alerts',
      'SafeWear Alerts',
      channelDescription: 'Emergency and risk notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    // Avoid ID collisions
    final id = DateTime.now().millisecondsSinceEpoch;

    await _plugin.show(id, title, body, const NotificationDetails(android: androidDetails));
  }
}
