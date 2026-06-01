import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/application/use_cases/generate_alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/break_period.dart';
import 'package:kurone_ko_alarm/domain/entities/work_day.dart';

void main() {
  late GenerateAlarmPlanUseCaseImpl useCase;

  setUp(() {
    useCase = GenerateAlarmPlanUseCaseImpl();
  });

  group('GenerateAlarmPlanUseCase', () {
    test('generates main and pre-warning alarm for each break period', () {
      final workDay = WorkDay(
        id: 'wd1',
        date: DateTime(2026, 5, 8),
        startTime: DateTime(2026, 5, 8, 9, 0),
        endTime: DateTime(2026, 5, 8, 17, 0),
      );

      final lunchBreak = BreakPeriod(
        id: 'bp_lunch',
        workDayId: 'wd1',
        startTime: DateTime(2026, 5, 8, 12, 0),
        endTime: DateTime(2026, 5, 8, 13, 0),
        type: BreakType.lunch,
      );

      final shortBreak = BreakPeriod(
        id: 'bp_short',
        workDayId: 'wd1',
        startTime: DateTime(2026, 5, 8, 15, 0),
        endTime: DateTime(2026, 5, 8, 15, 15),
        type: BreakType.short,
      );

      final plan = useCase.generate(
        scheduleId: 'sd1',
        workDays: [workDay],
        breakPeriods: [lunchBreak, shortBreak],
      );

      expect(plan.scheduleId, equals('sd1'));
      expect(plan.alarms.length, equals(4)); // 2 per break period

      final mainAlarms = plan.mainAlarms;
      final preWarnings = plan.preWarningAlarms;

      expect(mainAlarms.length, equals(2));
      expect(preWarnings.length, equals(2));
    });

    test('pre-warning is exactly 1 minute before main alarm', () {
      final workDay = WorkDay(
        id: 'wd1',
        date: DateTime(2026, 5, 8),
        startTime: DateTime(2026, 5, 8, 9, 0),
        endTime: DateTime(2026, 5, 8, 17, 0),
      );

      final breakPeriod = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: DateTime(2026, 5, 8, 12, 0),
        endTime: DateTime(2026, 5, 8, 13, 0),
        type: BreakType.lunch,
      );

      final plan = useCase.generate(
        scheduleId: 'sd1',
        workDays: [workDay],
        breakPeriods: [breakPeriod],
      );

      final mainAlarm = plan.mainAlarms.first;
      final preWarning = plan.preWarningAlarms.first;

      expect(
        preWarning.scheduledTime,
        equals(mainAlarm.scheduledTime.subtract(const Duration(minutes: 1))),
      );
    });

    test('main alarm has breakStart tone, pre-warning has preBreak tone', () {
      final workDay = WorkDay(
        id: 'wd1',
        date: DateTime(2026, 5, 8),
        startTime: DateTime(2026, 5, 8, 9, 0),
        endTime: DateTime(2026, 5, 8, 17, 0),
      );

      final breakPeriod = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: DateTime(2026, 5, 8, 12, 0),
        endTime: DateTime(2026, 5, 8, 13, 0),
        type: BreakType.lunch,
      );

      final plan = useCase.generate(
        scheduleId: 'sd1',
        workDays: [workDay],
        breakPeriods: [breakPeriod],
      );

      final mainAlarm = plan.mainAlarms.first;
      final preWarning = plan.preWarningAlarms.first;

      expect(mainAlarm.toneProfile, equals(ToneProfile.breakStart));
      expect(preWarning.toneProfile, equals(ToneProfile.preBreak));
    });

    test('generates zero alarms when no break periods', () {
      final workDay = WorkDay(
        id: 'wd1',
        date: DateTime(2026, 5, 8),
        startTime: DateTime(2026, 5, 8, 9, 0),
        endTime: DateTime(2026, 5, 8, 17, 0),
      );

      final plan = useCase.generate(
        scheduleId: 'sd1',
        workDays: [workDay],
        breakPeriods: [],
      );

      expect(plan.alarms, isEmpty);
    });

    test('plan id is derived from schedule id', () {
      final plan = useCase.generate(
        scheduleId: 'my_schedule',
        workDays: [],
        breakPeriods: [],
      );

      expect(plan.id, equals('plan_my_schedule'));
      expect(plan.scheduleId, equals('my_schedule'));
    });

    test('alarms are disabled by default (enabled=true)', () {
      final workDay = WorkDay(
        id: 'wd1',
        date: DateTime(2026, 5, 8),
        startTime: DateTime(2026, 5, 8, 9, 0),
        endTime: DateTime(2026, 5, 8, 17, 0),
      );

      final breakPeriod = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: DateTime(2026, 5, 8, 12, 0),
        endTime: DateTime(2026, 5, 8, 13, 0),
        type: BreakType.lunch,
      );

      final plan = useCase.generate(
        scheduleId: 'sd1',
        workDays: [workDay],
        breakPeriods: [breakPeriod],
      );

      for (final alarm in plan.alarms) {
        expect(alarm.enabled, isTrue);
      }
    });
  });
}
