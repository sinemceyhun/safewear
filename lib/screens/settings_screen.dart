import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'emergency_contacts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController nameFilter;
  late final TextEditingController svcUuid;
  late final TextEditingController chrUuid;

  // Thresholds (integer-only)
  late final TextEditingController bpmLow;
  late final TextEditingController bpmHigh;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();

    nameFilter = TextEditingController(text: s.bleNameFilter);
    svcUuid = TextEditingController(text: s.bleServiceUuid);
    chrUuid = TextEditingController(text: s.bleNotifyCharUuid);

    // ✅ Store as integers in the UI (even though thresholds are doubles in AppState)
    bpmLow = TextEditingController(text: s.thresholds.bpmLow.round().toString());
    bpmHigh = TextEditingController(text: s.thresholds.bpmHigh.round().toString());
  }

  @override
  void dispose() {
    nameFilter.dispose();
    svcUuid.dispose();
    chrUuid.dispose();
    bpmLow.dispose();
    bpmHigh.dispose();
    super.dispose();
  }

  // ✅ Digits only, no decimals, no minus
  final _digitsOnly = FilteringTextInputFormatter.digitsOnly;

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<DataSource>(
          segments: const [
            ButtonSegment(value: DataSource.mock, label: Text('Mock')),
            ButtonSegment(value: DataSource.ble, label: Text('BLE')),
          ],
          selected: {s.dataSource},
          onSelectionChanged: (set) => context.read<AppState>().setDataSource(set.first),
        ),

        const SizedBox(height: 20),
        const Text('Emergency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Emergency Contacts (Email Only)'),
            subtitle: Text('${s.emergencyContacts.length} contact(s)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        const Text('BLE Config', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: nameFilter,
          decoration: const InputDecoration(labelText: 'Device name filter'),
        ),
        TextField(
          controller: svcUuid,
          decoration: const InputDecoration(labelText: 'Service UUID'),
        ),
        TextField(
          controller: chrUuid,
          decoration: const InputDecoration(labelText: 'Notify Characteristic UUID'),
        ),

        const SizedBox(height: 20),
        const Text('Thresholds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        TextField(
          controller: bpmLow,
          keyboardType: TextInputType.number,
          inputFormatters: [_digitsOnly],
          decoration: const InputDecoration(
            labelText: 'BPM lower threshold',
          ),
        ),

        TextField(
          controller: bpmHigh,
          keyboardType: TextInputType.number,
          inputFormatters: [_digitsOnly],
          decoration: const InputDecoration(
            labelText: 'BPM upper threshold',
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final st = context.read<AppState>();

            st.bleNameFilter = nameFilter.text.trim();
            st.bleServiceUuid = svcUuid.text.trim();
            st.bleNotifyCharUuid = chrUuid.text.trim();

            final low = _parseInt(bpmLow.text);
            final high = _parseInt(bpmHigh.text);

            // ✅ No restrictions: allow low > high, weird values, etc.
            if (low != null) st.thresholds.bpmLow = low.toDouble();
            if (high != null) st.thresholds.bpmHigh = high.toDouble();

            st.notifyListeners();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saved')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
