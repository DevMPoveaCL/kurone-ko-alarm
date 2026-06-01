/// Type of alarm event.
enum AlarmEventType { main, preWarning }

/// Tone profile identifier for notification customization.
enum ToneProfile { breakStart, preBreak }

/// Semantic purpose of an alarm event.
enum AlarmEventPurpose {
  shiftStart,
  breakStart,
  breakEnd,
  lunchStart,
  lunchEnd,
  lunchExtensionEnd,
  shiftEnd,
}

/// Lifecycle status of an alarm event.
enum AlarmEventStatus { scheduled, fired, dismissed, missed }

/// A single scheduled alarm event within an AlarmPlan.
final class AlarmEvent {
  final String id;
  final String planId;
  final DateTime scheduledTime;
  final AlarmEventType type;
  final ToneProfile toneProfile;
  final AlarmEventPurpose purpose;

  /// Stable semantic field key from the source schedule (e.g. 'breakStart', 'secondBreakStart').
  final String sourceFieldKey;

  final bool enabled;

  /// Android alarm ID assigned by the native scheduler.
  final int? androidAlarmId;

  /// Lifecycle status of this alarm event.
  final AlarmEventStatus status;

  /// When the status last changed.
  final DateTime? statusChangedAt;

  const AlarmEvent({
    required this.id,
    required this.planId,
    required this.scheduledTime,
    required this.type,
    required this.toneProfile,
    this.purpose = AlarmEventPurpose.breakStart,
    this.sourceFieldKey = '',
    this.enabled = true,
    this.androidAlarmId,
    this.status = AlarmEventStatus.scheduled,
    this.statusChangedAt,
  });

  /// Returns the pre-warning alarm that should precede this main alarm by 1 minute.
  AlarmEvent preWarningFor() {
    if (type != AlarmEventType.main) {
      throw StateError('preWarningFor is only valid for main alarms');
    }
    return AlarmEvent(
      id: '${id}_pre',
      planId: planId,
      scheduledTime: scheduledTime.subtract(const Duration(minutes: 1)),
      type: AlarmEventType.preWarning,
      toneProfile: ToneProfile.preBreak,
      purpose: purpose,
      sourceFieldKey: sourceFieldKey,
      enabled: enabled,
      status: status,
      statusChangedAt: statusChangedAt,
    );
  }

  AlarmEvent copyWith({
    String? id,
    String? planId,
    DateTime? scheduledTime,
    AlarmEventType? type,
    ToneProfile? toneProfile,
    AlarmEventPurpose? purpose,
    String? sourceFieldKey,
    bool? enabled,
    int? androidAlarmId,
    AlarmEventStatus? status,
    DateTime? statusChangedAt,
  }) {
    return AlarmEvent(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      type: type ?? this.type,
      toneProfile: toneProfile ?? this.toneProfile,
      purpose: purpose ?? this.purpose,
      sourceFieldKey: sourceFieldKey ?? this.sourceFieldKey,
      enabled: enabled ?? this.enabled,
      androidAlarmId: androidAlarmId ?? this.androidAlarmId,
      status: status ?? this.status,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          planId == other.planId &&
          scheduledTime == other.scheduledTime &&
          type == other.type &&
          toneProfile == other.toneProfile &&
          purpose == other.purpose &&
          sourceFieldKey == other.sourceFieldKey &&
          enabled == other.enabled &&
          androidAlarmId == other.androidAlarmId &&
          status == other.status &&
          statusChangedAt == other.statusChangedAt;

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    scheduledTime,
    type,
    toneProfile,
    purpose,
    sourceFieldKey,
    enabled,
    androidAlarmId,
    status,
    statusChangedAt,
  );

  @override
  String toString() =>
      'AlarmEvent(id: $id, planId: $planId, scheduledTime: $scheduledTime, '
      'type: $type, toneProfile: $toneProfile, purpose: $purpose, sourceFieldKey: $sourceFieldKey, '
      'enabled: $enabled, androidAlarmId: $androidAlarmId, status: $status, statusChangedAt: $statusChangedAt)';
}
