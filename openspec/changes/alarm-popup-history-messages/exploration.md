# Exploration: alarm-popup-history-messages

## Current State

### 1. Full-Screen Alarm Overlay (Pop-up)

The Android native side **already has full-screen alarm infrastructure**:

- **`AlarmRingingActivity`** (`android/.../AlarmRingingActivity.kt`): A native Activity with `showOnLockScreen=true`, `turnScreenOn=true`, `FLAG_SHOW_WHEN_LOCKED`, `FLAG_TURN_SCREEN_ON`, `FLAG_KEEP_SCREEN_ON`, `FLAG_DISMISS_KEYGUARD`. It shows a dark overlay with alarm title, body, and a "Detener alarma" button.
- **`AlarmRingingService`** (`android/.../AlarmRingingService.kt`): Foreground service with `mediaPlayback` type. Plays alarm sound, vibrates, acquires WakeLock, and posts an `ongoing` notification with `fullScreenIntent` for main alarms.
- **`AlarmReceiver`** (`android/.../AlarmReceiver.kt`): On alarm fire, calls `startForegroundService` then `startActivity(AlarmRingingIntentFactory.createFrom(context, intent))` if `showFullScreenAlarm` is true.
- **Manifest declares** `USE_FULL_SCREEN_INTENT` permission.
- **Flutter-side** (`NativeAlarmScheduler._showFullScreenAlarmFor`): Returns `true` for `AlarmEventType.main`, `false` for `AlarmEventType.preWarning`. So main alarms SHOULD show the full-screen overlay.

**Why overlays may not appear consistently:**

