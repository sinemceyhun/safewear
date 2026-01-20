import 'dart:convert';
import 'dart:math' as math;

class SensorSample {
  final DateTime ts;

  // Required (current payload)
  final double bpm; // e.g., 72.5

  // ✅ FIXED mapping:
  // 0 none
  // 1 fall
  // 2 manual(button)
  final int alarm;

  final double? gx, gy, gz;
  final Map<String, dynamic>? raw;

  const SensorSample({
    required this.ts,
    required this.bpm,
    required this.alarm,
    this.gx,
    this.gy,
    this.gz,
    this.raw,
  });

  bool get hasGyro => gx != null && gy != null && gz != null;

  double? get gyroMag {
    if (!hasGyro) return null;
    final x = gx!, y = gy!, z = gz!;
    return math.sqrt(x * x + y * y + z * z);
  }

  static SensorSample? tryParseLine(String line) {
    final s = line.trim();
    if (s.isEmpty) return null;

    // Expected JSON line: {"bpm":72.5,"alarm":0} (+ optional gx/gy/gz)
    if (s.startsWith('{') && s.endsWith('}')) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;

        final bpm = _asDouble(m['bpm']);
        final alarm = _asInt(m['alarm']);
        if (bpm == null || alarm == null) return null;

        return SensorSample(
          ts: DateTime.now(),
          bpm: bpm,
          alarm: alarm,
          gx: _asDouble(m['gx']),
          gy: _asDouble(m['gy']),
          gz: _asDouble(m['gz']),
          raw: m,
        );
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
