/// Outbound port for requesting platform permissions.
abstract class PermissionGateway {
  /// Requests the Android exact alarm permission.
  Future<bool> requestExactAlarm();

  /// Requests battery optimization exemption.
  Future<bool> requestBatteryOptimization();

  /// Checks whether exact alarm permission is granted.
  Future<bool> hasExactAlarmPermission();

  /// Checks whether alarm notifications can be posted.
  Future<bool> hasNotificationPermission();

  /// Requests notification permission or opens the platform notification settings.
  Future<bool> requestNotificationPermission();

  /// Checks whether full-screen intent permission is granted (Android 14+).
  Future<bool> hasFullScreenIntentPermission();

  /// Requests full-screen intent permission or opens the relevant settings.
  Future<bool> requestFullScreenIntentPermission();
}
