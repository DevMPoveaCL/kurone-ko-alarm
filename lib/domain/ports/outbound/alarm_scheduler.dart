import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';

/// Outbound port for scheduling alarms on the native platform.
abstract class AlarmScheduler {
  /// Schedules a single alarm event. Returns the native alarm ID.
  Future<int> schedule(AlarmEvent event);

  /// Cancels a scheduled alarm by its native ID.
  Future<void> cancel(int nativeAlarmId);

  /// Prunes native persisted alarms older than or equal to [now].
  Future<void> pruneNativeStaleAlarms(DateTime now);

  /// Reschedules all enabled alarms from the given list.
  Future<void> rescheduleAll(List<AlarmEvent> events);

  /// Reads and clears the native outcome log, returning dismissal/fired records.
  Future<List<Map<String, Object?>>> syncAlarmOutcomes();

  /// Computes the stable native alarm ID that will be used for [event].
  int nativeIdFor(AlarmEvent event);
}
