import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/work_day.dart';
import 'package:kurone_ko_alarm/domain/entities/break_period.dart';

/// Inbound port for generating alarm plans from confirmed schedules.
abstract class GenerateAlarmPlanUseCase {
  /// Generates an alarm plan from work days and their break periods.
  /// Each break period produces a main alarm at start and a pre-warning
  /// exactly 1 minute before with a distinct tone profile.
  AlarmPlan generate({
    required String scheduleId,
    required List<WorkDay> workDays,
    required List<BreakPeriod> breakPeriods,
  });
}
