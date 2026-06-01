import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';

/// Clock adapter backed by the device's local system time.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
