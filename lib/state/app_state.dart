import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/sensor_sample.dart';
import '../models/emergency_contact.dart';
import '../services/ble_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/emergency_contacts_repo.dart';
import '../services/emergency_action_service.dart';

enum DataSource { mock, ble }

class AlertEvent {
  final DateTime ts;
  final String type;
  final String message;

  AlertEvent(this.type, this.message) : ts = DateTime.now();
}

/// Thresholds (SpO₂ removed)
class Thresholds {
  // Optional HR alerts from bpm (still useful even if wearable doesn't send spo2)
  double bpmLow = 45;
  double bpmHigh = 140;

  // Inactivity detection (enabled only when gyro arrives)
  int immobileSeconds = 25;

  // Motion detection based on gyro deltas
  // If gyro changes above this, consider as movement.
  double gyroDeltaEps = 0.15;

  // If absolute gyro magnitude is above this, consider as movement.
  // Helps when sample-to-sample delta is small but device is rotating steadily.
  double gyroAbsEps = 0.25;

  Thresholds();
}

class AppState extends ChangeNotifier {
  final NotificationService notificationService;

  final BleService _ble = BleService();
  final EmergencyContactsRepo _contactsRepo = EmergencyContactsRepo();
  final EmergencyActionService _actionSvc = EmergencyActionService();

  AppState({required this.notificationService});

  // Mode
  DataSource dataSource = DataSource.mock;

  // BLE config (set these to your actual UUIDs from your screenshots)
  String bleNameFilter = '';
  String bleServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  String bleNotifyCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  // Runtime state
  bool scanning = false;
  List<ScanResult> scanResults = [];
  BluetoothConnectionState connectionState = BluetoothConnectionState.disconnected;

  SensorSample? latest;
  final thresholds = Thresholds();
  final List<AlertEvent> alerts = [];

  // Motion / inactivity state (gyro-based)
  bool _motionAvailable = false;
  DateTime? _lastMovementTs;
  double? _lastGx, _lastGy, _lastGz;
  Timer? _immobileTimer;

  // Wearable alarm transition tracking
  int _lastAlarmCode = 0;
  DateTime? _lastEmergencyTs;

  // Alert spam control
  final Map<String, DateTime> _lastAlertTs = {};

  // Emergency contacts
  List<EmergencyContact> emergencyContacts = [];

  // --- BPM chart history ---
  static const int bpmHistoryMax = 120; // ~2 minutes if you get ~1Hz samples
  final List<double> bpmHistory = [];
  final List<DateTime> bpmHistoryTs = [];


  void start() {
    unawaited(_loadEmergencyContacts());
    _startMockIfNeeded();
  }
  // gyro settings
  bool get gyroAvailable => latest?.hasGyro == true;

  // Settings UI control (manual)
  bool showGyroSettings = false;

  void setShowGyroSettings(bool v) {
    if (showGyroSettings == v) return;
    showGyroSettings = v;
    notifyListeners();
  }


  Future<void> _loadEmergencyContacts() async {
    emergencyContacts = await _contactsRepo.load();
    notifyListeners();
  }

