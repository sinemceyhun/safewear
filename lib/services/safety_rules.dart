import '../models/alarm_event.dart';
import '../models/sensor_sample.dart';

class Thresholds {
  double fallAccelMag;   // magnitude threshold
  int inactivitySeconds; // no movement time
  int hrLow;
  int hrHigh;
  int spo2Low;

  Thresholds({
    required this.fallAccelMag,
    required this.inactivitySeconds,
    required this.hrLow,
    required this.hrHigh,
    required this.spo2Low,
  });

  static Thresholds defaults() => Thresholds(
    fallAccelMag: 2.5,
    inactivitySeconds: 30,
    hrLow: 45,
    hrHigh: 140,
    spo2Low: 92,
  );
}

class SafetyRules {
  SensorSample? _last;
  DateTime? _lastMotionTs;

  AlarmEvent? evaluate(SensorSample s, Thresholds t) {
    _last ??= s;
    _lastMotionTs ??= s.ts;

    final mag = s.accelMag ?? 0.0;
    final lastMag = _last!.accelMag ?? 0.0;

    final moved = (mag - lastMag).abs() > 0.15;
    if (moved) _lastMotionTs = s.ts;

    // Fall candidate: magnitude spike
    if (mag >= t.fallAccelMag) {
      _last = s;
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.fall,
        message: "Düşme şüphesi: ivme büyüklüğü ${mag.toStringAsFixed(2)}",
      );
    }

    // Inactivity
    final idleFor = s.ts.difference(_lastMotionTs!).inSeconds;
    if (idleFor >= t.inactivitySeconds) {
      _last = s;
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.inactivity,
        message: "Hareketsizlik: ${idleFor}s",
      );
    }

    // Abnormal HR (only if present)
    final hr = s.hr;
    if (hr != null && (hr <= t.hrLow || hr >= t.hrHigh)) {
      _last = s;
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.abnormalHeartRate,
        message: "Anormal nabız: $hr BPM",
      );
    }

    // Low SpO2 (only if present)
    final spo2 = s.spo2;
    if (spo2 != null && spo2 <= t.spo2Low) {
      _last = s;
      return AlarmEvent(
        ts: s.ts,
        type: AlarmType.lowSpo2,
        message: "Düşük SpO₂: $spo2%",
      );
    }

    _last = s;
    return null;
  }
}
