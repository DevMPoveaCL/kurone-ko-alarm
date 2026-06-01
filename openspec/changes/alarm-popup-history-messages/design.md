# Design: Alarm Popup, History & Contextual Messages

## Technical Approach

Add `status` + `statusChangedAt` to `AlarmEvent` and persist them via a Drift migration. A native SharedPreferences outcome log bridges dismissal events from Kotlin to Dart without an EventChannel. A pure domain label helper computes contextual Spanish titles with break ordinals derived from the plan alarm list, keeping `AlarmEvent` identity clean. Android 14+ `USE_FULL_SCREEN_INTENT` is surfaced through `PermissionGateway`; when denied, the scheduler sends `showFullScreenAlarm: false` so `AlarmReceiver` falls back to the existing high-importance `break_alarms` heads-up notification.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Break ordinal source | Computed from sorted plan list at scheduling / display time | Keeps domain identity free of display-only numbering |
| Native → Flutter sync | SharedPreferences JSON log queried on app open | Avoids background complexity; aligns with spec out-of-scope on real-time sync |
| Full-screen fallback | Check permission at schedule time; if denied, set `showFullScreenAlarm: false` | Simpler to test from Dart; permission rarely changes after scheduling |
| History storage | Reuse `AlarmEvents` table with `status` + `statusChangedAt` | Avoids extra table; history is a filtered view of the same rows |

## Data Flow

```
Schedule/Display:
  AlarmPlan.alarms → AlarmEventLabel.title(event, breakOrdinal)
    ├→ NativeAlarmScheduler.schedule (title/body extras)
    └→ AlarmTimeline widget (inline ordinal computation)

Alarm Fire:
  AlarmReceiver → AlarmRingingService
    ├─ showFullScreenAlarm:true → AlarmRingingActivity
    └─ showFullScreenAlarm:false → heads-up Notification

Dismissal:
  User taps Stop → Kotlin writes {id, status, atMillis} to alarm_outcomes SP

App Open:
  ImportFlowController.loadActiveAlarms() → syncAlarmOutcomes()
    → DriftLocalRepository.updateAlarmStatus() → purgeHistoryOlderThan(24h)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/domain/entities/alarm_event.dart` | Modify | Add `AlarmEventStatus` enum, `status`, `statusChangedAt` |
| `lib/domain/ports/outbound/permission_gateway.dart` | Modify | Add `hasFullScreenIntentPermission`, `requestFullScreenIntentPermission` |
| `lib/domain/ports/outbound/local_repository.dart` | Modify | Add `updateAlarmStatus`, `getAlarmHistory`, `purgeHistoryOlderThan` |
| `lib/domain/services/alarm_event_label.dart` | Create | Pure `title(AlarmEvent, {int breakOrdinal})` and `body(AlarmEvent)` |
| `lib/infrastructure/adapters/persistence/database.dart` | Modify | Schema 2; add `status` (default `'scheduled'`) and `statusChangedAt` (nullable) to `AlarmEvents`; add `onUpgrade` |
| `lib/infrastructure/adapters/persistence/drift_local_repository.dart` | Modify | History query, status update, 24h purge |
| `lib/infrastructure/adapters/alarm/native_alarm_scheduler.dart` | Modify | Replace `_titleFor`/`_bodyFor` with `AlarmEventLabel`; compute ordinals in `rescheduleAll` via private `_schedule` |
| `lib/infrastructure/adapters/permissions/android_permission_gateway.dart` | Modify | Delegate new full-screen intent methods through MethodChannel |
| `lib/presentation/widgets/alarm_timeline.dart` | Modify | Use contextual labels; add history section |
| `lib/presentation/providers/import_flow_controller.dart` | Modify | Call `syncAlarmOutcomes` and `purgeHistoryOlderThan` during `loadActiveAlarms` |
| `android/.../AlarmSchedulerAdapter.kt` | Modify | Add `hasFullScreenIntentPermission`; persist `purpose`; add `syncAlarmOutcomes` handler |
| `android/.../AlarmRingingActivity.kt` | Modify | Remove hardcoded break-specific fallback strings; use generic defaults |
| `android/.../AlarmRingingIntentFactory.kt` | Modify | Relay `purpose` extra for future native reconstruction |
| `android/.../MainActivity.kt` | Modify | Check/request `USE_FULL_SCREEN_INTENT` on API 34+ |

## Interfaces / Contracts

```dart
enum AlarmEventStatus { scheduled, fired, dismissed, missed }

final class AlarmEvent {
  // existing fields ...
  final AlarmEventStatus status;
  final DateTime? statusChangedAt;
}

abstract class PermissionGateway {
  Future<bool> hasFullScreenIntentPermission();
  Future<bool> requestFullScreenIntentPermission();
}

abstract class LocalRepository {
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status);
  Future<List<AlarmEvent>> getAlarmHistory();
  Future<void> purgeHistoryOlderThan(DateTime cutoff);
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `AlarmEventLabel.title/body` for all purposes, with/without ordinals | Table-driven pure functions |
| Unit | `breakOrdinalFor` helper | Assert 1°, 2° indexing for break start/end pairs |
| Unit | `AndroidPermissionGateway` full-screen methods | Mock MethodChannel |
| Unit | `NativeAlarmScheduler` sends contextual title with ordinal | Mock channel; inspect `title` argument |
| Unit | `DriftLocalRepository` migration, history, purge, status update | In-memory `NativeDatabase.memory()` with schema 2 |
| Widget | `AlarmTimeline` renders contextual labels and history | Pump widget with fake alarms/history |
| E2E (manual) | Android 14+ permission grant/deny and fallback notification | Physical device verification |

## Migration / Rollout

1. **Drift**: Schema 1 → 2 adds `status` (default `'scheduled'`) and `statusChangedAt`. Existing rows remain `scheduled`.
2. **Permission**: `MainActivity` checks `USE_FULL_SCREEN_INTENT` on API 34+ at startup. Denial degrades to heads-up notifications.
3. **Rollback**: Revert schema to 1; remove new columns from entity and repository. History entries created during the window are lost, which is acceptable.

## Open Questions

- Past alarms without explicit dismissal are marked `fired` during stale pruning. Refine to `missed` if the native scheduler later supports explicit missed detection.
