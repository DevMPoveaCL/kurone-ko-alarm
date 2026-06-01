import 'package:kurone_ko_alarm/application/use_cases/reviewed_alarm_plan_mapper.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/permission_gateway.dart';

/// Review state for the human gate before alarm scheduling.
enum ReviewState { draft, reviewing, needsDate, confirmed, cancelled }

/// Immutable review session used by presentation state later.
final class ReviewSession {
  final ScheduleDraft draft;
  final ReviewState state;

  const ReviewSession({required this.draft, required this.state});

  bool get canConfirm =>
      state == ReviewState.reviewing &&
      !ReviewedAlarmPlanMapper.hasMissingRequiredDates(draft) &&
      !ReviewedAlarmPlanMapper.hasInvalidAlarmTimes(draft);

  ReviewSession copyWith({ScheduleDraft? draft, ReviewState? state}) {
    return ReviewSession(
      draft: draft ?? this.draft,
      state: state ?? this.state,
    );
  }
}

/// Application service for the human review gate.
final class ReviewAndConfirmUseCaseImpl implements ReviewAndConfirmUseCase {
  final LocalRepository repository;
  final Clock clock;
  final AlarmScheduler scheduler;
  final PermissionGateway? permissionGateway;

  const ReviewAndConfirmUseCaseImpl({
    required this.repository,
    required this.clock,
    required this.scheduler,
    this.permissionGateway,
  });

  ReviewSession startReview(ScheduleDraft draft) {
    return ReviewSession(
      draft: draft,
      state:
          ReviewedAlarmPlanMapper.hasMissingRequiredDates(draft) ||
              ReviewedAlarmPlanMapper.hasInvalidAlarmTimes(draft)
          ? ReviewState.needsDate
          : ReviewState.reviewing,
    );
  }

  Future<ReviewSession> confirmReview(ReviewSession session) async {
    await confirm(session.draft);
    return session.copyWith(state: ReviewState.confirmed);
  }

  Future<ReviewSession> cancelReview(ReviewSession session) async {
    await cancel(session.draft);
    return session.copyWith(state: ReviewState.cancelled);
  }

  @override
  Future<AlarmPlan> confirm(ScheduleDraft draft) async {
    final plan = ReviewedAlarmPlanMapper.buildPlan(
      draft,
      createdAt: clock.now(),
    );
    _throwIfAnyEnabledAlarmIsInThePast(plan);

    await _ensureSchedulingPermissions();

    await repository.saveDraft(draft);
    await repository.savePlan(plan);
    await scheduler.rescheduleAll(plan.alarms);
    return plan;
  }

  void _throwIfAnyEnabledAlarmIsInThePast(AlarmPlan plan) {
    final now = clock.now();
    final hasPastAlarm = plan.alarms.any(
      (alarm) => alarm.enabled && alarm.scheduledTime.isBefore(now),
    );
    if (!hasPastAlarm) {
      return;
    }

    throw const ScheduleValidationFailure(
      message:
          'Hay alarmas con fecha u hora en el pasado. Actualiza la fecha u hora antes de confirmar.',
    );
  }

  Future<void> _ensureSchedulingPermissions() async {
    final permissions = permissionGateway;
    if (permissions == null) {
      return;
    }

    if (!await permissions.hasNotificationPermission()) {
      final granted = await permissions.requestNotificationPermission();
      if (!granted) {
        throw const PermissionDenied(permission: 'notifications');
      }
    }

    if (!await permissions.hasExactAlarmPermission()) {
      final granted = await permissions.requestExactAlarm();
      if (!granted) {
        throw const PermissionDenied(permission: 'exactAlarm');
      }
    }

    if (!await permissions.hasFullScreenIntentPermission()) {
      final granted = await permissions.requestFullScreenIntentPermission();
      if (!granted) {
        throw const PermissionDenied(permission: 'fullScreenIntent');
      }
    }
  }

  @override
  Future<void> cancel(ScheduleDraft draft) async {
    await repository.deleteDraft(draft.id);
  }

  @override
  ScheduleDraft updateEntry(
    ScheduleDraft draft, {
    required String entryId,
    required Map<String, String> fields,
  }) {
    return draft.copyWith(
      entries: draft.entries.map((entry) {
        if (entry.id != entryId) {
          return entry;
        }

        return entry.copyWith(fields: {...entry.fields, ...fields});
      }).toList(),
    );
  }
}
