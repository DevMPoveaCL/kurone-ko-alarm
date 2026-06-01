# Full-Screen Alarm Overlay Specification

## Purpose
Ensure main alarms present a full-screen stop UI on Android, with graceful degradation when the `USE_FULL_SCREEN_INTENT` runtime permission is unavailable.

## Requirements

### Requirement: Permission Check
The system MUST check `USE_FULL_SCREEN_INTENT` permission status on Android 14+ before attempting a full-screen alarm.

#### Scenario: Permission Granted
- GIVEN the device runs Android 14+
- AND `USE_FULL_SCREEN_INTENT` is granted
- WHEN a main alarm fires
- THEN the full-screen `AlarmRingingActivity` is launched with the contextual title and a stop button

#### Scenario: Permission Denied
- GIVEN the device runs Android 14+
- AND `USE_FULL_SCREEN_INTENT` is denied
- WHEN a main alarm fires
- THEN a high-priority heads-up notification is shown instead of the full-screen Activity

### Requirement: Stop UI
The system MUST provide a stop control on the full-screen overlay that terminates the alarm sound and vibration.

#### Scenario: User Stops Alarm
- GIVEN the full-screen overlay is visible and the alarm is sounding
- WHEN the user presses the stop button
- THEN the sound and vibration stop
- AND the overlay closes
- AND the alarm event status is recorded as dismissed

### Requirement: Fallback Notification
When full-screen intent is denied, the fallback notification MUST use the `break_alarms` channel with high importance and include the alarm's contextual label.

#### Scenario: Fallback Shown
- GIVEN full-screen permission is denied
- WHEN a main alarm fires
- THEN the heads-up notification displays the contextual alarm title
- AND tapping the notification opens the stop UI
