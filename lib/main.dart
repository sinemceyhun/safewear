import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.init();

  final appState = AppState(notificationService: notificationService);
  appState.start();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const SafeWearApp(),
    ),
  );
}