  // -------------------------
  // Emergency contacts CRUD
  // -------------------------
  Future<void> addOrUpdateEmergencyContact(EmergencyContact c) async {
    final idx = emergencyContacts.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      emergencyContacts[idx] = c;
    } else {
      emergencyContacts.add(c);
    }
    await _contactsRepo.save(emergencyContacts);
    notifyListeners();
  }

  Future<void> removeEmergencyContact(String id) async {
    emergencyContacts.removeWhere((c) => c.id == id);
    await _contactsRepo.save(emergencyContacts);
    notifyListeners();
  }

  // -------------------------
  // Mode switching
  // -------------------------
  Future<void> setDataSource(DataSource s) async {
    if (dataSource == s) return;
    dataSource = s;

    await disconnectBle();
    _stopMock();

    _resetMotionState();

    if (dataSource == DataSource.mock) {
      _startMockIfNeeded();
    }

    notifyListeners();
  }

  void _resetMotionState() {
    _motionAvailable = false;
    _lastMovementTs = null;
    _lastGx = _lastGy = _lastGz = null;
    _immobileTimer?.cancel();
    _immobileTimer = null;
  }

  // -------------------------
  // Mock data (for UI/rules testing)
  // -------------------------
  Timer? _mockTimer;

  void _startMockIfNeeded() {
    if (dataSource != DataSource.mock) return;

    _mockTimer?.cancel();
    final rnd = Random();

    _mockTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      final bpm = 65 + rnd.nextInt(40) + rnd.nextDouble(); // 65-105.x
      final alarm = (rnd.nextDouble() < 0.02) ? 2 : 0;     // rare fall alarm

      // Sometimes include gyro to exercise inactivity
      final includeGyro = rnd.nextDouble() < 0.6;
      final gx = includeGyro ? (rnd.nextDouble() - 0.5) * 0.6 : null;
      final gy = includeGyro ? (rnd.nextDouble() - 0.5) * 0.6 : null;
      final gz = includeGyro ? (rnd.nextDouble() - 0.5) * 0.6 : null;

      final sample = SensorSample(
        ts: DateTime.now(),
        bpm: bpm,
        alarm: alarm,
        gx: gx,
        gy: gy,
        gz: gz,
        raw: const {'source': 'mock'},
      );

      _onNewSample(sample);
    });
  }

  void _stopMock() {
    _mockTimer?.cancel();
    _mockTimer = null;
  }

  // -------------------------
  // BLE
  // -------------------------
  Future<void> startBleScan() async {
    if (dataSource != DataSource.ble) {
      await setDataSource(DataSource.ble);
    }
    if (scanning) return;

    await PermissionService.ensurePermissions();

    scanning = true;
    scanResults = [];
    notifyListeners();

    try {
      await _ble.startScan(
        nameFilter: bleNameFilter,
        onResults: (results) {
          scanResults = results;
          notifyListeners();
        },
        onError: (_) {
          scanning = false;
          notifyListeners();
        },
      );

      // Align UI scanning state with BleService timeout (6s)
      Future.delayed(const Duration(seconds: 6), () {
        if (!scanning) return;
        scanning = false;
        notifyListeners();
      });
    } catch (_) {
      scanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopBleScan() async {
    if (!scanning) return;
    await _ble.stopScan();
    scanning = false;
    notifyListeners();
  }

  Future<void> connectBle(ScanResult target) async {
    if (scanning) await stopBleScan();

    _resetMotionState();

    final cfg = BleConfig(
      deviceNameFilter: bleNameFilter,
      serviceUuid: Guid(bleServiceUuid),
      notifyCharUuid: Guid(bleNotifyCharUuid),
    );

    await _ble.connectAndSubscribe(
      target: target,
      config: cfg,
      onConnectionState: (s) {
        connectionState = s;
        notifyListeners();
      },
      onLine: (line) {
        final sample = SensorSample.tryParseLine(line);
        if (sample != null) _onNewSample(sample);
      },
    );
  }

  Future<void> disconnectBle() async {
    await _ble.disconnect();
    connectionState = BluetoothConnectionState.disconnected;
    _resetMotionState();
    notifyListeners();
  }

  // -------------------------
  // Emergency actions
  // -------------------------
  String buildEmergencyMessage({required String reason}) {
    final bpm = latest?.bpm;
    final alarm = latest?.alarm;

    final gmag = latest?.gyroMag;

    return [
      'SafeWear Emergency',
      'Reason: $reason',
      'Time: ${DateTime.now().toIso8601String()}',
      'BPM: ${bpm != null ? bpm.toStringAsFixed(1) : '-'}',
      'Alarm: ${alarm ?? '-'}',
      'GyroMag: ${gmag != null ? gmag.toStringAsFixed(3) : '-'}',
    ].join('\n');
  }

  Future<void> triggerEmergency({required String reason}) async {
    final msg = buildEmergencyMessage(reason: reason);

    alerts.insert(0, AlertEvent('EMERGENCY', msg));
    notifyListeners();

    await notificationService.showAlert(
      title: 'SafeWear: EMERGENCY',
      body: reason,
    );
  }

  Future<void> emergencyCall(EmergencyContact c) => _actionSvc.call(c);
  Future<void> emergencySms(EmergencyContact c, String message) => _actionSvc.sms(c, message);
  Future<void> emergencyEmail(
      EmergencyContact c, {
        required String subject,
        required String body,
      }) =>
      _actionSvc.email(c, subject: subject, body: body);

  // -------------------------
  // Alerts / detection
  // -------------------------
  bool _allowEmit(String type, {int minSeconds = 10}) {
    final now = DateTime.now();
    final last = _lastAlertTs[type];
    if (last == null) {
      _lastAlertTs[type] = now;
      return true;
    }
    if (now.difference(last).inSeconds >= minSeconds) {
      _lastAlertTs[type] = now;
      return true;
    }
    return false;
  }

  void _handleWearableAlarmTransition(SensorSample s) {
    final alarm = s.alarm;

    // Trigger only on transition
    if (alarm == _lastAlarmCode) return;
    _lastAlarmCode = alarm;

    if (alarm == 0) return;

    final reason = (alarm == 1)
        ? 'Wearable: Manuel Acil (Buton)'
        : 'Wearable: Düşme Algılandı';

    // Cooldown 10s
    final now = DateTime.now();
    final canFire = _lastEmergencyTs == null || now.difference(_lastEmergencyTs!).inSeconds >= 10;
    if (!canFire) return;

    _lastEmergencyTs = now;
    unawaited(triggerEmergency(reason: reason));
  }

  void _updateMotionFromGyroIfPresent(SensorSample s) {
    if (!s.hasGyro) return;

    _motionAvailable = true;

    final gx = s.gx!, gy = s.gy!, gz = s.gz!;
    final gmag = s.gyroMag ?? 0.0;

    // Compute delta magnitude vs last sample (vector delta)
    double delta = 0.0;
    if (_lastGx != null && _lastGy != null && _lastGz != null) {
      final dx = gx - _lastGx!;
      final dy = gy - _lastGy!;
      final dz = gz - _lastGz!;
      delta = sqrt(dx * dx + dy * dy + dz * dz);
    }

    final moved = (delta >= thresholds.gyroDeltaEps) || (gmag >= thresholds.gyroAbsEps);

    if (moved) {
      _lastMovementTs = DateTime.now();
    } else {
      _lastMovementTs ??= DateTime.now(); // initialize once
    }

    _lastGx = gx;
    _lastGy = gy;
    _lastGz = gz;

    // Start inactivity timer only after gyro is available
    _immobileTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_motionAvailable || _lastMovementTs == null) return;

      final idle = DateTime.now().difference(_lastMovementTs!).inSeconds;
      if (idle >= thresholds.immobileSeconds) {
        if (_allowEmit('IMMOBILE', minSeconds: thresholds.immobileSeconds)) {
          unawaited(_emitAlert('IMMOBILE', 'No movement (gyro) for ${idle}s'));
        }
        // Reset baseline after firing to avoid repeats
        _lastMovementTs = DateTime.now();
      }
    });
  }

  void _onNewSample(SensorSample s) {
    latest = s;
    // Record BPM history for chart
    bpmHistory.add(s.bpm);
    bpmHistoryTs.add(s.ts);
    if (bpmHistory.length > bpmHistoryMax) {
      bpmHistory.removeAt(0);
      bpmHistoryTs.removeAt(0);
    }

    // 1) Wearable alarm (authoritative)
    _handleWearableAlarmTransition(s);

    // 2) Optional: HR alerts based on bpm (still useful)
    if (_allowEmit('BPM_CHECK', minSeconds: 1)) {
      if (s.bpm <= thresholds.bpmLow && _allowEmit('HR_LOW', minSeconds: 15)) {
        unawaited(_emitAlert('HR_LOW', 'Low BPM: ${s.bpm.toStringAsFixed(1)}'));
      } else if (s.bpm >= thresholds.bpmHigh && _allowEmit('HR_HIGH', minSeconds: 15)) {
        unawaited(_emitAlert('HR_HIGH', 'High BPM: ${s.bpm.toStringAsFixed(1)}'));
      }
    }

    // 3) Optional: Inactivity (only if gyro exists)
    _updateMotionFromGyroIfPresent(s);

    notifyListeners();
  }

  Future<void> _emitAlert(String type, String msg) async {
    alerts.insert(0, AlertEvent(type, msg));
    notifyListeners();

    await notificationService.showAlert(
      title: 'SafeWear: $type',
      body: msg,
    );
  }
}
