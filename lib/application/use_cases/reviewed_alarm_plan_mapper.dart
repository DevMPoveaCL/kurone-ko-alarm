import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';

/// Converts reviewed semantic schedule fields into concrete alarm events.
///
/// Product decision: shift boundaries and actionable break/lunch fields create
/// alarms. `lunchEnd` and `extendedLunchStart` remain review context only.
final class ReviewedAlarmPlanMapper {
  /// Fields that produce schedulable alarms and are editable in review UI.
  static const settableAlarmFieldLabels = <String, String>{
    'startTime': 'Hora inicio',
    'breakStart': 'Inicio descanso',
    'breakEnd': 'Término descanso',
    'lunchStart': 'Inicio almuerzo',
    'extendedLunchEnd': 'Término almuerzo extendido',
    'secondBreakStart': 'Inicio segundo descanso',
    'secondBreakEnd': 'Término segundo descanso',
    'endTime': 'Hora término',
  };

  /// Fields present in imports that must NOT appear as editable alarm fields.
  static const informationalOnlyFieldKeys = <String>{
    'date',
    'name',
    'lunchEnd',
    'extendedLunchStart',
  };

  /// Internal ordering used when building alarms. Must match exactly the keys
  /// of [settableAlarmFieldLabels] to keep scheduling and UI in sync.
  static const alarmTimeFieldKeys = [
    'startTime',
    'breakStart',
    'breakEnd',
    'lunchStart',
    'extendedLunchEnd',
    'secondBreakStart',
    'secondBreakEnd',
    'endTime',
  ];

  const ReviewedAlarmPlanMapper._();

  static AlarmPlan buildPlan(
    ScheduleDraft draft, {
    required DateTime createdAt,
    String? planId,
  }) {
    _throwIfAlarmTimesAreInvalid(draft);
    final resolvedPlanId = planId ?? 'plan_${draft.id}';
    return AlarmPlan(
      id: resolvedPlanId,
      scheduleId: draft.id,
      alarms: buildAlarms(draft, planId: resolvedPlanId),
      createdAt: createdAt,
    );
  }

  static List<AlarmEvent> buildAlarms(
    ScheduleDraft draft, {
    required String planId,
  }) {
    return _withPreWarnings(buildMainAlarms(draft, planId: planId));
  }

  static List<AlarmEvent> buildMainAlarms(
    ScheduleDraft draft, {
    required String planId,
  }) {
    _throwIfAlarmTimesAreInvalid(draft);
    _throwIfDateIsMissingForAlarmTimes(draft);

    final alarmsByDateTime = <String, AlarmEvent>{};
    for (final entry in draft.entries) {
      final date = _parseDate(entry.fields['date']);
      if (date == null) {
        continue;
      }

      for (final key in alarmTimeFieldKeys) {
        final time = _parseTime(entry.fields[key]);
        if (time == null) {
          continue;
        }
        final scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.$1,
          time.$2,
        );
        final signature = scheduledTime.toIso8601String();
        alarmsByDateTime.putIfAbsent(
          signature,
          () => AlarmEvent(
            id: '${planId}_${_dateIdPart(scheduledTime)}',
            planId: planId,
            scheduledTime: scheduledTime,
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: _purposeForFieldKey(key),
            sourceFieldKey: key,
          ),
        );
      }
    }

    final alarms = alarmsByDateTime.values.toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return alarms;
  }

  static bool hasMissingRequiredDates(ScheduleDraft draft) {
    return draft.entries.any((entry) {
      final hasAlarmTime = alarmTimeFieldKeys.any(
        (key) => _parseTime(entry.fields[key]) != null,
      );
      if (!hasAlarmTime) {
        return false;
      }
      return _parseDate(entry.fields['date']) == null;
    });
  }

  static bool hasInvalidAlarmTimes(ScheduleDraft draft) {
    return draft.entries.any(
      (entry) => alarmTimeFieldKeys.any((key) {
        final value = entry.fields[key]?.trim();
        return value != null && value.isNotEmpty && _parseTime(value) == null;
      }),
    );
  }

  static List<AlarmEvent> _withPreWarnings(List<AlarmEvent> mainAlarms) {
    final alarms = <AlarmEvent>[];
    for (final main in mainAlarms) {
      alarms.add(main.preWarningFor());
      alarms.add(main);
    }
    alarms.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return alarms;
  }

  static void _throwIfDateIsMissingForAlarmTimes(ScheduleDraft draft) {
    if (!hasMissingRequiredDates(draft)) {
      return;
    }
    throw StateError(
      'A reviewed schedule date is required before confirming alarms. '
      'Edit the date field instead of using the import date.',
    );
  }

  static void _throwIfAlarmTimesAreInvalid(ScheduleDraft draft) {
    if (!hasInvalidAlarmTimes(draft)) {
      return;
    }
    throw const ScheduleValidationFailure(
      message:
          'Usa horarios en formato de 24 horas (HH:mm). No uses AM/PM; actualiza la hora antes de confirmar.',
    );
  }

  static DateTime? _parseDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'^(\d{1,2})[-/]([A-Za-zÁÉÍÓÚáéíóú0-9]+)[-/](\d{4})$',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final day = int.tryParse(match.group(1)!);
    final month = _parseMonth(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static int? _parseMonth(String value) {
    final numeric = int.tryParse(value);
    if (numeric != null && numeric >= 1 && numeric <= 12) {
      return numeric;
    }
    final normalized = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return const {
      'enero': 1,
      'ene': 1,
      'febrero': 2,
      'feb': 2,
      'marzo': 3,
      'mar': 3,
      'abril': 4,
      'abr': 4,
      'mayo': 5,
      'may': 5,
      'junio': 6,
      'jun': 6,
      'julio': 7,
      'jul': 7,
      'agosto': 8,
      'ago': 8,
      'septiembre': 9,
      'setiembre': 9,
      'sep': 9,
      'set': 9,
      'octubre': 10,
      'oct': 10,
      'noviembre': 11,
      'nov': 11,
      'diciembre': 12,
      'dic': 12,
    }[normalized];
  }

  static (int, int)? _parseTime(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(':');
    if (parts.length != 2 && parts.length != 3) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = parts.length == 3 ? int.tryParse(parts[2]) : 0;
    if (hour == null || minute == null || second == null) {
      return null;
    }
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        second < 0 ||
        second > 59) {
      return null;
    }
    return (hour, minute);
  }

  static AlarmEventPurpose _purposeForFieldKey(String key) {
    return switch (key) {
      'startTime' => AlarmEventPurpose.shiftStart,
      'breakStart' || 'secondBreakStart' => AlarmEventPurpose.breakStart,
      'breakEnd' || 'secondBreakEnd' => AlarmEventPurpose.breakEnd,
      'lunchStart' => AlarmEventPurpose.lunchStart,
      'extendedLunchEnd' => AlarmEventPurpose.lunchExtensionEnd,
      'endTime' => AlarmEventPurpose.shiftEnd,
      _ => AlarmEventPurpose.breakStart,
    };
  }

  static String _dateIdPart(DateTime dateTime) {
    return '${dateTime.year}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}_'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
