/// Represents a single work day with start and end times.
final class WorkDay {
  final String id;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;

  const WorkDay({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  WorkDay copyWith({
    String? id,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return WorkDay(
      id: id ?? this.id,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkDay &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => Object.hash(id, date, startTime, endTime);

  @override
  String toString() =>
      'WorkDay(id: $id, date: $date, startTime: $startTime, endTime: $endTime)';
}
