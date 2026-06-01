/// Type of break period within a work day.
enum BreakType { lunch, short }

/// Represents a break period within a work day.
final class BreakPeriod {
  final String id;
  final String workDayId;
  final DateTime startTime;
  final DateTime endTime;
  final BreakType type;

  const BreakPeriod({
    required this.id,
    required this.workDayId,
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  BreakPeriod copyWith({
    String? id,
    String? workDayId,
    DateTime? startTime,
    DateTime? endTime,
    BreakType? type,
  }) {
    return BreakPeriod(
      id: id ?? this.id,
      workDayId: workDayId ?? this.workDayId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BreakPeriod &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workDayId == other.workDayId &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          type == other.type;

  @override
  int get hashCode => Object.hash(id, workDayId, startTime, endTime, type);

  @override
  String toString() =>
      'BreakPeriod(id: $id, workDayId: $workDayId, startTime: $startTime, '
      'endTime: $endTime, type: $type)';
}
