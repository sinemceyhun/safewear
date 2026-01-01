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
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final now = DateTime.now();

      // Mostly stable accel around 1g, sometimes spike to simulate "fall"
      final spike = _rng.nextDouble() < 0.02;
      final ax = 0.02 * (_rng.nextDouble() - 0.5);
      final ay = 0.02 * (_rng.nextDouble() - 0.5);
      final az = spike ? 3.2 : 1.0 + 0.02 * (_rng.nextDouble() - 0.5);

      final hr = 70 + _rng.nextInt(10) - 5;
      final spo2 = 97 + _rng.nextInt(3) - 1;

      _ctrl.add(
        SensorSample(
          ts: now,
          ax: ax,
          ay: ay,
          az: az,
          gx: 0,
          gy: 0,
          gz: 0,
          hr: hr,
          spo2: spo2,
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
