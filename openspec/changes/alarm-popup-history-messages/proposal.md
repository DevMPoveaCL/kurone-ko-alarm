# Proposal: Alarm Popup, History & Contextual Messages

## Intent

Main alarms don't always show the full-screen overlay on Android 14+, past alarms vanish silently with no history, and UI labels are generic (`Alarma principal`, `Preaviso`) instead of contextual (`Preaviso de 1° break inicio`). This change fixes all three gaps within the existing hexagonal architecture.

## Scope

### In Scope
- Android 14+ `USE_FULL_SCREEN_INTENT` runtime permission check/request via `PermissionGateway`
- Graceful fallback to high-priority heads-up notification when full-screen is denied
- `AlarmEventStatus` enum + `statusChangedAt` column on `AlarmEvents` table (Drift schema migration)
- Alarm history UI section showing fired/dismissed/missed alarms with 24h retention
- 24h cleanup: hard-delete entries with `statusChangedAt > 24h` on app open
- Contextual labels derived from `AlarmEventPurpose` (with ordinal index for break numbering)
- Synchronized labels across Flutter `AlarmTimeline`, Android notifications, and `AlarmRingingActivity` fallbacks

### Out of Scope
- Real-time native → Flutter state sync (history reflects state on next app open, no EventChannel)
- Push notifications or remote alarm event tracking
- History analytics or export

## Capabilities

### New Capabilities
- `fullscreen-alarm-overlay`: Full-screen Activity for main alarms with Android 14+ permission handling and fallback
- `alarm-history`: Persistent alarm event status tracking (fired/dismissed/missed) with 24h retention and UI display
- `contextual-alarm-messages`: Purpose-derived alarm labels with break ordinal numbering, synchronized across Flutter and native surfaces

### Modified Capabilities
None — no existing specs.

## Approach

**Incremental Domain-First** (recommended in exploration). Extend `AlarmEvent` with `status` + `statusChangedAt`, add `PermissionGateway` methods for full-screen intent, and extract a shared labeling function from `AlarmEventPurpose`. Drift migration adds columns with defaults. Native Kotlin Activity receives `purpose` via intent extras instead of hardcoded strings. No new tables — history is derived from `status != scheduled` query filter.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/domain/entities/alarm_event.dart` | Modified | Add `AlarmEventStatus` enum, `status`, `statusChangedAt` fields |
| `lib/domain/ports/outbound/permission_gateway.dart` | Modified | Add `hasFullScreenIntentPermission`, `requestFullScreenIntentPermission` |
| `lib/infrastructure/adapters/persistence/database.dart` | Modified | Drift schema migration: add `status`, `statusChangedAt` columns |
| `lib/infrastructure/adapters/persistence/drift_local_repository.dart` | Modified | History query, status update, 24h purge methods |
| `lib/infrastructure/adapters/alarm/native_alarm_scheduler.dart` | Modified | Extract contextual label function; pass purpose through native calls |
| `lib/infrastructure/adapters/permissions/android_permission_gateway.dart` | Modified | Implement full-screen intent permission methods |
| `lib/presentation/widgets/alarm_timeline.dart` | Modified | Replace generic labels with purpose-derived labels; add history section |
| `lib/presentation/providers/import_flow_controller.dart` | Modified | Load history, trigger 24h cleanup |
| `android/.../AlarmRingingActivity.kt` | Modified | Accept `purpose` via intent extras instead of hardcoded fallbacks |
| `android/.../AlarmRingingIntentFactory.kt` | Modified | Relay `purpose` through intent extras |
| `android/.../AlarmSchedulerAdapter.kt` | Modified | Persist `purpose` in SharedPreferences |
| `android/.../MainActivity.kt` | Modified | Check/request `USE_FULL_SCREEN_INTENT` on API 34+ |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `USE_FULL_SCREEN_INTENT` denied by system on Android 14+ | Medium | Graceful fallback to heads-up notification; permission guide dialog |
| Drift schema migration corrupts existing data | Low | Migration with defaults (`status='scheduled'`), test coverage for migration |
| Break ordinal numbering missing from domain model | Medium | Compute ordinal from sorted plan event list; accept index parameter in labels |
| Label inconsistency across Dart/Kotlin | Low | Shared label logic extracted to single function; tests assert parity |

## Rollback Plan

Revert the Drift migration (schema rollback), revert `AlarmEvent` entity changes, and remove the history UI section. Full-screen Activity and permission gateway changes are additive — disable by reverting `PermissionGateway` additions. No state loss beyond history entries created during the change window.

## Dependencies

- Exploration artifact: `openspec/changes/alarm-popup-history-messages/exploration.md`

## Success Criteria

- [ ] Full-screen overlay fires on Android 14+ when permission is granted; heads-up fallback when denied
- [ ] Alarm history displays fired/dismissed/missed entries with contextual labels for at least 24h
- [ ] `AlarmTimeline` shows labels like `Preaviso de 1° break inicio` instead of `Preaviso`
- [ ] Existing active alarms continue scheduling correctly after migration
- [ ] 24h purge removes old history entries on app open
