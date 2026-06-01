import 'package:flutter/services.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/permission_gateway.dart';

/// MethodChannel-backed Android permission gateway for alarm reliability settings.
final class AndroidPermissionGateway implements PermissionGateway {
  static const MethodChannel defaultChannel = MethodChannel(
    'com.kuroneko.alarm/scheduler',
  );

  final MethodChannel _channel;

  const AndroidPermissionGateway({MethodChannel channel = defaultChannel})
    : _channel = channel;

  @override
  Future<bool> hasExactAlarmPermission() async {
    return await _channel.invokeMethod<bool>('hasExactAlarmPermission') ??
        false;
  }

  @override
  Future<bool> requestExactAlarm() async {
    return await _channel.invokeMethod<bool>('requestExactAlarmPermission') ??
        false;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
        false;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }

  @override
  Future<bool> requestBatteryOptimization() async {
    return await _channel.invokeMethod<bool>(
          'requestBatteryOptimizationExemption',
        ) ??
        false;
  }

  @override
  Future<bool> hasFullScreenIntentPermission() async {
    return await _channel.invokeMethod<bool>('hasFullScreenIntentPermission') ??
        false;
  }

  @override
  Future<bool> requestFullScreenIntentPermission() async {
    return await _channel.invokeMethod<bool>(
          'requestFullScreenIntentPermission',
        ) ??
        false;
  }
}
