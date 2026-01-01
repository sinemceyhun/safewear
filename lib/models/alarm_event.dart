enum AlarmType { fall, inactivity, abnormalHeartRate, lowSpo2, manual }

class AlarmEvent {
  final DateTime ts;
  final AlarmType type;
  final String message;

  AlarmEvent({required this.ts, required this.type, required this.message});
}
