import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';

/// Pure domain service that produces contextual alarm labels in neutral Spanish.
final class AlarmEventLabel {
  const AlarmEventLabel._();

  /// Returns the title for an [event] using its [sourceFieldKey].
  static String title(AlarmEvent event) {
    final prefix = switch (event.type) {
      AlarmEventType.preWarning => 'Preaviso:',
      AlarmEventType.main => 'Alarma:',
    };

    final label = switch (event.sourceFieldKey) {
      'startTime' => 'Inicio Turno',
      'breakStart' => '1° Break Inicio',
      'breakEnd' => '1° Break Término',
      'lunchStart' => 'Inicio Almuerzo',
      'extendedLunchEnd' => 'Término Almuerzo Extendido',
      'secondBreakStart' => '2° Break Inicio',
      'secondBreakEnd' => '2° Break Término',
      'endTime' => 'Fin Turno',
      _ => _fallbackPurposeLabel(event.purpose),
    };

    return '$prefix $label';
  }

  static String _fallbackPurposeLabel(AlarmEventPurpose purpose) {
    return switch (purpose) {
      AlarmEventPurpose.shiftStart => 'Inicio Turno',
      AlarmEventPurpose.breakStart => 'Break Inicio',
      AlarmEventPurpose.breakEnd => 'Break Término',
      AlarmEventPurpose.lunchStart => 'Inicio Almuerzo',
      AlarmEventPurpose.lunchEnd => 'Término Almuerzo',
      AlarmEventPurpose.lunchExtensionEnd => 'Término Almuerzo Extendido',
      AlarmEventPurpose.shiftEnd => 'Fin Turno',
    };
  }

  /// Computes the break ordinal (1-based) for a break-related [event]
  /// within its plan's alarm list [planAlarms].
  /// Returns `null` for non-break purposes.
  ///
  /// Ordinals are per-day: the first break of a day is 1°, the second is 2°,
  /// regardless of how many days are in the plan.
  static int? breakOrdinalFor(AlarmEvent event, List<AlarmEvent> planAlarms) {
    if (event.purpose != AlarmEventPurpose.breakStart &&
        event.purpose != AlarmEventPurpose.breakEnd) {
      return null;
    }

    // Ordinals are defined by main alarms only; pre-warnings share the
    // ordinal of the main alarm they precede.
    final sortedMains = planAlarms
        .where(
          (a) =>
              a.type == AlarmEventType.main &&
              (a.purpose == AlarmEventPurpose.breakStart ||
                  a.purpose == AlarmEventPurpose.breakEnd),
        )
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    AlarmEvent targetMain;
    if (event.type == AlarmEventType.main) {
      targetMain = event;
    } else {
      // Find the corresponding main alarm: exactly 1 minute later,
      // same purpose, same plan. Returns null if none found.
      final candidate = planAlarms
          .where(
            (a) =>
                a.type == AlarmEventType.main &&
                a.purpose == event.purpose &&
                a.scheduledTime.isAtSameMomentAs(
                  event.scheduledTime.add(const Duration(minutes: 1)),
                ),
          )
          .firstOrNull;
      if (candidate == null) return null;
      targetMain = candidate;
    }

    // Count only within the same calendar day.
    final targetDate = _dateKey(targetMain.scheduledTime);
    var ordinal = 0;
    for (final alarm in sortedMains) {
      if (_dateKey(alarm.scheduledTime) != targetDate) continue;
      if (alarm.purpose == AlarmEventPurpose.breakStart) {
        ordinal++;
      }
      if (alarm.id == targetMain.id) {
        return ordinal;
      }
    }
    return null;
  }

  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Returns the body (subtitle) for an [event].
  static String body(AlarmEvent event) {
    return switch ((event.type, event.purpose)) {
      (AlarmEventType.preWarning, AlarmEventPurpose.shiftStart) =>
        'Prepara el inicio de tu turno.',
      (AlarmEventType.main, AlarmEventPurpose.shiftStart) =>
        'Tu turno empieza ahora.',
      (AlarmEventType.preWarning, AlarmEventPurpose.breakStart) =>
        'Prepara el inicio de tu descanso.',
      (AlarmEventType.main, AlarmEventPurpose.breakStart) =>
        'El descanso empieza ahora.',
      (AlarmEventType.preWarning, AlarmEventPurpose.breakEnd) =>
        'Prepara el regreso a tus actividades.',
      (AlarmEventType.main, AlarmEventPurpose.breakEnd) =>
        'El descanso terminó. Vuelve a tus actividades.',
      (AlarmEventType.preWarning, AlarmEventPurpose.lunchStart) =>
        'Prepara el inicio de tu almuerzo.',
      (AlarmEventType.main, AlarmEventPurpose.lunchStart) =>
        'El almuerzo empieza ahora.',
      (AlarmEventType.preWarning, AlarmEventPurpose.lunchEnd) =>
        'Prepara el regreso a tus actividades.',
      (AlarmEventType.main, AlarmEventPurpose.lunchEnd) =>
        'El almuerzo terminó. Vuelve a tus actividades.',
      (AlarmEventType.preWarning, AlarmEventPurpose.lunchExtensionEnd) =>
        'Prepara el regreso a tus actividades.',
      (AlarmEventType.main, AlarmEventPurpose.lunchExtensionEnd) =>
        'El almuerzo extendido terminó. Vuelve a tus actividades.',
      (AlarmEventType.preWarning, AlarmEventPurpose.shiftEnd) =>
        'Prepara el cierre de tu turno.',
      (AlarmEventType.main, AlarmEventPurpose.shiftEnd) =>
        'Tu turno terminó.',
    };
  }
}
