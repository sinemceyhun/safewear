import '../models/alarm_event.dart';
import '../models/sensor_sample.dart';

class SafetyThresholds {
  // Optional BPM alerts
  double bpmLow;
  double bpmHigh;

  // Inactivity settings (only if gyro exists)
  int inactivitySeconds;
  double gyroDeltaEps;
  double gyroAbsEps;

  SafetyThresholds({
    required this.bpmLow,
    required this.bpmHigh,
    required this.inactivitySeconds,
    required this.gyroDeltaEps,
    required this.gyroAbsEps,
  });

  static SafetyThresholds defaults() => SafetyThresholds(
    bpmLow: 45,
    bpmHigh: 140,
    inactivitySeconds: 30,
    gyroDeltaEps: 0.15,
    gyroAbsEps: 0.25,
  );
}

class SafetyRules {
  DateTime? _lastMotionTs;

  double? _lastGx, _lastGy, _lastGz;

  AlarmEvent? evaluate(SensorSample s, SafetyThresholds t) {
    // 1) Alarm (authoritative from wearable)
    if (s.alarm == 1) {
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.manual,
        message: 'Manuel acil (buton)',
      );
    }
    if (s.alarm == 2) {
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.fall,
        message: 'Düşme alarmı (wearable)',
      );
    }

    // 2) Inactivity (only if gyro exists)
    if (s.hasGyro) {
      final gx = s.gx!, gy = s.gy!, gz = s.gz!;
      final gmag = s.gyroMag ?? 0.0;

      double delta = 0.0;
      if (_lastGx != null && _lastGy != null && _lastGz != null) {
        final dx = gx - _lastGx!;
        final dy = gy - _lastGy!;
        final dz = gz - _lastGz!;
        delta = (dx * dx + dy * dy + dz * dz).sqrt();
      }

      final moved = (delta >= t.gyroDeltaEps) || (gmag >= t.gyroAbsEps);

      if (moved) {
        _lastMotionTs = s.ts;
      } else {
        _lastMotionTs ??= s.ts;
      }

      _lastGx = gx;
      _lastGy = gy;
      _lastGz = gz;

      final idleFor = s.ts.difference(_lastMotionTs!).inSeconds;
      if (idleFor >= t.inactivitySeconds) {
        // reset baseline to avoid constant firing
        _lastMotionTs = s.ts;
        return AlarmEvent(
          ts: s.ts,
          type: AlarmType.inactivity,
          message: "Hareketsizlik (gyro): ${idleFor}s",
        );
      }
    }

    // 3) Abnormal HR (optional; based on bpm)
    if (s.bpm <= t.bpmLow || s.bpm >= t.bpmHigh) {
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.abnormalHeartRate,
        message: "Anormal nabız: ${s.bpm.toStringAsFixed(1)} BPM",
      );
    }

    return null;
  }
}

extension _SqrtNum on num {
  double sqrt() {
    final x = toDouble();
    double guess = x > 1 ? x / 2 : 1;
    for (int i = 0; i < 10; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }
}
