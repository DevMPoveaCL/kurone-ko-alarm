import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';

/// Inbound port for reviewing and confirming a schedule draft.
abstract class ReviewAndConfirmUseCase {
  /// Confirms the draft and persists it, returning an alarm plan.
  Future<AlarmPlan> confirm(ScheduleDraft draft);

  /// Cancels and discards the draft.
  Future<void> cancel(ScheduleDraft draft);

  /// Updates an entry within the draft (for inline corrections).
  ScheduleDraft updateEntry(
    ScheduleDraft draft, {
    required String entryId,
    required Map<String, String> fields,
  });
}
