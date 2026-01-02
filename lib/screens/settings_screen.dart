import 'package:flutter/material.dart';
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

  late final TextEditingController hrLow;
  late final TextEditingController hrHigh;
  late final TextEditingController spo2Low;
  late final TextEditingController fallMag;
  late final TextEditingController immobileSec;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();

    nameFilter = TextEditingController(text: s.bleNameFilter);
    svcUuid = TextEditingController(text: s.bleServiceUuid);
    chrUuid = TextEditingController(text: s.bleNotifyCharUuid);

    hrLow = TextEditingController(text: s.thresholds.hrLow.toString());
    hrHigh = TextEditingController(text: s.thresholds.hrHigh.toString());
    spo2Low = TextEditingController(text: s.thresholds.spo2Low.toString());
    fallMag = TextEditingController(text: s.thresholds.fallAccelMag.toString());
    immobileSec = TextEditingController(text: s.thresholds.immobileSeconds.toString());
  }

  @override
  void dispose() {
    nameFilter.dispose();
    svcUuid.dispose();
    chrUuid.dispose();
    hrLow.dispose();
    hrHigh.dispose();
    spo2Low.dispose();
    fallMag.dispose();
    immobileSec.dispose();
    super.dispose();
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
            title: const Text('Emergency Contacts'),
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
        TextField(controller: nameFilter, decoration: const InputDecoration(labelText: 'Device name filter')),
        TextField(controller: svcUuid, decoration: const InputDecoration(labelText: 'Service UUID')),
        TextField(controller: chrUuid, decoration: const InputDecoration(labelText: 'Notify Characteristic UUID')),

        const SizedBox(height: 20),
        const Text('Thresholds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: hrLow, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'HR low')),
        TextField(controller: hrHigh, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'HR high')),
        TextField(controller: spo2Low, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SpO₂ low')),
        TextField(controller: fallMag, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fall accel magnitude')),
        TextField(controller: immobileSec, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Immobile seconds')),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final st = context.read<AppState>();

            st.bleNameFilter = nameFilter.text.trim();
            st.bleServiceUuid = svcUuid.text.trim();
            st.bleNotifyCharUuid = chrUuid.text.trim();

            st.thresholds.hrLow = int.tryParse(hrLow.text.trim()) ?? st.thresholds.hrLow;
            st.thresholds.hrHigh = int.tryParse(hrHigh.text.trim()) ?? st.thresholds.hrHigh;
            st.thresholds.spo2Low = int.tryParse(spo2Low.text.trim()) ?? st.thresholds.spo2Low;
            st.thresholds.fallAccelMag = double.tryParse(fallMag.text.trim()) ?? st.thresholds.fallAccelMag;
            st.thresholds.immobileSeconds = int.tryParse(immobileSec.text.trim()) ?? st.thresholds.immobileSeconds;

            st.notifyListeners();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
