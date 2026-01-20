import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/emergency_contact.dart';

class EmergencyActionsSheet extends StatelessWidget {
  final String reason;
  const EmergencyActionsSheet({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Emergency Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Reason: $reason'),
            ),
            const SizedBox(height: 12),

            if (s.emergencyContacts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No emergency contacts configured. Add them in Settings.'),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: s.emergencyContacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = s.emergencyContacts[i];
                    return _contactCard(context, c, s, reason);
                  },
                ),
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, EmergencyContact c, AppState s, String reason) {
    final msg = s.buildEmergencyMessage(reason: reason);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // ✅ ONLY EMAIL ACTION (real SMTP via AppState -> EmergencyActionService -> EmailService)
                if ((c.email?.trim().isNotEmpty ?? false))
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await s.emergencyEmail(
                          c,
                          subject: '🚨 SafeWear ACİL DURUM:',
                          body: msg,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email sent')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Email failed: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.email),
                    label: const Text('Email'),
                  )
                else
                  const Text(
                    'No email for this contact.',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
