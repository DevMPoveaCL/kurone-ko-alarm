import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/services/alarm_event_label.dart';

/// MethodChannel-backed Android alarm scheduler adapter.
final class NativeAlarmScheduler implements AlarmScheduler {
  static const MethodChannel defaultChannel = MethodChannel(
    'com.kuroneko.alarm/scheduler',
  );

  final MethodChannel _channel;
  final Future<bool> Function() _hasFullScreenIntentPermission;

  const NativeAlarmScheduler({
    MethodChannel channel = defaultChannel,
    Future<bool> Function()? hasFullScreenIntentPermission,
  }) : _channel = channel,
       _hasFullScreenIntentPermission = hasFullScreenIntentPermission ?? _alwaysGranted;

  static Future<bool> _alwaysGranted() async => true;

  /// Generates a stable positive Android request code for events not yet persisted
  /// with a native alarm id.
  static int computeNativeId(AlarmEvent event) {
    if (event.androidAlarmId != null) {
      return event.androidAlarmId!;
    }

    var hash = 0x811c9dc5;
    for (final unit in event.id.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  @override
  int nativeIdFor(AlarmEvent event) => computeNativeId(event);

  @override
  Future<int> schedule(AlarmEvent event) async => _schedule(event);

  Future<int> _schedule(AlarmEvent event, {int? breakOrdinal}) async {
    final nativeId = computeNativeId(event);
    final showFullScreen = event.type == AlarmEventType.main &&
        await _hasFullScreenIntentPermission();
    final prewarningId = event.type == AlarmEventType.main
        ? computeNativeId(event.preWarningFor())
        : null;
    try {
      final payload = <String, Object?>{
        'id': nativeId,
        'millis': event.scheduledTime.millisecondsSinceEpoch,
        'channelId': _channelIdFor(event),
        'eventType': _eventTypeFor(event),
        'scheduleMode': _scheduleModeFor(event),
        'title': AlarmEventLabel.title(event),
        'body': AlarmEventLabel.body(event),
        'purpose': event.purpose.name,
        'breakOrdinal': breakOrdinal,
        'ringUntilDismissed': _ringUntilDismissedFor(event),
        'autoStopMillis': _autoStopMillisFor(event),
        'showFullScreenAlarm': showFullScreen,
        'dismissAction': 'com.kuroneko.kurone_ko_alarm.DISMISS_ALARM',
      };
      if (prewarningId != null) {
        payload['prewarningId'] = prewarningId;
      }
      final result = await _channel.invokeMethod<int>('scheduleAlarm', payload);
      return result ?? nativeId;
    } on PlatformException catch (error) {
      throw SchedulingFailure(message: error.message ?? error.code);
    }
  }

  @override
  Future<void> cancel(int nativeAlarmId) async {
    try {
      await _channel.invokeMethod<void>('cancelAlarm', {'id': nativeAlarmId});
    } on PlatformException catch (error) {
      throw SchedulingFailure(message: error.message ?? error.code);
    }
  }

  @override
  Future<void> pruneNativeStaleAlarms(DateTime now) async {
    try {
      await _channel.invokeMethod<void>('pruneStaleAlarms', {
        'nowMillis': now.millisecondsSinceEpoch,
      });
    } on PlatformException catch (error) {
      throw SchedulingFailure(message: error.message ?? error.code);
    }
  }

  @override
  Future<void> rescheduleAll(List<AlarmEvent> events) async {
    final planAlarms = events.toList();
    for (final event in events.where((event) => event.enabled)) {
      final ordinal = AlarmEventLabel.breakOrdinalFor(event, planAlarms);
      await _schedule(event, breakOrdinal: ordinal);
    }
  }

  @override
  Future<List<Map<String, Object?>>> syncAlarmOutcomes() async {
    try {
      final result = await _channel.invokeMethod<String>('syncAlarmOutcomes');
      if (result == null || result.isEmpty || result == '[]') return [];
      final decoded = jsonDecode(result) as List<dynamic>;
      return decoded.cast<Map<String, Object?>>();
    } on PlatformException catch (error) {
      throw SchedulingFailure(message: error.message ?? error.code);
    }
  }

  /// Asks the native Android side to reschedule its persisted alarm mirror.
  ///
  /// This is mainly a testable MethodChannel seam for the boot-recovery bridge;
  /// Android's [BootCompletedReceiver] invokes the same native operation after
  /// `BOOT_COMPLETED` without requiring Flutter UI presentation code.
  Future<void> rescheduleAllOnBoot() async {
    try {
      await _channel.invokeMethod<void>('rescheduleAllOnBoot');
    } on PlatformException catch (error) {
      throw SchedulingFailure(message: error.message ?? error.code);
    }
  }

  static String _channelIdFor(AlarmEvent event) {
    return event.type == AlarmEventType.preWarning
        ? 'pre_break_warnings'
        : 'break_alarms';
  }

  static String _eventTypeFor(AlarmEvent event) {
    return event.type == AlarmEventType.preWarning ? 'preWarning' : 'main';
  }

  static String _scheduleModeFor(AlarmEvent event) {
    return event.type == AlarmEventType.main
        ? 'alarmClock'
        : 'exactNotification';
  }

  static bool _ringUntilDismissedFor(AlarmEvent event) {
    return event.type == AlarmEventType.main;
  }

  static int _autoStopMillisFor(AlarmEvent event) {
    return event.type == AlarmEventType.main ? 5 * 60 * 1000 : 0;
  }
}
