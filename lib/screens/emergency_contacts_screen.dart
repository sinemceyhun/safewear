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
    
    final actions = <String>[];
    if (c.canCall) actions.add('Call');
    if (c.canSms) {
      if (c.phone != null && c.phone!.trim().isNotEmpty) {
        actions.add('SMS (Otomatik)');
      } else {
        actions.add('SMS (Telefon yok!)');
      }
    }
    if (c.canEmail) actions.add('Email');

    return 'Phone: $phone\nEmail: $email\nActions: ${actions.isEmpty ? '—' : actions.join(', ')}';
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

    // Telefon numarası değiştiğinde, eğer boşsa SMS'i otomatik kapat
    _phoneCtrl.addListener(_onPhoneChanged);
    
    // İlk yüklemede telefon numarası kontrolü yap
    _validateSmsWithPhone();
  }

  void _onPhoneChanged() {
    _validateSmsWithPhone();
  }

  void _validateSmsWithPhone() {
    final phone = _phoneCtrl.text.trim();
    // Eğer telefon numarası yoksa ve SMS açıksa, SMS'i kapat
    if (phone.isEmpty && _canSms) {
      setState(() {
        _canSms = false;
      });
    }
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
    if (name.isEmpty) {
      _showError('İsim zorunludur');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    // SMS için telefon numarası kontrolü
    if (_canSms && phone.isEmpty) {
      _showError('SMS göndermek için telefon numarası gereklidir');
      return;
    }

    // Call için telefon numarası kontrolü
    if (_canCall && phone.isEmpty) {
      _showError('Arama yapmak için telefon numarası gereklidir');
      return;
    }

    // Email için email kontrolü
    if (_canEmail && email.isEmpty) {
      _showError('Email göndermek için email adresi gereklidir');
      return;
    }

    // SMS/Call açıkken telefon numarası yoksa otomatik kapat
    final finalCanSms = _canSms && phone.isNotEmpty;
    final finalCanCall = _canCall && phone.isNotEmpty;
    final finalCanEmail = _canEmail && email.isNotEmpty;

    final contact = EmergencyContact(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      canCall: finalCanCall,
      canSms: finalCanSms,
      canEmail: finalCanEmail,
    );

    Navigator.of(context).pop(contact);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
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
              decoration: InputDecoration(
                labelText: 'Phone ${_canCall || _canSms ? "(required)" : "(optional)"}',
                helperText: (_canCall || _canSms) 
                    ? 'Call ve SMS için telefon numarası gereklidir'
                    : null,
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email ${_canEmail ? "(required)" : "(optional)"}',
                helperText: _canEmail 
                    ? 'Email göndermek için email adresi gereklidir'
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Allow Call'),
              subtitle: _canCall && _phoneCtrl.text.trim().isEmpty
                  ? const Text('Telefon numarası gereklidir', style: TextStyle(color: Colors.orange))
                  : null,
              value: _canCall,
              onChanged: (v) {
                if (v && _phoneCtrl.text.trim().isEmpty) {
                  _showError('Arama için önce telefon numarası giriniz');
                  return;
                }
                setState(() => _canCall = v);
              },
            ),
            SwitchListTile(
              title: const Text('Allow SMS'),
              subtitle: _canSms && _phoneCtrl.text.trim().isEmpty
                  ? const Text('Telefon numarası gereklidir', style: TextStyle(color: Colors.orange))
                  : _canSms
                      ? const Text('Acil durumda otomatik SMS gönderilecek', style: TextStyle(color: Colors.green, fontSize: 12))
                      : null,
              value: _canSms,
              onChanged: (v) {
                if (v) {
                  final phone = _phoneCtrl.text.trim();
                  if (phone.isEmpty) {
                    _showError('SMS için önce telefon numarası giriniz');
                    return;
                  }
                }
                setState(() => _canSms = v);
              },
            ),
            SwitchListTile(
              title: const Text('Allow Email'),
              subtitle: _canEmail && _emailCtrl.text.trim().isEmpty
                  ? const Text('Email adresi gereklidir', style: TextStyle(color: Colors.orange))
                  : null,
              value: _canEmail,
              onChanged: (v) {
                if (v && _emailCtrl.text.trim().isEmpty) {
                  _showError('Email için önce email adresi giriniz');
                  return;
                }
                setState(() => _canEmail = v);
              },
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