1. **Android 14+ `USE_FULL_SCREEN_INTENT` runtime permission**: Starting with Android 14 (API 34), `USE_FULL_SCREEN_INTENT` is no longer auto-granted to all apps — only to apps with `ROLE_CALL_REDIRECTION` or those that declare `android.permission.USE_FULL_SCREEN_INTENT` AND are approved by the system. The manifest declares it, but the app never **checks or requests** the runtime permission status. The `PermissionGateway` interface and `AndroidPermissionGateway` adapter have **no method** for `USE_FULL_SCREEN_INTENT`.
2. **`AlarmManager` exact alarm restrictions on Android 12+**: If `canScheduleExactAlarms()` returns false, the `setAlarmClock` path degrades to `setExactAndAllowWhileIdle` — the alarm can be delayed, which means the Activity won't fire at the exact scheduled time.
3. **Doze / App Standby**: Even with `WAKE_LOCK` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, manufacturers (Xiaomi, Samsung, Huawei) aggressively kill background apps. The `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission is requested but not enforced.
4. **Notification channel importance**: The `break_alarms` channel is set to `IMPORTANCE_HIGH` which is correct, but if the user manually lowers it, the full-screen intent won't trigger.
5. **No notification channel for full-screen alarms specifically**: There's one `break_alarms` channel and one `pre_break_warnings` channel. Full-screen intent uses the `break_alarms` channel — correct, but if this channel gets degraded, full-screen stops working.

**Key gap**: The app does NOT check or request the `USE_FULL_SCREEN_INTENT` runtime permission on Android 14+. This is the most likely reason overlays are missing for main alarms on newer devices.

### 2. Alarm History (Historial)

**Current model has NO fired/dismissed/missed tracking:**

- `AlarmEvents` table in Drift (`database.dart`) stores: `id`, `planId`, `scheduledMs`, `type`, `toneProfile`, `enabled`, `androidAlarmId`. There is **no `status` field** — no column for `fired`, `sounded`, `dismissed`, `missed`.
- `LocalRepository` port has `pruneStaleEnabledEvents(now)` which **soft-disables** past enabled events (`enabled = false`) and returns their native IDs for cancellation. This is purely a cleanup operation — it doesn't track whether they actually fired.
- There is **no "history" concept** anywhere in the domain, application, infrastructure, or presentation layers.
- The presentation layer's `AlarmTimeline` widget only shows **future** alarms with `Activa/Inactiva` pills. Disappeared alarms are pruned silently.

**Key gap**: To implement `Historial`, we need a new `AlarmEventStatus` enum and a `status` column on `AlarmEvents`, plus a new `firedAt`/`dismissedAt`/`soundedAt` timestamp column. The existing `pruneStaleEnabledEvents` must be rewritten to set status instead of just `enabled = false`.

### 3. Contextual Labels

**Where generic labels are produced:**

| Label | File | Line | Current Text |
|-------|------|------|-------------|
| Timeline row header | `alarm_timeline.dart` | 166 | `'Alarma principal'` / `'Preaviso'` |
| Preview step label | `alarm_timeline.dart` | 80 | `'Preaviso ${_minusOneMinute(alarmTime)}'` |
| Preview step label | `alarm_timeline.dart` | 83 | `'Alarma $alarmTime'` |
| Notification title | `native_alarm_scheduler.dart` | 111-135 | Switch on `(type, purpose)` — contextual but still generic ("Descanso", "Inicio de turno", etc.) |
| Notification body | `native_alarm_scheduler.dart` | 138-167 | Switch on `(type, purpose)` — contextual but brief |
| Activity title fallback | `AlarmRingingActivity.kt` | 48 | `"Descanso"` |
| Activity body fallback | `AlarmRingingActivity.kt` | 49 | `"El descanso empieza ahora."` |
| IntentFactory fallback | `AlarmRingingIntentFactory.kt` | 25-27 | `"Descanso"` / `"El descanso empieza ahora."` |

**The notification title/body in `native_alarm_scheduler.dart` already switches on `(AlarmEventType, AlarmEventPurpose)`**, producing contextual text like "Descanso", "Inicio de turno", "Almuerzo", etc. However:

1. The **Flutter UI** (`alarm_timeline.dart`) displays only `'Preaviso'` and `'Alarma principal'` — completely ignoring the `purpose` field.
2. The **native Activity fallbacks** are hardcoded to "Descanso" regardless of purpose.
3. The **preview timeline** doesn't have access to `purpose` or `BreakType` to generate labels like "Preaviso de 1° break inicio".

**Key gap**: The `AlarmEventPurpose` enum already exists in the domain (`shiftStart`, `breakStart`, `breakEnd`, `lunchStart`, `lunchEnd`, `lunchExtensionEnd`, `shiftEnd`) and the native scheduler already uses it. The Flutter presentation layer and the native Activity fallbacks need to derive contextual labels from `AlarmEventPurpose` (and potentially the entry's position/index for "1° break" vs "2° break").

### 24h Retention Cleanup

The current `pruneStaleEnabledEvents` sets `enabled = false` for past alarms. Changing this to a status-based approach with 24h retention means:
- Add `status` column (`scheduled`, `fired`, `dismissed`, `missed`, `expired`) and `statusChangedAt` timestamp
- Fired/dismissed/missed alarms are **history** items — shown in `Historial` for 24h, then hard-deleted
- Currently disabled alarms are not tracked at all — they just disappear

## Affected Areas

- `lib/domain/entities/alarm_event.dart` — Needs `status` and `soundedAt`/`dismissedAt` fields plus `AlarmEventStatus` enum
- `lib/domain/ports/outbound/local_repository.dart` — Needs history query methods, 24h purge method, status update
- `lib/infrastructure/adapters/persistence/database.dart` — Needs schema migration: add `status`, `soundedAt`, `dismissedAt` columns to `AlarmEvents` table; possibly a new `AlarmHistory` table
- `lib/infrastructure/adapters/persistence/drift_local_repository.dart` — Implement new repository methods
- `lib/infrastructure/adapters/alarm/native_alarm_scheduler.dart` — Needs contextual label function (title/body generation) extracted to a shared callable, and the `_titleFor`/`_bodyFor` methods need to be kept in sync with UI labels
- `lib/presentation/widgets/alarm_timeline.dart` — Replace `'Alarma principal'`/`'Preaviso'` with purpose-derived contextual labels
- `lib/presentation/screens/import_screen.dart` — Minor: no structural change needed, but `BreakPreviewTimeline` labels need contextualization
- `lib/presentation/providers/import_flow_controller.dart` — Needs history loading, 24h cleanup trigger
- `android/.../AlarmRingingActivity.kt` — Fallback strings must match contextual labels; needs to pass purpose via intent extras
- `android/.../AlarmReceiver.kt` — Needs to pass `purpose` through intent extras to Activity
- `android/.../AlarmRingingIntentFactory.kt` — Needs to relay `purpose` from intent extras
- `android/.../AlarmRingingService.kt` — Notification title/body already good, but must ensure purpose is in intent extras
- `android/.../AlarmSchedulerAdapter.kt` — Needs to store/retrieve `purpose` field in SharedPreferences persistence
- `lib/domain/errors/domain_errors.dart` — Likely fine
- `lib/application/use_cases/review_and_confirm.dart` — May need to pass purpose through to scheduler
- `android/.../MainActivity.kt` — Possible: need to add `USE_FULL_SCREEN_INTENT` permission check/request
- `android/.../BootCompletedReceiver.kt` — Reschedule must preserve purpose data
- `lib/infrastructure/adapters/permissions/android_permission_gateway.dart` — Needs `hasFullScreenIntentPermission()` / `requestFullScreenIntentPermission()` methods
- `lib/domain/ports/outbound/permission_gateway.dart` — Needs full-screen intent permission methods
- `test/` — All affected test files need updates

## Approaches

### 1. Incremental Domain-First Approach (Recommended)

Extend `AlarmEvent` with status tracking, add a history display, and fix the full-screen permission gap — all within the existing hexagonal architecture.

- **Pros**:
  - Follows existing Clean/Hexagonal patterns perfectly
  - Each concern (popup fix, history, labels) can be proposed as separate tasks within one change
  - Minimal architectural disruption — no new tables needed, just column additions
  - TDD-friendly: domain entities and ports change first, then adapters
- **Cons**:
  - Schema migration required (Drift version bump)
  - Three concerns touch overlapping files, so task ordering matters
- **Effort**: Medium

### 2. Separate History Table Approach

Add a new `AlarmHistory` table alongside `AlarmEvents` — when an alarm fires/dismisses, copy a record there and soft-delete the original.

- **Pros**:
  - Cleaner separation of "active" vs "historical" data
  - 24h cleanup is trivial — `DELETE FROM alarm_history WHERE dismissed_at < now - 24h`
  - No migration to existing `AlarmEvents`
- **Cons**:
  - Data duplication — every alarm event ends up in two tables
  - More complex repository interface
  - When does the copy happen? Requires a state-change callback from Android native → Flutter
- **Effort**: Medium-High

### 3. Status Flags on Existing Table Only (Simplest)

Add `status` column to `AlarmEvents` only — no timestamps. History = `status != scheduled`.

- **Pros**:
  - Minimal migration
  - Existing prune logic replaced by status update
- **Cons**:
  - Can't calculate 24h without a timestamp column
  - Can't distinguish "fired 23h ago" from "fired 2h ago" for cleanup
- **Effort**: Low — but insufficient for 24h retention requirement

## Recommendation

**Approach 1: Incremental Domain-First.**

Rationale:
- The project follows strict hexagonal architecture with domain entities, outbound ports, and infrastructure adapters. Adding status tracking within `AlarmEvent` and migrating `AlarmEvents` table is the natural path.
- A `status` + `statusChangedAt` column pair on `AlarmEvents` enables both history display and 24h retention cleanup without data duplication.
- The full-screen overlay fix is orthogonal — it requires adding a permission check in `PermissionGateway` and a runtime request flow, which is a clean adapter-level change.
- Contextual labels can be extracted into a dedicated domain service or extension that both Flutter UI and native notification tiers can call, maintaining DRY.

## Risks

- **Android 14+ `USE_FULL_SCREEN_INTENT` runtime permission**: This permission can only be granted through system settings for non-call apps on Android 14+. If the system denies it, the full-screen Activity simply won't show — the app must fall back gracefully to a high-priority heads-up notification. This is a platform constraint, not a code bug.
- **Drift schema migration**: Adding columns to `AlarmEvents` requires bumping `schemaVersion` and writing a migration. Existing data must be preserved with defaults (`status = 'scheduled'`, `statusChangedAt = null`). Test coverage must verify migration correctness.
- **Native ↔ Flutter state synchronization**: When an alarm fires on the Android side, the Flutter UI doesn't know about it unless we add a callback channel (`EventChannel` or `MethodChannel` callback). Without this, history can only be updated on the next app open. This is acceptable for V1 (history reflects what happened, updated when the user opens the app).
- **Contextual label DRY**: Labels must stay consistent across 3 surfaces: (1) Flutter `AlarmTimeline` widget, (2) Android notification title/body in `NativeAlarmScheduler._titleFor`/`_bodyFor`, and (3) Android `AlarmRingingActivity` fallback strings. Changes must be synchronized across Dart and Kotlin.
- **Index/ordinal for "1°" vs "2°" break**: The current domain model (`AlarmEvent`) does NOT carry the ordinal index (which break number is this?). The `purpose` field is `breakStart`/`breakEnd`, not `firstBreakStart`/`secondBreakStart`. Labeling "1° Break" vs "2° Break" requires computing ordinal position from the alarm plan's sorted list, not from the individual event. This influences how contextual labels are derived.

## Ready for Proposal

**Yes.** The three concerns (popup, history, labels) are well-scoped and the domain model is ready for extension. The next step is `sdd-propose` to define the change proposal with intent, scope, and approach.