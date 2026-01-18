import 'dart:async';
import 'dart:math' as math;

import '../models/sensor_sample.dart';

abstract class SensorStream {
  Stream<SensorSample> stream();
  Future<void> stop();
}

/// Emulator-friendly fake stream (UI + rules test)
class MockSensorStream implements SensorStream {
  final _ctrl = StreamController<SensorSample>.broadcast();
  Timer? _t;
  final _rng = math.Random();

  @override
  Stream<SensorSample> stream() => _ctrl.stream;

  void start() {
    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final now = DateTime.now();

      // BPM around 70-100 with fractional part
      final bpm = 70 + _rng.nextInt(31) + _rng.nextDouble();

      // Rare alarms
      final r = _rng.nextDouble();

      // ✅ FIXED:
      // 2 => manual
      // 1 => fall
      final alarm = (r < 0.01)
          ? 2 // manual
          : (r < 0.02)
          ? 1 // fall
          : 0;

      // Sometimes provide gyro, sometimes not
      final includeGyro = _rng.nextDouble() < 0.6;

      // If includeGyro=false -> inactivity should never trigger (correct behavior)
      // If includeGyro=true but small changes -> can simulate immobility.
      final moving = _rng.nextDouble() < 0.35;

      final gx = includeGyro ? (moving ? (_rng.nextDouble() - 0.5) * 0.8 : 0.01) : null;
      final gy = includeGyro ? (moving ? (_rng.nextDouble() - 0.5) * 0.8 : 0.01) : null;
      final gz = includeGyro ? (moving ? (_rng.nextDouble() - 0.5) * 0.8 : 0.01) : null;

      _ctrl.add(
        SensorSample(
          ts: now,
          bpm: bpm,
          alarm: alarm,
          gx: gx,
          gy: gy,
          gz: gz,
          raw: const {'source': 'mock'},
        ),
      );
    });
  }

  @override
  Future<void> stop() async {
    _t?.cancel();
    await _ctrl.close();
  }
}
