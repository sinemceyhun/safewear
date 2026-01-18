import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/emergency_contact.dart';
import '../state/app_state.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<EmergencyContact>(
            context: context,
            builder: (_) => const _EmergencyContactEditDialog(),
          );

          if (created != null && context.mounted) {
            await context.read<AppState>().addOrUpdateEmergencyContact(created);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.emergencyContacts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No emergency contacts yet. Tap + to add one.'),
              ),
            ),
          for (final c in s.emergencyContacts)
            Card(
              child: ListTile(
                title: Text(c.name),
                subtitle: Text(_subtitle(c)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final updated = await showDialog<EmergencyContact>(
                        context: context,
                        builder: (_) => _EmergencyContactEditDialog(existing: c),
                      );

                      if (updated != null && context.mounted) {
                        await context.read<AppState>().addOrUpdateEmergencyContact(updated);
                      }
                    } else if (v == 'delete') {
                      if (!context.mounted) return;
                      await context.read<AppState>().removeEmergencyContact(c.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _subtitle(EmergencyContact c) {
    final email = (c.email == null || c.email!.trim().isEmpty) ? '—' : c.email!.trim();
    return 'Email: $email';
  }
}

class _EmergencyContactEditDialog extends StatefulWidget {
  final EmergencyContact? existing;
  const _EmergencyContactEditDialog({this.existing});

  @override
  State<_EmergencyContactEditDialog> createState() => _EmergencyContactEditDialogState();
}

class _EmergencyContactEditDialogState extends State<_EmergencyContactEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) return;
    if (email.isEmpty) return; // email is required now

    final contact = EmergencyContact(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      phone: null,            // ✅ no phone usage
      email: email,
      canCall: false,         // ✅ disabled
      canSms: false,          // ✅ disabled
      canEmail: true,         // ✅ always enabled
    );

    Navigator.of(context).pop(contact);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Contact' : 'Add Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This app uses real SMTP email sending.\nEmail is required.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
