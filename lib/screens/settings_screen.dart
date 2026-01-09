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

  // Thresholds (SpO2 removed)
  late final TextEditingController bpmLow;
  late final TextEditingController bpmHigh;

  // Gyro thresholds (manual show/hide)
  late final TextEditingController immobileSec;
  late final TextEditingController gyroDeltaEps;
  late final TextEditingController gyroAbsEps;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();

    nameFilter = TextEditingController(text: s.bleNameFilter);
    svcUuid = TextEditingController(text: s.bleServiceUuid);
    chrUuid = TextEditingController(text: s.bleNotifyCharUuid);

    bpmLow = TextEditingController(text: s.thresholds.bpmLow.toStringAsFixed(0));
    bpmHigh = TextEditingController(text: s.thresholds.bpmHigh.toStringAsFixed(0));

    immobileSec = TextEditingController(text: s.thresholds.immobileSeconds.toString());
    gyroDeltaEps = TextEditingController(text: s.thresholds.gyroDeltaEps.toString());
    gyroAbsEps = TextEditingController(text: s.thresholds.gyroAbsEps.toString());
  }

  @override
  void dispose() {
    nameFilter.dispose();
    svcUuid.dispose();
    chrUuid.dispose();

    bpmLow.dispose();
    bpmHigh.dispose();

    immobileSec.dispose();
    gyroDeltaEps.dispose();
    gyroAbsEps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final showGyro = s.showGyroSettings; // MANUAL FLAG (no auto change)

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

        TextField(
          controller: bpmLow,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'BPM low (optional alert)'),
        ),
        TextField(
          controller: bpmHigh,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'BPM high (optional alert)'),
        ),

        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show gyro settings'),
          value: showGyro,
          onChanged: (v) => context.read<AppState>().setShowGyroSettings(v),
        ),

        if (showGyro) ...[
          const SizedBox(height: 8),
          const Text('Gyro-based Inactivity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          TextField(
            controller: immobileSec,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Immobile seconds'),
          ),
          TextField(
            controller: gyroDeltaEps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Gyro delta epsilon'),
          ),
          TextField(
            controller: gyroAbsEps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Gyro abs epsilon'),
          ),
        ],

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final st = context.read<AppState>();

            st.bleNameFilter = nameFilter.text.trim();
            st.bleServiceUuid = svcUuid.text.trim();
            st.bleNotifyCharUuid = chrUuid.text.trim();

            st.thresholds.bpmLow = double.tryParse(bpmLow.text.trim()) ?? st.thresholds.bpmLow;
            st.thresholds.bpmHigh = double.tryParse(bpmHigh.text.trim()) ?? st.thresholds.bpmHigh;

            if (st.showGyroSettings) {
              st.thresholds.immobileSeconds =
                  int.tryParse(immobileSec.text.trim()) ?? st.thresholds.immobileSeconds;
              st.thresholds.gyroDeltaEps =
                  double.tryParse(gyroDeltaEps.text.trim()) ?? st.thresholds.gyroDeltaEps;
              st.thresholds.gyroAbsEps =
                  double.tryParse(gyroAbsEps.text.trim()) ?? st.thresholds.gyroAbsEps;
            }

            st.notifyListeners();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
