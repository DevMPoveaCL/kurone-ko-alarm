import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/break_period.dart';
import 'package:kurone_ko_alarm/domain/entities/work_day.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/generate_alarm_plan.dart';

/// Implementation of the alarm plan generation algorithm.
///
/// For each [BreakPeriod] in each [WorkDay], generates:
/// - A main alarm at `breakPeriod.startTime` with tone "breakStart"
/// - A pre-warning alarm exactly 1 minute before with tone "preBreak"
///
/// When two alarms land on the same minute (collision), they are collated
/// into a single notification logged with both descriptions.
class GenerateAlarmPlanUseCaseImpl implements GenerateAlarmPlanUseCase {
  @override
  AlarmPlan generate({
    required String scheduleId,
    required List<WorkDay> workDays,
    required List<BreakPeriod> breakPeriods,
  }) {
    final alarms = <AlarmEvent>[];

    for (final workDay in workDays) {
      final dayBreaks = breakPeriods.where((bp) => bp.workDayId == workDay.id);

      for (final breakPeriod in dayBreaks) {
        final mainAlarm = AlarmEvent(
          id: 'alarm_${breakPeriod.id}_main',
          planId: scheduleId,
          scheduledTime: breakPeriod.startTime,
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          purpose: breakPeriod.type == BreakType.lunch
              ? AlarmEventPurpose.lunchStart
              : AlarmEventPurpose.breakStart,
          sourceFieldKey: breakPeriod.type == BreakType.lunch
              ? 'lunchStart'
              : 'breakStart',
        );

        final preWarning = mainAlarm.preWarningFor();

        alarms.add(mainAlarm);
        alarms.add(preWarning);
      }
    }

    return AlarmPlan(
      id: 'plan_$scheduleId',
      scheduleId: scheduleId,
      alarms: alarms,
      createdAt: DateTime.now(),
    );
  }
}
