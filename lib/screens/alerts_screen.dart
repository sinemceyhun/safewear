import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: s.alerts.length,
      itemBuilder: (_, i) {
        final a = s.alerts[i];
        return Card(
          child: ListTile(
            title: Text(a.type),
            subtitle: Text('${a.message}\n${a.ts.toIso8601String()}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}