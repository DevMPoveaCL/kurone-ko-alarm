import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/services/alarm_event_label.dart';

void main() {
  group('AlarmEventLabel.title', () {
    test('maps startTime to Inicio Turno for main alarm', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.shiftStart,
        sourceFieldKey: 'startTime',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: Inicio Turno');
    });

    test('maps startTime to Inicio Turno for pre-warning', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.preWarning,
        toneProfile: ToneProfile.preBreak,
        purpose: AlarmEventPurpose.shiftStart,
        sourceFieldKey: 'startTime',
      );

      expect(AlarmEventLabel.title(event), 'Preaviso: Inicio Turno');
    });

    test('maps breakStart to 1° Break Inicio', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: 1° Break Inicio');
    });

    test('maps breakEnd to 1° Break Término', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakEnd,
        sourceFieldKey: 'breakEnd',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: 1° Break Término');
    });

    test('maps secondBreakStart to 2° Break Inicio', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'secondBreakStart',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: 2° Break Inicio');
    });

    test('maps secondBreakEnd to 2° Break Término', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakEnd,
        sourceFieldKey: 'secondBreakEnd',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: 2° Break Término');
    });

    test('maps lunchStart to Inicio Almuerzo', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.lunchStart,
        sourceFieldKey: 'lunchStart',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: Inicio Almuerzo');
    });

    test('maps extendedLunchEnd to Término Almuerzo Extendido', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.lunchExtensionEnd,
        sourceFieldKey: 'extendedLunchEnd',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: Término Almuerzo Extendido');
    });

    test('maps endTime to Fin Turno', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.shiftEnd,
        sourceFieldKey: 'endTime',
      );

      expect(AlarmEventLabel.title(event), 'Alarma: Fin Turno');
    });

    test('prefixes pre-warnings correctly for second break start', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.preWarning,
        toneProfile: ToneProfile.preBreak,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'secondBreakStart',
      );

      expect(AlarmEventLabel.title(event), 'Preaviso: 2° Break Inicio');
    });

    test('uses neutral Spanish without regionalisms', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.shiftStart,
        sourceFieldKey: 'startTime',
      );

      final title = AlarmEventLabel.title(event);
      expect(title, 'Alarma: Inicio Turno');
      expect(title, isNot(contains('Inicio de turno')));
    });

    test('does not generate artificial 3° ordinal for repeated days', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );

      expect(AlarmEventLabel.title(event), isNot(contains('3°')));
    });
  });

  group('AlarmEventLabel.breakOrdinalFor', () {
    test('assigns same ordinal to pre-warning and its main break alarm', () {
      final main = AlarmEvent(
        id: 'main-1',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 12, 30),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );
      final pre = main.preWarningFor();
      final planAlarms = [pre, main];

      expect(AlarmEventLabel.breakOrdinalFor(main, planAlarms), 1);
      expect(AlarmEventLabel.breakOrdinalFor(pre, planAlarms), 1);
    });

    test('assigns 1 to first break and 2 to second break main alarms', () {
      final break1Main = AlarmEvent(
        id: 'b1-main',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10, 0),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );
      final break1Pre = break1Main.preWarningFor();
      final break2Main = AlarmEvent(
        id: 'b2-main',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 14, 0),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'secondBreakStart',
      );
      final break2Pre = break2Main.preWarningFor();
      final planAlarms = [break1Pre, break1Main, break2Pre, break2Main];

      expect(AlarmEventLabel.breakOrdinalFor(break1Main, planAlarms), 1);
      expect(AlarmEventLabel.breakOrdinalFor(break1Pre, planAlarms), 1);
      expect(AlarmEventLabel.breakOrdinalFor(break2Main, planAlarms), 2);
      expect(AlarmEventLabel.breakOrdinalFor(break2Pre, planAlarms), 2);
    });

    test('does not produce inflated ordinals like 3, 4, 40 for repeated entries', () {
      final alarms = <AlarmEvent>[];
      for (var day = 1; day <= 20; day++) {
        for (var breakIdx = 1; breakIdx <= 2; breakIdx++) {
          final main = AlarmEvent(
            id: 'd${day}_b$breakIdx',
            planId: 'p',
            scheduledTime: DateTime.utc(2026, 6, day, 10 + breakIdx * 2, 0),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.breakStart,
            sourceFieldKey: breakIdx == 1 ? 'breakStart' : 'secondBreakStart',
          );
          alarms.add(main.preWarningFor());
          alarms.add(main);
        }
      }

      final preWarningOrdinals = alarms
          .where((a) => a.type == AlarmEventType.preWarning && a.purpose == AlarmEventPurpose.breakStart)
          .map((a) => AlarmEventLabel.breakOrdinalFor(a, alarms))
          .toList();
      expect(preWarningOrdinals.every((o) => o == 1 || o == 2), isTrue);

      final mainOrdinals = alarms
          .where((a) => a.type == AlarmEventType.main && a.purpose == AlarmEventPurpose.breakStart)
          .map((a) => AlarmEventLabel.breakOrdinalFor(a, alarms))
          .toList();
      expect(mainOrdinals.every((o) => o == 1 || o == 2), isTrue);

      expect(preWarningOrdinals, isNot(contains(3)));
      expect(mainOrdinals, isNot(contains(3)));
    });

    test('returns null for non-break purposes', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.shiftStart,
        sourceFieldKey: 'startTime',
      );

      expect(AlarmEventLabel.breakOrdinalFor(event, [event]), isNull);
    });

    test('breakEnd gets same ordinal as preceding breakStart', () {
      final breakStartMain = AlarmEvent(
        id: 'bs-main',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10, 0),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );
      final breakStartPre = breakStartMain.preWarningFor();
      final breakEndMain = AlarmEvent(
        id: 'be-main',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10, 15),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakEnd,
        sourceFieldKey: 'breakEnd',
      );
      final breakEndPre = breakEndMain.preWarningFor();
      final planAlarms = [breakStartPre, breakStartMain, breakEndPre, breakEndMain];

      expect(AlarmEventLabel.breakOrdinalFor(breakEndMain, planAlarms), 1);
      expect(AlarmEventLabel.breakOrdinalFor(breakEndPre, planAlarms), 1);
    });
  });

  group('AlarmEventLabel.body', () {
    test('returns contextual body for break start main alarm', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );

      expect(
        AlarmEventLabel.body(event),
        'El descanso empieza ahora.',
      );
    });

    test('returns contextual body for break start pre-warning', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.preWarning,
        toneProfile: ToneProfile.preBreak,
        purpose: AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
      );

      expect(
        AlarmEventLabel.body(event),
        'Prepara el inicio de tu descanso.',
      );
    });

    test('returns contextual body for lunch end main alarm', () {
      final event = AlarmEvent(
        id: 'a',
        planId: 'p',
        scheduledTime: DateTime.utc(2026, 6, 1, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.lunchEnd,
        sourceFieldKey: 'lunchEnd',
      );

      expect(
        AlarmEventLabel.body(event),
        'El almuerzo terminó. Vuelve a tus actividades.',
      );
    });
  });
}
