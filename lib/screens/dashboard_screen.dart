import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/emergency_actions_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _alarmText(int alarm) {
    switch (alarm) {
      case 0:
        return '0 (None)';
      case 1:
        return '1 (Manual / Button)';
      case 2:
        return '2 (Fall)';
      default:
        return '$alarm (Unknown)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sample = s.latest;

    final bpmData = s.bpmHistory;
    final hasChart = bpmData.isNotEmpty;

    final double? minBpm = hasChart ? bpmData.reduce((a, b) => a < b ? a : b) : null;
    final double? maxBpm = hasChart ? bpmData.reduce((a, b) => a > b ? a : b) : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _kv('Mode', s.dataSource.name)),
            const SizedBox(width: 12),
            Expanded(child: _kv('BLE', s.connectionState.name)),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest sample', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _kv('BPM', sample != null ? sample.bpm.toStringAsFixed(1) : '—'),
                _kv('Alarm', sample != null ? _alarmText(sample.alarm) : '—'),
                _kv('GyroMag', sample?.gyroMag != null ? sample!.gyroMag!.toStringAsFixed(3) : '—'),
                _kv('Timestamp', sample?.ts.toIso8601String() ?? '—'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BPM Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (!hasChart)
                  const Text('No BPM data yet.')
                else ...[
                  Row(
                    children: [
                      Text('Min: ${minBpm!.toStringAsFixed(1)}'),
                      const SizedBox(width: 12),
                      Text('Max: ${maxBpm!.toStringAsFixed(1)}'),
                      const Spacer(),
                      Text('N: ${bpmData.length}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _LineChartPainter(values: bpmData),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: ListTile(
            title: const Text('Alerts (latest)'),
            subtitle: Text(s.alerts.isEmpty ? 'No alerts' : '${s.alerts.first.type}: ${s.alerts.first.message}'),
          ),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          icon: const Icon(Icons.warning_amber),
          label: const Text('Emergency'),
          onPressed: () async {
            const reason = 'In-app emergency button';
            await context.read<AppState>().triggerEmergency(reason: reason);

            if (!context.mounted) return;

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const EmergencyActionsSheet(reason: reason),
            );
          },
        ),
      ],
    );
  }
}

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

/// Simple line chart painter (no extra deps)
class _LineChartPainter extends CustomPainter {
  final List<double> values;

  _LineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);

    // avoid zero range
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final pad = 10.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    // grid paint (light)
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.grey.withOpacity(0.2);

    // border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gridPaint);

    // horizontal grid lines
    for (int i = 1; i <= 3; i++) {
      final y = pad + (h / 4.0) * i;
      canvas.drawLine(Offset(pad, y), Offset(pad + w, y), gridPaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.blueAccent;

    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final x = pad + (w * i) / (values.length - 1);
      final norm = (values[i] - minV) / range;
      final y = pad + h * (1.0 - norm);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // last point dot
    final lastX = pad + w;
    final lastNorm = (values.last - minV) / range;
    final lastY = pad + h * (1.0 - lastNorm);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blueAccent;

    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values.length != values.length ||
        (values.isNotEmpty && oldDelegate.values.isNotEmpty && oldDelegate.values.last != values.last);
  }
}
