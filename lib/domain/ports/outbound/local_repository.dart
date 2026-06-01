import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';

/// Outbound port for local persistence of schedules and alarm data.
abstract class LocalRepository {
  // --- ScheduleDraft CRUD ---
  Future<void> saveDraft(ScheduleDraft draft);
  Future<ScheduleDraft?> getDraft(String id);
  Future<List<ScheduleDraft>> getAllDrafts();
  Future<void> deleteDraft(String id);

  // --- AlarmPlan CRUD ---
  Future<void> savePlan(AlarmPlan plan);
  Future<AlarmPlan?> getPlan(String id);
  Future<List<AlarmPlan>> getAllPlans();

  // --- AlarmEvent queries ---
  Future<List<AlarmEvent>> getEventsForPlan(String planId);
  Future<List<AlarmEvent>> getAllEnabledEvents();

  /// Removes enabled alarm events whose scheduledTime is in the past
  /// relative to [now], and returns the native Android alarm IDs that were
  /// cancelled so callers can also cancel them in the native scheduler.
  ///
  /// Disabled events are not pruned — they are inert and do not ring.
  Future<List<int>> pruneStaleEnabledEvents(DateTime now);

  /// Updates the status of an alarm event and records the change timestamp.
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status);

  /// Updates a single alarm event in place, preserving its plan association.
  Future<void> updateAlarmEvent(AlarmEvent event);

  /// Returns alarm events whose status is not `scheduled` (history entries).
  Future<List<AlarmEvent>> getAlarmHistory();

  /// Hard-deletes history entries whose `statusChangedAt` is older than [cutoff].
  Future<void> purgeHistoryOlderThan(DateTime cutoff);
}
