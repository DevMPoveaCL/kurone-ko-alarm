/// Time-of-day value object with hour and minute only.
final class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  TimeOfDay.of(DateTime dt) : hour = dt.hour, minute = dt.minute;

  const TimeOfDay.morning() : hour = 8, minute = 0;

  const TimeOfDay.afternoon() : hour = 14, minute = 0;

  Duration difference(TimeOfDay other) {
    return Duration(hours: hour - other.hour, minutes: minute - other.minute);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeOfDay &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
