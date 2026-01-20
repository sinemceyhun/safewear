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

  // ✅ Alarm oranları (istersen değiştir)
  final double manualChance; // alarm=2
  final double fallChance;   // alarm=1

  MockSensorStream({
    this.manualChance = 0.01,
    this.fallChance = 0.01,
  });

  @override
  Stream<SensorSample> stream() => _ctrl.stream;

  void start() {
    // ✅ start() tekrar çağrılırsa çakışmasın
    _t?.cancel();

    _t = Timer.periodic(const Duration(milliseconds: 700), (_) {
      final now = DateTime.now();

      // BPM around 70-100 with fractional part
      final bpm = 70 + _rng.nextInt(31) + _rng.nextDouble();

      // ✅ Rare alarms (fall=1, manual=2)
      final r = _rng.nextDouble();
      int alarm = 0;

      if (r < manualChance) {
        alarm = 2; // ✅ manual button
      } else if (r < manualChance + fallChance) {
        alarm = 1; // ✅ fall
      }

      // Sometimes provide gyro, sometimes not
      final includeGyro = _rng.nextDouble() < 0.6;
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
    _t = null;
    await _ctrl.close();
  }
}
