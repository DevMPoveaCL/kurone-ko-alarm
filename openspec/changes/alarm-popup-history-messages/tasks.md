# Tasks: Alarm Popup, History & Contextual Messages

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~500–550 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single changeset — exception-ok |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Medium

## Phase 1: Foundation — Domain Entity, Schema Migration & Label Service

- [x] 1.1 RED: Unit test `AlarmEventLabel.title/body` for all `AlarmEventPurpose` values with/without break ordinals — expect neutral Spanish, no slang
- [x] 1.2 GREEN: Create `lib/domain/services/alarm_event_label.dart` — pure `title(AlarmEvent, {int? breakOrdinal})` and `body(AlarmEvent)`
- [x] 1.3 RED: Unit test Drift schema 1→2 migration — assert `status='scheduled'` and `statusChangedAt=NULL` defaults on existing rows
- [x] 1.4 GREEN: Add `AlarmEventStatus` enum + `status`/`statusChangedAt` fields to `AlarmEvent` in `lib/domain/entities/alarm_event.dart`
- [x] 1.5 GREEN: Implement schema 2 `onUpgrade` migration in `lib/infrastructure/adapters/persistence/database.dart`
- [x] 1.6 RED/GREEN: Add `hasFullScreenIntentPermission`/`requestFullScreenIntentPermission` to `PermissionGateway` port; test contract

## Phase 2: Full-Screen Overlay Permission & Stop UI

- [x] 2.1 RED: Unit test `AndroidPermissionGateway` full-screen methods — mock MethodChannel, assert correct args
- [x] 2.2 GREEN: Implement full-screen methods in `lib/infrastructure/adapters/permissions/android_permission_gateway.dart`
- [x] 2.3 GREEN: Add `USE_FULL_SCREEN_INTENT` check/request in `android/.../MainActivity.kt` on API 34+
- [x] 2.4 GREEN: Wire permission check into `NativeAlarmScheduler` — set `showFullScreenAlarm: false` when denied at schedule time
- [x] 2.5 GREEN: Standardize stop UI in `AlarmRingingActivity.kt` — accept label via intent extras, remove hardcoded fallback strings

## Phase 3: Alarm History — Status Lifecycle & 24h Retention

- [x] 3.1 GREEN: Add `updateAlarmStatus`, `getAlarmHistory`, `purgeHistoryOlderThan` to `LocalRepository` port
- [x] 3.2 RED: Unit test `DriftLocalRepository` — history excludes `scheduled`, status update sets timestamp, purge removes >24h
- [x] 3.3 GREEN: Implement history query, status update, 24h purge in `lib/infrastructure/adapters/persistence/drift_local_repository.dart`
- [x] 3.4 GREEN: Add `syncAlarmOutcomes` handler in `AlarmSchedulerAdapter.kt` — read dismissal JSON log from SharedPreferences
- [x] 3.5 GREEN: Wire `syncAlarmOutcomes` + `purgeHistoryOlderThan(24h)` into `ImportFlowController.loadActiveAlarms()`

## Phase 4: Contextual Labels on All Surfaces

- [x] 4.1 GREEN: Replace `_titleFor`/`_bodyFor` in `NativeAlarmScheduler` with `AlarmEventLabel` calls; compute break ordinals in `rescheduleAll`
- [x] 4.2 GREEN: Update `AlarmSchedulerAdapter.kt` — persist `purpose` and ordinal index in SharedPreferences
- [x] 4.3 GREEN: Update `AlarmRingingIntentFactory.kt` — relay label and `purpose` through intent extras
- [x] 4.4 RED: Widget test `AlarmTimeline` — assert contextual labels rendered per alarm; history section shows terminal-status entries
- [x] 4.5 GREEN: Update `lib/presentation/widgets/alarm_timeline.dart` — use `AlarmEventLabel.title` per-alarm; add history section

## Phase 5: Verification

- [x] 5.1 Run full unit suite across all test files created — label, migration, repository, gateway, scheduler, widget
- [x] 5.2 Walk all spec scenarios: full-screen grant/deny, dismissal lifecycle, label consistency, 24h purge, scheduled exclusion
- [x] 5.3 Manual E2E on Android 14+ device: permission granted → overlay appears; denied → heads-up notification; stop → dismissal recorded

## Post-Implementation Bugfix (2026-06-01)

- [x] Fix: `breakOrdinalFor` counted pre-warnings as separate breaks, inflating ordinals globally (e.g. `2°`, `3°`, `40°`). Fixed by computing ordinals per-day and assigning pre-warnings the same ordinal as their corresponding main alarm.
- [x] Fix: Label format changed from `Preaviso de ...` / `Alarma ...` to `Preaviso: ...` / `Alarma: ...` with cleaner semantic names (`Inicio Turno`, `Fin Turno`, `Término Almuerzo`, etc.).
- [x] Fix: `AlarmTimeline` history section was invisible (buried after all upcoming alarms) and had no empty state. Refactored to show `Historial` BEFORE upcoming alarms, with empty state `No hay alarmas en el historial.`.
- [x] Fix: Upcoming alarms now grouped by day in expandable `ExpansionTile` sections, nearest day expanded by default. Prevents long ungrouped scroll for >100 alarms.
- [x] Tests: Added/updated 17 unit tests and 5 widget tests covering label format, ordinal behavior, day grouping, history visibility, and empty state.

## Post-Implementation Bugfix — Full-Screen Popup Not Working (2026-06-01)

