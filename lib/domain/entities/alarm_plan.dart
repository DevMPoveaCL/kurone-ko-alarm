import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';

/// Plan containing one or more alarm events generated from a schedule.
final class AlarmPlan {
  final String id;
  final String scheduleId;
  final List<AlarmEvent> alarms;
  final DateTime createdAt;

  const AlarmPlan({
    required this.id,
    required this.scheduleId,
    required this.alarms,
    required this.createdAt,
  });

  /// Main alarms only (not pre-warnings).
  List<AlarmEvent> get mainAlarms =>
      alarms.where((a) => a.type == AlarmEventType.main).toList();

  /// Pre-warning alarms only.
  List<AlarmEvent> get preWarningAlarms =>
      alarms.where((a) => a.type == AlarmEventType.preWarning).toList();

  AlarmPlan copyWith({
    String? id,
    String? scheduleId,
    List<AlarmEvent>? alarms,
    DateTime? createdAt,
  }) {
    return AlarmPlan(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      alarms: alarms ?? this.alarms,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          scheduleId == other.scheduleId &&
          alarms == other.alarms &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, scheduleId, alarms, createdAt);

  @override
  String toString() =>
      'AlarmPlan(id: $id, scheduleId: $scheduleId, '
      'alarms: ${alarms.length}, createdAt: $createdAt)';
}
