import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/application/use_cases/reviewed_alarm_plan_mapper.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

void main() {
  group('ReviewedAlarmPlanMapper alarm purpose', () {
    test('assigns distinct purposes to break start and break end alarms', () {
      final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
        _draftWithFields({
          'date': '20-MAYO-2026',
          'breakStart': '12:30',
          'breakEnd': '12:45',
        }),
        planId: 'plan-1',
      );

      expect(alarms.map((alarm) => (alarm.scheduledTime, alarm.purpose)), [
        (DateTime(2026, 5, 20, 12, 30), AlarmEventPurpose.breakStart),
        (DateTime(2026, 5, 20, 12, 45), AlarmEventPurpose.breakEnd),
      ]);
    });

    test('assigns lunch start purpose and leaves lunch end informational', () {
      final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
        _draftWithFields({
          'date': '20-MAYO-2026',
          'lunchStart': '13:00',
          'lunchEnd': '14:00',
        }),
        planId: 'plan-1',
      );

      expect(alarms.map((alarm) => (alarm.scheduledTime, alarm.purpose)), [
        (DateTime(2026, 5, 20, 13), AlarmEventPurpose.lunchStart),
      ]);
    });

    test('pre-warning keeps the purpose of its upcoming main alarm', () {
      final alarms = ReviewedAlarmPlanMapper.buildAlarms(
        _draftWithFields({'date': '20-MAYO-2026', 'breakEnd': '12:45'}),
        planId: 'plan-1',
      );

      expect(
        alarms.map((alarm) => (alarm.type, alarm.scheduledTime, alarm.purpose)),
        [
          (
            AlarmEventType.preWarning,
            DateTime(2026, 5, 20, 12, 44),
            AlarmEventPurpose.breakEnd,
          ),
          (
            AlarmEventType.main,
            DateTime(2026, 5, 20, 12, 45),
            AlarmEventPurpose.breakEnd,
          ),
        ],
      );
    });

    test(
      'schedules real Excel format columns and omits informational fields',
      () {
        final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          _draftWithFields({
            'date': '20-MAYO-2026',
            'startTime': '00:00',
            'breakStart': '02:30',
            'breakEnd': '02:45',
            'lunchStart': '05:00',
            'lunchEnd': '05:30',
            'extendedLunchStart': '05:30',
            'extendedLunchEnd': '05:45',
            'secondBreakStart': '08:00',
            'secondBreakEnd': '08:15',
            'endTime': '10:00',
          }),
          planId: 'plan-1',
        );

        expect(alarms.map((alarm) => alarm.scheduledTime), [
          DateTime(2026, 5, 20, 0),
          DateTime(2026, 5, 20, 2, 30),
          DateTime(2026, 5, 20, 2, 45),
          DateTime(2026, 5, 20, 5),
          DateTime(2026, 5, 20, 5, 45),
          DateTime(2026, 5, 20, 8),
          DateTime(2026, 5, 20, 8, 15),
          DateTime(2026, 5, 20, 10),
        ]);
        expect(alarms.map((alarm) => alarm.purpose), [
          AlarmEventPurpose.shiftStart,
          AlarmEventPurpose.breakStart,
          AlarmEventPurpose.breakEnd,
          AlarmEventPurpose.lunchStart,
          AlarmEventPurpose.lunchExtensionEnd,
          AlarmEventPurpose.breakStart,
          AlarmEventPurpose.breakEnd,
          AlarmEventPurpose.shiftEnd,
        ]);
      },
    );

    test(
      'schedules extendedLunchEnd and secondBreakStart as settable alarm fields',
      () {
        final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          _draftWithFields({
            'date': '20-MAYO-2026',
            'extendedLunchEnd': '05:45',
            'secondBreakStart': '08:00',
          }),
          planId: 'plan-1',
        );

        expect(alarms.map((alarm) => (alarm.scheduledTime, alarm.purpose)), [
          (DateTime(2026, 5, 20, 5, 45), AlarmEventPurpose.lunchExtensionEnd),
          (DateTime(2026, 5, 20, 8), AlarmEventPurpose.breakStart),
        ]);
      },
    );

    test('preserves source field key for every schedulable alarm', () {
      final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
        _draftWithFields({
          'date': '20-MAYO-2026',
          'startTime': '08:00',
          'breakStart': '10:00',
          'breakEnd': '10:15',
          'lunchStart': '13:00',
          'extendedLunchEnd': '14:30',
          'secondBreakStart': '16:00',
          'secondBreakEnd': '16:15',
          'endTime': '18:00',
        }),
        planId: 'plan-1',
      );

      expect(alarms.map((a) => a.sourceFieldKey), [
        'startTime',
        'breakStart',
        'breakEnd',
        'lunchStart',
        'extendedLunchEnd',
        'secondBreakStart',
        'secondBreakEnd',
        'endTime',
      ]);
    });

    test('pre-warning copies the sourceFieldKey of its main alarm', () {
      final alarms = ReviewedAlarmPlanMapper.buildAlarms(
        _draftWithFields({'date': '20-MAYO-2026', 'secondBreakStart': '15:00'}),
        planId: 'plan-1',
      );

      final main = alarms.firstWhere((a) => a.type == AlarmEventType.main);
      final pre = alarms.firstWhere((a) => a.type == AlarmEventType.preWarning);

      expect(main.sourceFieldKey, 'secondBreakStart');
      expect(pre.sourceFieldKey, 'secondBreakStart');
    });
  });

  group('AlarmReviewFieldPolicy', () {
    test(
      'settableAlarmFieldLabels includes Hora Inicio and Hora Termino',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        expect(labels.containsKey('startTime'), isTrue);
        expect(labels.containsKey('endTime'), isTrue);
        expect(labels['startTime'], 'Hora inicio');
        expect(labels['endTime'], 'Hora término');
      },
    );

    test(
      'settableAlarmFieldLabels includes all schedulable break and lunch fields',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        expect(labels.containsKey('breakStart'), isTrue);
        expect(labels.containsKey('breakEnd'), isTrue);
        expect(labels.containsKey('lunchStart'), isTrue);
        expect(labels.containsKey('extendedLunchEnd'), isTrue);
        expect(labels.containsKey('secondBreakStart'), isTrue);
        expect(labels.containsKey('secondBreakEnd'), isTrue);
      },
    );

    test(
      'settableAlarmFieldLabels excludes informational-only fields',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        expect(labels.containsKey('date'), isFalse);
        expect(labels.containsKey('lunchEnd'), isFalse);
        expect(labels.containsKey('extendedLunchStart'), isFalse);
        expect(labels.containsKey('name'), isFalse);
      },
    );

    test(
      'alarmTimeFieldKeys matches exactly the keys of settableAlarmFieldLabels',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        final keys = ReviewedAlarmPlanMapper.alarmTimeFieldKeys;
        expect(keys.toSet(), equals(labels.keys.toSet()));
      },
    );

    test(
      'informationalOnlyFieldKeys contains the non-schedulable time fields',
      () {
        final informational = ReviewedAlarmPlanMapper.informationalOnlyFieldKeys;
        expect(informational.contains('lunchEnd'), isTrue);
        expect(informational.contains('extendedLunchStart'), isTrue);
        expect(informational.contains('extendedLunchEnd'), isFalse);
        expect(informational.contains('secondBreakStart'), isFalse);
      },
    );

    test(
      'settableAlarmFieldLabels uses neutral Spanish without voseo',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        for (final label in labels.values) {
          expect(label, isNot(contains('Importá')));
          expect(label, isNot(contains('revisá')));
          expect(label, isNot(contains('tenés')));
        }
      },
    );

    test(
      'settableAlarmFieldLabels contains correct neutral Spanish labels for new fields',
      () {
        final labels = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;
        expect(labels['extendedLunchEnd'], 'Término almuerzo extendido');
        expect(labels['secondBreakStart'], 'Inicio segundo descanso');
      },
    );

    test(
      'purpose mapping assigns lunchExtensionEnd to extendedLunchEnd',
      () {
        final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          _draftWithFields({
            'date': '20-MAYO-2026',
            'extendedLunchEnd': '14:15',
          }),
          planId: 'plan-1',
        );
        expect(alarms.single.purpose, AlarmEventPurpose.lunchExtensionEnd);
      },
    );

    test(
      'purpose mapping assigns breakStart to secondBreakStart',
      () {
        final alarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          _draftWithFields({
            'date': '20-MAYO-2026',
            'secondBreakStart': '15:00',
          }),
          planId: 'plan-1',
        );
        expect(alarms.single.purpose, AlarmEventPurpose.breakStart);
      },
    );
  });
}

ScheduleDraft _draftWithFields(Map<String, String> fields) {
  return ScheduleDraft(
    id: 'draft-1',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 20),
    entries: [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: fields,
        confidence: const Confidence.high(),
      ),
    ],
  );
}