- [x] Triage: `AlarmReceiver.kt` directly called `context.startActivity()` from `BroadcastReceiver.onReceive()`, which is blocked on modern Android (API 29+) when the app is not in the foreground. Removed direct activity start; the `AlarmRingingService` foreground notification with `setFullScreenIntent` is the correct and only path.
- [x] Triage: `break_alarms` notification channel used `IMPORTANCE_HIGH`. Changed to `IMPORTANCE_MAX` to maximize heads-up/full-screen reliability.
- [x] Triage: On Android 14+ (API 34), `requestFullScreenIntentPermission()` opened generic notification settings (`ACTION_APP_NOTIFICATION_SETTINGS`). Updated to open the dedicated full-screen intent settings page (`ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`).
- [x] Triage: `ReviewAndConfirmUseCase` silently disabled full-screen alarms by setting `showFullScreenAlarm: false` when permission was denied, without ever requesting it. Added `hasFullScreenIntentPermission` check and `requestFullScreenIntentPermission` call to `_ensureSchedulingPermissions()`, throwing `PermissionDenied(permission: 'fullScreenIntent')` if the user declines.
- [x] Tests: Added 2 new unit tests in `test/application/application_use_cases_test.dart` covering full-screen intent permission denied and granted during confirm flow. Updated `_FakePermissionGateway` to track full-screen intent checks/requests.
- [x] Verification: Full Dart suite 181 tests passing. `flutter analyze` clean. Debug APK built successfully.

## Post-Implementation Bugfix — Dismissed Alarms in Upcoming, Sound Reliability, Per-Alarm Edit UX (2026-06-01)

- [x] Triage A: `getAllEnabledEvents()` only filtered by `enabled=true`, not by `status='scheduled'`. `updateAlarmStatus()` did not set `enabled=false` for dismissed/fired/missed. Result: dismissed alarms stayed enabled and continued to appear in upcoming list.
- [x] Fix A: `getAllEnabledEvents()` now filters by both `enabled=true` AND `status='scheduled'`. `updateAlarmStatus()` sets `enabled=false` for any non-scheduled status.
- [x] Triage B: `AlarmRingingService.startAlarmSound()` returned early when `mediaPlayer?.isPlaying == true`. If the service was reused for a new main alarm while still ringing from a previous one, the new alarm showed overlay/notification but produced no sound.
- [x] Fix B: `startAlarmSound()` now stops and releases any existing `MediaPlayer` before creating and starting a new one, ensuring every main alarm restarts sound reliably.
- [x] Triage C: No per-alarm edit state existed. The only edit flow (`enterEditMode`) reopened the entire Excel review list. No `Editar` action existed on individual alarm rows.
- [x] Fix C: Added `updateAlarmEvent` to `LocalRepository` port and `DriftLocalRepository`. Added `editAlarmTime` to `ImportFlowController` — updates one alarm time, shifts paired prewarning by 1 minute, cancels/reschedules native alarms. Added `Editar` button to active `_TimelineRow`. Wired `showTimePicker` dialog in `import_screen.dart`.
- [x] Tests: Added 6 new tests covering dismissed exclusion, status→disable, repository update, controller edit isolation, widget `Editar` visibility, and callback invocation. Full suite: 203 tests passing.
- [x] Verification: `flutter analyze` clean (3 pre-existing INFO-level lints). Debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.

## Post-Implementation Bugfix — Obsolete Buttons, Duplicate Blocks, Real-Time Sync Lag, Transient Feedback (2026-06-01)

- [x] Triage A: Global `Editar alarmas` rendered in `_ConfirmedCard` (line 383–387) and `_AlarmListCard` (line 462–476). `Ocultar todas` rendered in `_AlarmListCard`. Both obsolete because per-row `Editar` now exists.
- [x] Fix A: Removed `_ConfirmedCard` entirely from `ImportScreen`. Removed global `Editar alarmas` and `Ocultar todas` buttons from `_AlarmListCard`. Kept per-row `Editar` in `_TimelineRow`.
- [x] Triage B: Duplicate `AlarmTimeline` blocks produced because `_ConfirmedCard` rendered its own timeline (line 377–381) in addition to `_AlarmListCard`'s timeline (line 452–456) when status was `confirmed`.
- [x] Fix B: Removed `_ConfirmedCard` conditional rendering. After confirm, only `_AlarmListCard` (the authoritative active block) is shown, with a transient `_FeedbackBanner` instead of a second persistent timeline.
- [x] Triage C: `_activeAlarmRefreshInterval` was 45 seconds. Past/dismissed alarms could remain in upcoming for up to 45s before `loadActiveAlarms()` pruned them.
- [x] Fix C: Reduced interval to 5 seconds. `loadActiveAlarms()` already syncs native outcomes, prunes stale events, and reloads active/history on every tick.
- [x] Triage D: No transient success/error feedback existed after confirm/import. `_ConfirmedCard` showed persistent duplicate content instead.
- [x] Fix D: Added `feedbackMessage` + `feedbackSuccess` to `ImportFlowState`. Controller `_setFeedback` shows success message `Cargado con éxito en alarmas activas` (green check) or error message (red icon) for 3 seconds via `_FeedbackClearTimer`. `_AlarmListCard` renders `_FeedbackBanner` conditionally.
- [x] Triage E: `AlarmTimeline` did not auto-expand nearest day when `alarms` populated after initial mount (empty → non-empty), leaving upcoming rows collapsed after async load.
- [x] Fix E: Added `didUpdateWidget` to `AlarmTimeline` that expands the nearest future day when `oldWidget.alarms.isEmpty && widget.alarms.isNotEmpty`.
- [x] Tests: Added/updated 7 tests covering no-global-buttons, single-authoritative-block, transient-success, 5s-interval, auto-prune-to-history, feedback-banner, and didUpdateWidget expansion. Full suite: 207 tests passing.
- [x] Verification: `flutter analyze` clean (3 pre-existing INFO-level lints). Debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
