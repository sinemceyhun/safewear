import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';

class SafeWearApp extends StatelessWidget {
  const SafeWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeWear',
      theme: ThemeData(useMaterial3: true),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('SafeWear'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Dashboard'),
                Tab(text: 'Connect'),
                Tab(text: 'Alerts'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              DashboardScreen(),
              ConnectionScreen(),
              AlertsScreen(),
              SettingsScreen(),
            ],
          ),
        ),
      ),
    );
  }
}