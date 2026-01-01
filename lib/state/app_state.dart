import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/sensor_sample.dart';
import '../services/ble_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
enum DataSource { mock, ble }

class AlertEvent {
  final DateTime ts;
  final String type;
  final String message;

  AlertEvent(this.type, this.message) : ts = DateTime.now();
}

class Thresholds {
  int hrLow = 50;
  int hrHigh = 120;
  int spo2Low = 90;
  double fallAccelMag = 2.7; // approx "g" magnitude threshold
  int immobileSeconds = 25;

  Thresholds();
}

class AppState extends ChangeNotifier {
  final NotificationService notificationService;
  final BleService _ble = BleService();

  AppState({required this.notificationService});

  // Mode
  DataSource dataSource = DataSource.mock;

  // BLE config (set these to match ESP32 later)
  String bleNameFilter = 'SafeWear';
  String bleServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  String bleNotifyCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

  // Runtime state
  bool scanning = false;
  List<ScanResult> scanResults = [];

  BluetoothConnectionState connectionState = BluetoothConnectionState.disconnected;

  SensorSample? latest;
  final thresholds = Thresholds();

  final List<AlertEvent> alerts = [];

  Timer? _mockTimer;
  Timer? _immobileTimer;

  double? _lastAccelMag;
  DateTime? _lastMovementTs;

  void start() {
    _startMockIfNeeded();
  }

  // -------------------------
  // Mode switching
  // -------------------------
  Future<void> setDataSource(DataSource s) async {
    if (dataSource == s) return;
    dataSource = s;

    await disconnectBle();
    _stopMock();

    if (dataSource == DataSource.mock) {
      _startMockIfNeeded();
    }

    notifyListeners();
  }

  // -------------------------
  // Mock data
  // -------------------------
  void _startMockIfNeeded() {
    if (dataSource != DataSource.mock) return;

    _mockTimer?.cancel();
    final rnd = Random();

    _mockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final hr = 65 + rnd.nextInt(50);
      final spo2 = 92 + rnd.nextInt(7);

      // simulate accel mag around 1.0 with occasional spikes (fall)
      final spike = rnd.nextDouble() < 0.04;
      final az = spike ? (2.8 + rnd.nextDouble()) : (0.9 + rnd.nextDouble() * 0.3);

      final sample = SensorSample(
        ts: DateTime.now(),
        hr: hr,
        spo2: spo2,
        ax: (rnd.nextDouble() - 0.5) * 0.1,
        ay: (rnd.nextDouble() - 0.5) * 0.1,
        az: az,
        gx: (rnd.nextDouble() - 0.5) * 2,
        gy: (rnd.nextDouble() - 0.5) * 2,
        gz: (rnd.nextDouble() - 0.5) * 2,
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
  // -------------------------
// BLE
// -------------------------
  Future<void> startBleScan() async {
    // Ensure we are in BLE mode
    if (dataSource != DataSource.ble) {
      await setDataSource(DataSource.ble);
    }

    // Avoid double-start
    if (scanning) return;

    // Runtime permissions (Android)
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
        onError: (e) {
          scanning = false;
          notifyListeners();
        },
      );

      // Match BleService.startScan timeout (6s) so UI stays "Scanning…" while scan is active
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
    notifyListeners();
  }

  // -------------------------
  // Alerts / detection
  // -------------------------
  void _onNewSample(SensorSample s) {
    latest = s;

    final mag = s.accelMag;
    if (mag != null) {
      if (_lastAccelMag == null || (mag - _lastAccelMag!).abs() > 0.03) {
        _lastMovementTs = DateTime.now();
      }
      _lastAccelMag = mag;

      if (mag >= thresholds.fallAccelMag) {
        _emitAlert('FALL', 'High acceleration magnitude detected: ${mag.toStringAsFixed(2)}');
      }
    }

    if (s.hr != null) {
      if (s.hr! < thresholds.hrLow) {
        _emitAlert('HR_LOW', 'Heart rate low: ${s.hr}');
      } else if (s.hr! > thresholds.hrHigh) {
        _emitAlert('HR_HIGH', 'Heart rate high: ${s.hr}');
      }
    }

    if (s.spo2 != null && s.spo2! < thresholds.spo2Low) {
      _emitAlert('SPO2_LOW', 'SpO₂ low: ${s.spo2}%');
    }

    _immobileTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_lastMovementTs == null) return;
      final idle = DateTime.now().difference(_lastMovementTs!).inSeconds;
      if (idle >= thresholds.immobileSeconds) {
        _emitAlert('IMMOBILE', 'No movement for ${idle}s');
        _lastMovementTs = DateTime.now(); // avoid spamming
      }
    });

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
