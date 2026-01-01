import 'dart:convert';

class SensorSample {
  final DateTime ts;

  final int? hr;
  final int? spo2;

  // Accel (g) and gyro (deg/s) - you can choose your units as long as ESP32 matches.
  final double? ax, ay, az;
  final double? gx, gy, gz;

  final Map<String, dynamic>? raw;

  const SensorSample({
    required this.ts,
    this.hr,
    this.spo2,
    this.ax,
    this.ay,
    this.az,
    this.gx,
    this.gy,
    this.gz,
    this.raw,
  });

  double? get accelMag {
    if (ax == null || ay == null || az == null) return null;
    final x = ax!, y = ay!, z = az!;
    return (x * x + y * y + z * z).sqrt();
  }

  static SensorSample? tryParseLine(String line) {
    final s = line.trim();
    if (s.isEmpty) return null;

    // Preferred format: JSON line
    // {"hr":78,"spo2":97,"ax":0.01,"ay":0.02,"az":1.00,"gx":0.1,"gy":0.2,"gz":0.3,"ts":1735...}
    if (s.startsWith('{') && s.endsWith('}')) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return SensorSample(
          ts: DateTime.now(),
          hr: _asInt(m['hr']),
          spo2: _asInt(m['spo2']),
          ax: _asDouble(m['ax']),
          ay: _asDouble(m['ay']),
          az: _asDouble(m['az']),
          gx: _asDouble(m['gx']),
          gy: _asDouble(m['gy']),
          gz: _asDouble(m['gz']),
          raw: m,
        );
      } catch (_) {
        return null;
      }
    }

    // Fallback: CSV line
    // hr,spo2,ax,ay,az,gx,gy,gz
    final parts = s.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 8) {
      return SensorSample(
        ts: DateTime.now(),
        hr: int.tryParse(parts[0]),
        spo2: int.tryParse(parts[1]),
        ax: double.tryParse(parts[2]),
        ay: double.tryParse(parts[3]),
        az: double.tryParse(parts[4]),
        gx: double.tryParse(parts[5]),
        gy: double.tryParse(parts[6]),
        gz: double.tryParse(parts[7]),
        raw: {'csv': s},
      );
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

extension _Sqrt on num {
  double sqrt() => (this is double ? this as double : toDouble()).pow(0.5);
  double pow(double p) => MathPow.pow(toDouble(), p);
}

// Minimal pow to avoid importing dart:math everywhere.
class MathPow {
  static double pow(double base, double exp) {
    // only exp=0.5 used in this file; safe for our use
    if (exp == 0.5) {
      double x = base;
      double guess = x > 1 ? x / 2 : 1;
      for (int i = 0; i < 10; i++) {
        guess = 0.5 * (guess + x / guess);
      }
      return guess;
    }
    // fallback
    double result = 1.0;
    int e = exp.toInt();
    for (int i = 0; i < e; i++) result *= base;
    return result;
  }
}
