import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';

/// DTO for an alarm plan persisted to the database.
final class AlarmPlanDto {
  final String id;
  final String scheduleId;
  final List<AlarmEventDto> alarms;
  final DateTime createdAt;

  const AlarmPlanDto({
    required this.id,
    required this.scheduleId,
    required this.alarms,
    required this.createdAt,
  });
}

/// DTO for an individual alarm event persisted to the database.
final class AlarmEventDto {
  final String id;
  final String planId;
  final DateTime scheduledTime;
  final AlarmEventType type;
  final ToneProfile toneProfile;
  final bool enabled;
  final int? androidAlarmId;

  const AlarmEventDto({
    required this.id,
    required this.planId,
    required this.scheduledTime,
    required this.type,
    required this.toneProfile,
    this.enabled = true,
    this.androidAlarmId,
  });
}
