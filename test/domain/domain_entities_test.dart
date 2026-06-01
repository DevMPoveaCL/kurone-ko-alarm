import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/work_day.dart';
import 'package:kurone_ko_alarm/domain/entities/break_period.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';

void main() {
  group('WorkDay', () {
    test('copyWith creates a new instance with updated fields', () {
      final date = DateTime(2026, 5, 8);
      final start = DateTime(2026, 5, 8, 9, 0);
      final end = DateTime(2026, 5, 8, 17, 0);

      final original = WorkDay(
        id: 'wd1',
        date: date,
        startTime: start,
        endTime: end,
      );

      final updated = original.copyWith(endTime: DateTime(2026, 5, 8, 18, 0));

      expect(updated.id, equals('wd1'));
      expect(updated.startTime, equals(start));
      expect(updated.endTime, equals(DateTime(2026, 5, 8, 18, 0)));
    });

    test('equality based on all fields', () {
      final date = DateTime(2026, 5, 8);
      final start = DateTime(2026, 5, 8, 9, 0);
      final end = DateTime(2026, 5, 8, 17, 0);

      final a = WorkDay(id: 'wd1', date: date, startTime: start, endTime: end);
      final b = WorkDay(id: 'wd1', date: date, startTime: start, endTime: end);
      final c = WorkDay(id: 'wd2', date: date, startTime: start, endTime: end);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('BreakPeriod', () {
    test('copyWith preserves fields correctly', () {
      final start = DateTime(2026, 5, 8, 12, 0);
      final end = DateTime(2026, 5, 8, 13, 0);

      final original = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: start,
        endTime: end,
        type: BreakType.lunch,
      );

      final updated = original.copyWith(type: BreakType.short);

      expect(updated.id, equals('bp1'));
      expect(updated.workDayId, equals('wd1'));
      expect(updated.type, equals(BreakType.short));
    });

    test('equality based on all fields', () {
      final start = DateTime(2026, 5, 8, 12, 0);
      final end = DateTime(2026, 5, 8, 13, 0);

      final a = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: start,
        endTime: end,
        type: BreakType.lunch,
      );
      final b = BreakPeriod(
        id: 'bp1',
        workDayId: 'wd1',
        startTime: start,
        endTime: end,
        type: BreakType.lunch,
      );

      expect(a, equals(b));
    });
  });

  group('Confidence', () {
    test('high constructor creates high level', () {
      const c = Confidence.high();
      expect(c.level, equals(ConfidenceLevel.high));
      expect(c.isHigh, isTrue);
      expect(c.isLow, isFalse);
    });

    test('medium constructor with reason and ambiguous columns', () {
      final c = const Confidence.medium(
        reason: 'merged header',
        ambiguousColumns: ['col2'],
      );
      expect(c.level, equals(ConfidenceLevel.medium));
      expect(c.reason, equals('merged header'));
      expect(c.ambiguousColumns, contains('col2'));
    });

    test('low constructor requires reason', () {
      final c = const Confidence.low(
        reason: 'unreadable text',
        ambiguousColumns: ['col3', 'col4'],
      );
      expect(c.level, equals(ConfidenceLevel.low));
      expect(c.isLow, isTrue);
      expect(c.ambiguousColumns.length, equals(2));
    });

    test('equality based on level, reason, and ambiguous columns', () {
      const a = Confidence.low(reason: 'foo', ambiguousColumns: ['col1']);
      const b = Confidence.low(reason: 'foo', ambiguousColumns: ['col1']);
      const c = Confidence.low(reason: 'bar', ambiguousColumns: ['col1']);
      const d = Confidence.low(reason: 'foo', ambiguousColumns: ['col2']);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  group('RawEntry', () {
    test('fields stored and accessible', () {
      final entry = RawEntry(
        id: 're1',
        source: ImportSource.image,
        fields: {'horario': '08:00-17:00', 'descanso': '12:00-13:00'},
        confidence: const Confidence.high(),
      );

      expect(entry.fields['horario'], equals('08:00-17:00'));
      expect(entry.source, equals(ImportSource.image));
    });

    test('copyWith updates fields', () {
      final original = RawEntry(
        id: 're1',
        source: ImportSource.excel,
        fields: {'horario': '08:00-17:00'},
        confidence: const Confidence.high(),
      );

      final updated = original.copyWith(fields: {'horario': '09:00-18:00'});

      expect(updated.fields['horario'], equals('09:00-18:00'));
      expect(updated.source, equals(ImportSource.excel));
    });
  });

  group('ScheduleDraft', () {
    test('lowConfidenceEntries filters correctly', () {
      final draft = ScheduleDraft(
        id: 'sd1',
        source: ImportSource.image,
        entries: [
          RawEntry(
            id: 'e1',
            source: ImportSource.image,
            fields: const {'horario': '08:00'},
            confidence: const Confidence.high(),
          ),
          RawEntry(
            id: 'e2',
            source: ImportSource.image,
            fields: const {'horario': '09:00'},
            confidence: const Confidence.low(reason: 'unclear'),
          ),
          RawEntry(
            id: 'e3',
            source: ImportSource.image,
            fields: const {'horario': '10:00'},
            confidence: const Confidence.medium(),
          ),
        ],
        createdAt: DateTime(2026, 5, 8),
      );

      expect(draft.lowConfidenceEntries.length, equals(1));
      expect(draft.lowConfidenceEntries.first.id, equals('e2'));
    });

    test(
      'lowConfidenceEntries is empty when all entries are high confidence',
      () {
        final draft = ScheduleDraft(
          id: 'sd1',
          source: ImportSource.excel,
          entries: [
            RawEntry(
              id: 'e1',
              source: ImportSource.excel,
              fields: const {'horario': '08:00'},
              confidence: const Confidence.high(),
            ),
            RawEntry(
              id: 'e2',
              source: ImportSource.excel,
              fields: const {'horario': '09:00'},
              confidence: const Confidence.high(),
            ),
          ],
          createdAt: DateTime(2026, 5, 8),
        );

        expect(draft.lowConfidenceEntries, isEmpty);
      },
    );
  });

  group('AlarmEvent', () {
    test('preWarningFor creates pre-warning 1 minute before main alarm', () {
      final mainTime = DateTime(2026, 5, 8, 14, 0);

      final main = AlarmEvent(
        id: 'ae1',
        planId: 'ap1',
        scheduledTime: mainTime,
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
      );

      final preWarning = main.preWarningFor();

      expect(preWarning.scheduledTime, equals(DateTime(2026, 5, 8, 13, 59)));
      expect(preWarning.type, equals(AlarmEventType.preWarning));
      expect(preWarning.toneProfile, equals(ToneProfile.preBreak));
      expect(preWarning.id, equals('ae1_pre'));
    });

    test('preWarningFor throws for non-main alarm', () {
      final pre = AlarmEvent(
        id: 'ae2',
        planId: 'ap1',
        scheduledTime: DateTime(2026, 5, 8, 13, 59),
        type: AlarmEventType.preWarning,
        toneProfile: ToneProfile.preBreak,
      );

      expect(() => pre.preWarningFor(), throwsA(isA<StateError>()));
    });

    test('copyWith preserves unchanged fields', () {
      final original = AlarmEvent(
        id: 'ae1',
        planId: 'ap1',
        scheduledTime: DateTime(2026, 5, 8, 14, 0),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        enabled: true,
      );

      final updated = original.copyWith(enabled: false);

      expect(updated.id, equals('ae1'));
      expect(updated.planId, equals('ap1'));
      expect(updated.scheduledTime, equals(DateTime(2026, 5, 8, 14, 0)));
      expect(updated.type, equals(AlarmEventType.main));
      expect(updated.enabled, isFalse);
    });
  });

  group('AlarmPlan', () {
    test('mainAlarms filters correctly', () {
      final plan = AlarmPlan(
        id: 'ap1',
        scheduleId: 'sd1',
        alarms: [
          AlarmEvent(
            id: 'ae1',
            planId: 'ap1',
            scheduledTime: DateTime(2026, 5, 8, 12, 0),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
          ),
          AlarmEvent(
            id: 'ae2',
            planId: 'ap1',
            scheduledTime: DateTime(2026, 5, 8, 11, 59),
            type: AlarmEventType.preWarning,
            toneProfile: ToneProfile.preBreak,
          ),
          AlarmEvent(
            id: 'ae3',
            planId: 'ap1',
            scheduledTime: DateTime(2026, 5, 8, 17, 0),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
          ),
        ],
        createdAt: DateTime(2026, 5, 8),
      );

      expect(plan.mainAlarms.length, equals(2));
      expect(plan.preWarningAlarms.length, equals(1));
      expect(plan.preWarningAlarms.first.id, equals('ae2'));
    });

    test('alarm count reflects all alarms', () {
      final plan = AlarmPlan(
        id: 'ap1',
        scheduleId: 'sd1',
        alarms: [
          AlarmEvent(
            id: 'ae1',
            planId: 'ap1',
            scheduledTime: DateTime(2026, 5, 8, 12, 0),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
          ),
          AlarmEvent(
            id: 'ae2',
            planId: 'ap1',
            scheduledTime: DateTime(2026, 5, 8, 11, 59),
            type: AlarmEventType.preWarning,
            toneProfile: ToneProfile.preBreak,
          ),
        ],
        createdAt: DateTime(2026, 5, 8),
      );

      expect(plan.alarms.length, equals(2));
    });
  });

  group('ImportSource enum', () {
    test('has image and excel values', () {
      expect(ImportSource.values, contains(ImportSource.image));
      expect(ImportSource.values, contains(ImportSource.excel));
    });
  });
}
