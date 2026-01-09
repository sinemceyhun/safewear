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
    final phone = (c.phone == null || c.phone!.trim().isEmpty) ? '—' : c.phone!.trim();
    final email = (c.email == null || c.email!.trim().isEmpty) ? '—' : c.email!.trim();
    final actions = <String>[
      if (c.canCall) 'Call',
      if (c.canSms) 'SMS',
      if (c.canEmail) 'Email',
    ].join(', ');

    return 'Phone: $phone\nEmail: $email\nActions: ${actions.isEmpty ? '—' : actions}';
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
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  bool _canCall = true;
  bool _canSms = true;
  bool _canEmail = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');

    _canCall = e?.canCall ?? true;
    _canSms = e?.canSms ?? true;
    _canEmail = e?.canEmail ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    final contact = EmergencyContact(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      canCall: _canCall,
      canSms: _canSms,
      canEmail: _canEmail,
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
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Allow Call'),
              value: _canCall,
              onChanged: (v) => setState(() => _canCall = v),
            ),
            SwitchListTile(
              title: const Text('Allow SMS'),
              value: _canSms,
              onChanged: (v) => setState(() => _canSms = v),
            ),
            SwitchListTile(
              title: const Text('Allow Email'),
              value: _canEmail,
              onChanged: (v) => setState(() => _canEmail = v),
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
