import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/application/use_cases/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/import_schedule.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/presentation/providers/import_flow_controller.dart';

void main() {
  group('ImportFlowController', () {
    test(
      'imports an Excel file into review-ready state with visible draft data',
      () async {
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
              extension: 'xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);

        final state = container.read(importFlowControllerProvider);
        expect(state.status, ImportFlowStatus.reviewReady);
        expect(state.selectedFileName, 'breaks.xlsx');
        expect(state.draft?.entries.single.fields['breakStart'], '12:30');
        expect(state.lowConfidenceCount, 1);
      },
    );

    test(
      'surfaces picker cancellation and import failures without a draft',
      () async {
        final cancelled = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
        );
        addTearDown(cancelled.dispose);

        await cancelled
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.image);

        expect(
          cancelled.read(importFlowControllerProvider).status,
          ImportFlowStatus.idle,
        );
        expect(cancelled.read(importFlowControllerProvider).draft, isNull);

        final failed = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'bad.xlsx',
              fileName: 'bad.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(error: Exception('parse failed')),
          reviewUseCase: _FakeReviewUseCase(),
        );
        addTearDown(failed.dispose);

        await failed
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);

        final failedState = failed.read(importFlowControllerProvider);
        expect(failedState.status, ImportFlowStatus.error);
        expect(failedState.errorMessage, contains('parse failed'));
        expect(failedState.draft, isNull);
      },
    );

    test(
      'edits, confirms, and cancels through the review gate only when a draft exists',
      () async {
        final reviewUseCase = _FakeReviewUseCase();
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: reviewUseCase,
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        container
            .read(importFlowControllerProvider.notifier)
            .editEntry(entryId: 'entry-1', fields: {'breakStart': '12:45'});
        await container.read(importFlowControllerProvider.notifier).confirm();

        final confirmed = container.read(importFlowControllerProvider);
        expect(confirmed.status, ImportFlowStatus.confirmed);
        expect(confirmed.draft?.entries.single.fields['breakStart'], '12:45');
        expect(confirmed.confirmedPlan?.id, 'plan_draft-1');
        expect(
          reviewUseCase.confirmedDraft?.entries.single.fields['breakStart'],
          '12:45',
        );

        await container.read(importFlowControllerProvider.notifier).cancel();

        final cancelled = container.read(importFlowControllerProvider);
        expect(cancelled.status, ImportFlowStatus.cancelled);
        expect(reviewUseCase.cancelledDraft?.id, 'draft-1');
      },
    );

    test(
      'shows a visual alarm pair after confirmation even before native scheduling is wired',
      () async {
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(returnEmptyPlan: true),
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        await container.read(importFlowControllerProvider.notifier).confirm();

        final alarms = container
            .read(importFlowControllerProvider)
            .activeAlarms;
        expect(alarms.map((alarm) => alarm.type), [
          AlarmEventType.preWarning,
          AlarmEventType.main,
          AlarmEventType.preWarning,
          AlarmEventType.main,
          AlarmEventType.preWarning,
          AlarmEventType.main,
        ]);
        expect(
          alarms
              .where((alarm) => alarm.type == AlarmEventType.main)
              .map((alarm) => alarm.scheduledTime),
          [
            DateTime(2026, 5, 14, 8),
            DateTime(2026, 5, 14, 12, 30),
            DateTime(2026, 5, 14, 17),
          ],
        );
      },
    );

    test(
      'visual preview includes break end alarms and uses parsed date',
      () async {
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draftWithBreakEnd()),
          reviewUseCase: _FakeReviewUseCase(returnEmptyPlan: true),
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        await container.read(importFlowControllerProvider.notifier).confirm();

        final mainAlarmTimes = container
            .read(importFlowControllerProvider)
            .activeAlarms
            .where((alarm) => alarm.type == AlarmEventType.main)
            .map((alarm) => alarm.scheduledTime)
            .toList();

        expect(mainAlarmTimes, [
          DateTime(2026, 5, 20, 12, 30),
          DateTime(2026, 5, 20, 12, 45),
        ]);
      },
    );

    test('missing date keeps review from being confirmable', () async {
      final container = _container(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'breaks.xlsx',
            fileName: 'breaks.xlsx',
          ),
        ),
        importUseCase: _FakeImportUseCase(
          draft: _draftWithBreakEnd(includeDate: false),
        ),
        reviewUseCase: _FakeReviewUseCase(returnEmptyPlan: true),
      );
      addTearDown(container.dispose);

      await container
          .read(importFlowControllerProvider.notifier)
          .importFrom(FilePickType.excel);

      expect(container.read(importFlowControllerProvider).canConfirm, isFalse);
    });

    test(
      'confirm preserves edited numeric date and second-precision times in confirmed plan',
      () async {
        final repository = _FakeLocalRepository();
        final reviewUseCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
          scheduler: _RecordingAlarmScheduler(),
        );
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(
            draft: _draftMissingDateWithSeconds(),
          ),
          reviewUseCase: reviewUseCase,
          repository: repository,
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        container
            .read(importFlowControllerProvider.notifier)
            .editEntry(entryId: 'entry-1', fields: {'date': '15-06-2026'});
        await container.read(importFlowControllerProvider.notifier).confirm();

        final state = container.read(importFlowControllerProvider);
        expect(state.status, ImportFlowStatus.confirmed);
        expect(state.draft?.entries.single.fields['date'], '15-06-2026');
        expect(
          state.confirmedPlan?.mainAlarms.map((alarm) => alarm.scheduledTime),
          [DateTime(2026, 6, 15, 1, 45), DateTime(2026, 6, 15, 2)],
        );
        expect(state.confirmedPlan?.alarms, hasLength(4));
        expect(state.activeAlarms, hasLength(4));
        expect(
          await repository.getPlan('plan_draft-seconds'),
          state.confirmedPlan,
        );
      },
    );

    test(
      'scheduler failure during confirm leaves controller in error state',
      () async {
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(
            error: const SchedulingFailure(message: 'exact alarm denied'),
          ),
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        await container.read(importFlowControllerProvider.notifier).confirm();

        final state = container.read(importFlowControllerProvider);
        expect(state.status, ImportFlowStatus.error);
        expect(state.draft?.id, 'draft-1');
        expect(state.confirmedPlan, isNull);
        expect(state.errorMessage, contains('alarmas exactas'));
        expect(state.errorMessage, isNot(contains('SchedulingFailure')));
      },
    );

    test(
      'permission denied during confirm shows actionable Spanish message',
      () async {
        final container = _container(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'breaks.xlsx',
              fileName: 'breaks.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(
            error: const PermissionDenied(permission: 'exactAlarm'),
          ),
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .importFrom(FilePickType.excel);
        await container.read(importFlowControllerProvider.notifier).confirm();

        final state = container.read(importFlowControllerProvider);
        expect(state.status, ImportFlowStatus.error);
        expect(state.draft?.id, 'draft-1');
        expect(state.errorMessage, contains('alarmas exactas'));
        expect(state.errorMessage, contains('Ajustes'));
        expect(state.errorMessage, isNot(contains('PermissionDenied')));
        expect(state.errorMessage, isNot(contains('SchedulingFailure')));
      },
    );

    test(
      'loadActiveAlarms prunes stale enabled alarms and cancels their native IDs',
      () async {
        final repository = _FakeLocalRepositoryWithStaleAlarms();
        final scheduler = _RecordingAlarmScheduler();
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          scheduler: scheduler,
        );
        addTearDown(container.dispose);

        await container
            .read(importFlowControllerProvider.notifier)
            .loadActiveAlarms();

        // Stale alarms (past) are pruned, only future remains in activeAlarms
        final state = container.read(importFlowControllerProvider);
        expect(state.activeAlarms.map((e) => e.id), ['future-alarm']);

        // Native scheduler cancel was called for stale androidAlarmIds 100 and 101
        expect(scheduler.cancelledIds, contains(100));
        expect(scheduler.cancelledIds, contains(101));
        expect(
          scheduler.cancelledIds,
          isNot(contains(102)),
        ); // future - not cancelled
      },
    );

    test(
      'startup asks native scheduler to prune stale persisted alarms',
      () async {
        final scheduler = _RecordingAlarmScheduler();
        final clock = _FixedClock(DateTime.utc(2026, 5, 20, 10, 30));
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          scheduler: scheduler,
          clock: clock,
          skipAutoLoad: false,
        );
        addTearDown(container.dispose);

        container.read(importFlowControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        expect(scheduler.pruneRequests, [DateTime.utc(2026, 5, 20, 10, 30)]);
      },
    );

    test(
      'periodic active-alarm refresh prunes expired alarms while controller is alive',
      () async {
        final repository = _FakeLocalRepositoryWithStaleAlarms();
        final scheduler = _RecordingAlarmScheduler();
        late void Function() tick;
        var timerCancelled = false;
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          scheduler: scheduler,
          activeAlarmRefreshTimerFactory: (interval, onTick) {
            expect(interval, const Duration(seconds: 5));
            tick = onTick;
            return _FakeTimer(onCancel: () => timerCancelled = true);
          },
        );
        container.read(importFlowControllerProvider.notifier);

        tick();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(importFlowControllerProvider);
        expect(state.activeAlarms.map((alarm) => alarm.id), ['future-alarm']);
        expect(scheduler.cancelledIds, containsAll([100, 101]));

        container.dispose();

        expect(timerCancelled, isTrue);
      },
    );

    test(
      'loadActiveAlarms maps dismissed outcome using nativeIdFor when androidAlarmId is null',
      () async {
        final pastAlarm = AlarmEvent(
          id: 'past-alarm',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 8),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          enabled: true,
          androidAlarmId: null,
        );
        final repository = _FakeRepositoryForSyncTest(
          plans: [
            AlarmPlan(
              id: 'plan-1',
              scheduleId: 'draft-1',
              alarms: [pastAlarm],
              createdAt: DateTime.utc(2026, 5, 14, 7),
            ),
          ],
        );
        final scheduler = _FakeSchedulerWithOutcomes(
          outcomes: [
            {
              'id': pastAlarm.id.hashCode,
              'status': 'dismissed',
              'atMillis': DateTime.utc(2026, 5, 14, 8, 1).millisecondsSinceEpoch,
            },
          ],
        );
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          scheduler: scheduler,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9)),
        );
        addTearDown(container.dispose);

        await container.read(importFlowControllerProvider.notifier).loadActiveAlarms();

        final state = container.read(importFlowControllerProvider);
        expect(state.history, hasLength(1));
        expect(state.history.first.status, AlarmEventStatus.dismissed);
      },
    );

    test(
      'loadActiveAlarms syncs outcomes before pruning stale alarms',
      () async {
        final callOrder = <String>[];
        final repository = _FakeRepositoryForSyncTest(
          plans: [
            AlarmPlan(
              id: 'plan-1',
              scheduleId: 'draft-1',
              alarms: [
                AlarmEvent(
                  id: 'future',
                  planId: 'plan-1',
                  scheduledTime: DateTime.utc(2026, 5, 20, 8),
                  type: AlarmEventType.main,
                  toneProfile: ToneProfile.breakStart,
                ),
              ],
              createdAt: DateTime.utc(2026, 5, 14, 7),
            ),
          ],
          callOrder: callOrder,
        );
        final scheduler = _FakeSchedulerWithOutcomes(
          outcomes: [],
          callOrder: callOrder,
        );
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          scheduler: scheduler,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9)),
        );
        addTearDown(container.dispose);

        await container.read(importFlowControllerProvider.notifier).loadActiveAlarms();

        final syncIndex = callOrder.indexOf('syncAlarmOutcomes');
        final pruneIndex = callOrder.indexOf('pruneStaleEnabledEvents');
        expect(syncIndex, isNot(-1));
        expect(pruneIndex, isNot(-1));
        expect(syncIndex, lessThan(pruneIndex));
      },
    );

    test(
      'editAlarmTime updates one alarm and reschedules it while leaving others untouched',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          scheduler: scheduler,
        );
        addTearDown(container.dispose);

        final controller = container.read(
          importFlowControllerProvider.notifier,
        );
        controller.state = ImportFlowState(
          activeAlarms: [
            AlarmEvent(
              id: 'main-1',
              planId: 'plan-1',
              scheduledTime: DateTime.utc(2026, 5, 20, 8),
              type: AlarmEventType.main,
              toneProfile: ToneProfile.breakStart,
              androidAlarmId: 100,
            ),
            AlarmEvent(
              id: 'main-1_pre',
              planId: 'plan-1',
              scheduledTime: DateTime.utc(2026, 5, 20, 7, 59),
              type: AlarmEventType.preWarning,
              toneProfile: ToneProfile.preBreak,
              androidAlarmId: 101,
            ),
            AlarmEvent(
              id: 'main-2',
              planId: 'plan-1',
              scheduledTime: DateTime.utc(2026, 5, 20, 12),
              type: AlarmEventType.main,
              toneProfile: ToneProfile.breakStart,
              androidAlarmId: 200,
            ),
          ],
        );

        await controller.editAlarmTime(
          'main-1',
          DateTime.utc(2026, 5, 20, 9, 30),
        );

        final state = container.read(importFlowControllerProvider);
        final edited = state.activeAlarms.firstWhere((a) => a.id == 'main-1');
        expect(edited.scheduledTime, DateTime.utc(2026, 5, 20, 9, 30));

        final prewarning = state.activeAlarms.firstWhere(
          (a) => a.id == 'main-1_pre',
        );
        expect(prewarning.scheduledTime, DateTime.utc(2026, 5, 20, 9, 29));

        final untouched = state.activeAlarms.firstWhere(
          (a) => a.id == 'main-2',
        );
        expect(untouched.scheduledTime, DateTime.utc(2026, 5, 20, 12));

        // Scheduler should have cancelled old alarm ids and scheduled new ones
        expect(scheduler.cancelledIds, contains(100));
        expect(scheduler.cancelledIds, contains(101));
        expect(scheduler.cancelledIds, isNot(contains(200)));
      },
    );

    test(
      'periodic refresh interval is 5 seconds for tighter sync',
      () async {
        Duration? capturedInterval;
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          activeAlarmRefreshTimerFactory: (interval, onTick) {
            capturedInterval = interval;
            return _FakeTimer(onCancel: () {});
          },
        );
        container.read(importFlowControllerProvider.notifier);

        expect(capturedInterval, const Duration(seconds: 5));
      },
    );

    test(
      'loadActiveAlarms moves past scheduled alarms to history via prune',
      () async {
        final repository = _FakeRepositoryForSyncTest(
          plans: [
            AlarmPlan(
              id: 'plan-1',
              scheduleId: 'draft-1',
              alarms: [
                AlarmEvent(
                  id: 'past-alarm',
                  planId: 'plan-1',
                  scheduledTime: DateTime.utc(2026, 5, 14, 8),
                  type: AlarmEventType.main,
                  toneProfile: ToneProfile.breakStart,
                  enabled: true,
                ),
              ],
              createdAt: DateTime.utc(2026, 5, 14, 7),
            ),
          ],
        );
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9)),
        );
        addTearDown(container.dispose);

        await container.read(importFlowControllerProvider.notifier).loadActiveAlarms();

        final state = container.read(importFlowControllerProvider);
        expect(state.activeAlarms, isEmpty);
        expect(state.history, hasLength(1));
        expect(state.history.first.id, 'past-alarm');
        expect(state.history.first.status, AlarmEventStatus.missed);
      },
    );

    test(
      'startup auto-populates active alarms and history from repository',
      () async {
        final repository = _FakeRepositoryForSyncTest(
          plans: [
            AlarmPlan(
              id: 'plan-1',
              scheduleId: 'draft-1',
              alarms: [
                AlarmEvent(
                  id: 'future',
                  planId: 'plan-1',
                  scheduledTime: DateTime.utc(2026, 5, 20, 8),
                  type: AlarmEventType.main,
                  toneProfile: ToneProfile.breakStart,
                ),
              ],
              createdAt: DateTime.utc(2026, 5, 14, 7),
            ),
          ],
        );
        final container = _container(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9)),
          skipAutoLoad: false,
        );
        addTearDown(container.dispose);

        container.read(importFlowControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(importFlowControllerProvider);
        expect(state.activeAlarms, hasLength(1));
        expect(state.activeAlarms.first.id, 'future');
        expect(state.history, isEmpty);
      },
    );
  });
}

ProviderContainer _container({
  required FilePicker filePicker,
  required ImportScheduleUseCase importUseCase,
  required ReviewAndConfirmUseCase reviewUseCase,
  LocalRepository? repository,
  Clock? clock,
  AlarmScheduler? scheduler,
  ActiveAlarmRefreshTimerFactory? activeAlarmRefreshTimerFactory,
  bool skipAutoLoad = true,
}) {
  final effectiveRepository = repository ?? _FakeLocalRepository();
  final effectiveClock = clock ?? _FixedClock(DateTime.utc(2026, 5, 14, 10));
  final effectiveScheduler = scheduler ?? _RecordingAlarmScheduler();
  return ProviderContainer(
    overrides: [
      filePickerProvider.overrideWithValue(filePicker),
      importScheduleUseCaseProvider.overrideWithValue(importUseCase),
      reviewAndConfirmUseCaseProvider.overrideWithValue(reviewUseCase),
      localRepositoryProvider.overrideWithValue(effectiveRepository),
      clockProvider.overrideWithValue(effectiveClock),
      alarmSchedulerProvider.overrideWithValue(effectiveScheduler),
      activeAlarmRefreshTimerFactoryProvider.overrideWithValue(
        activeAlarmRefreshTimerFactory ??
            (interval, onTick) => _FakeTimer(onCancel: () {}),
      ),
      importFlowControllerProvider.overrideWith((ref) {
        return ImportFlowController(
          filePicker: ref.watch(filePickerProvider),
          importUseCase: ref.watch(importScheduleUseCaseProvider),
          reviewUseCase: ref.watch(reviewAndConfirmUseCaseProvider),
          repository: ref.watch(localRepositoryProvider),
          clock: ref.watch(clockProvider),
          scheduler: ref.watch(alarmSchedulerProvider),
          activeAlarmRefreshTimerFactory: ref.watch(
            activeAlarmRefreshTimerFactoryProvider,
          ),
          skipAutoLoad: skipAutoLoad,
        );
      }),
    ],
  );
}

ScheduleDraft _draft() {
  return ScheduleDraft(
    id: 'draft-1',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: const [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          'date': '14-MAYO-2026',
          'name': 'Mika',
          'startTime': '08:00',
          'endTime': '17:00',
          'breakStart': '12:30',
        },
        confidence: Confidence.low(reason: 'Ambiguous break column'),
      ),
    ],
  );
}

ScheduleDraft _draftWithBreakEnd({bool includeDate = true}) {
  return ScheduleDraft(
    id: 'draft-break-end',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          if (includeDate) 'date': '20-MAYO-2026',
          'breakStart': '12:30',
          'breakEnd': '12:45',
        },
        confidence: const Confidence.high(),
      ),
    ],
  );
}

ScheduleDraft _draftMissingDateWithSeconds() {
  return ScheduleDraft(
    id: 'draft-seconds',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: const [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {'breakStart': '01:45:00', 'breakEnd': '02:00:00'},
        confidence: Confidence.high(),
      ),
    ],
  );
}

final class _FixedClock implements Clock {
  final DateTime value;

  const _FixedClock(this.value);

  @override
  DateTime now() => value;
}

final class _FakeFilePicker implements FilePicker {
  final FilePickResult? result;

  const _FakeFilePicker({required this.result});

  @override
  Future<FilePickResult?> pick({required FilePickType type}) async => result;
}

final class _FakeImportUseCase implements ImportScheduleUseCase {
  final ScheduleDraft? draft;
  final Object? error;

  const _FakeImportUseCase({this.draft, this.error});

  @override
  Future<ScheduleDraft> import({
    required String filePath,
    required ImportSource source,
  }) async {
    if (error != null) {
      throw error!;
    }
    return draft!;
  }
}

final class _FakeReviewUseCase implements ReviewAndConfirmUseCase {
  final bool returnEmptyPlan;
  final Object? error;
  ScheduleDraft? confirmedDraft;
  ScheduleDraft? cancelledDraft;

  _FakeReviewUseCase({this.returnEmptyPlan = false, this.error});

  @override
  Future<AlarmPlan> confirm(ScheduleDraft draft) async {
    if (error != null) {
      throw error!;
    }
    confirmedDraft = draft;
    if (returnEmptyPlan) {
      return AlarmPlan(
        id: 'plan_${draft.id}',
        scheduleId: draft.id,
        alarms: const [],
        createdAt: DateTime.utc(2026, 5, 14, 10),
      );
    }
    return AlarmPlan(
      id: 'plan_${draft.id}',
      scheduleId: draft.id,
      alarms: [
        AlarmEvent(
          id: 'main-1',
          planId: 'plan_${draft.id}',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 45),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
        ),
        AlarmEvent(
          id: 'pre-1',
          planId: 'plan_${draft.id}',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 44),
          type: AlarmEventType.preWarning,
          toneProfile: ToneProfile.preBreak,
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 14, 10),
    );
  }

  @override
  Future<void> cancel(ScheduleDraft draft) async {
    cancelledDraft = draft;
  }

  @override
  ScheduleDraft updateEntry(
    ScheduleDraft draft, {
    required String entryId,
    required Map<String, String> fields,
  }) {
    return draft.copyWith(
      entries: draft.entries
          .map(
            (entry) => entry.id == entryId
                ? entry.copyWith(fields: {...entry.fields, ...fields})
                : entry,
          )
          .toList(),
    );
  }
}

final class _FakeLocalRepository implements LocalRepository {
  final Map<String, ScheduleDraft> drafts = {};
  final Map<String, AlarmPlan> plans = {};

  @override
  Future<void> deleteDraft(String id) async {
    drafts.remove(id);
  }

  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => drafts.values.toList();

  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async => plans.values
      .expand((plan) => plan.alarms)
      .where(
        (event) =>
            event.enabled && event.status == AlarmEventStatus.scheduled,
      )
      .toList();

  @override
  Future<List<AlarmPlan>> getAllPlans() async => plans.values.toList();

  @override
  Future<ScheduleDraft?> getDraft(String id) async => drafts[id];

  @override
  Future<List<AlarmEvent>> getEventsForPlan(String planId) async =>
      plans[planId]?.alarms ?? const [];

  @override
  Future<AlarmPlan?> getPlan(String id) async => plans[id];

  @override
  Future<void> saveDraft(ScheduleDraft draft) async {
    drafts[draft.id] = draft;
  }

  @override
  Future<void> savePlan(AlarmPlan plan) async {
    plans[plan.id] = plan;
  }

  @override
  Future<List<int>> pruneStaleEnabledEvents(DateTime now) async => [];

  @override
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status) async {}

  @override
  Future<void> updateAlarmEvent(AlarmEvent event) async {}

  @override
  Future<List<AlarmEvent>> getAlarmHistory() async => [];

  @override
  Future<void> purgeHistoryOlderThan(DateTime cutoff) async {}
}

final class _FakeLocalRepositoryWithStaleAlarms implements LocalRepository {
  final Map<String, ScheduleDraft> drafts = {};
  final Map<String, AlarmPlan> plans = {
    'plan-stale': AlarmPlan(
      id: 'plan-stale',
      scheduleId: 'draft-stale',
      createdAt: DateTime.utc(2026, 5, 14),
      alarms: [
        AlarmEvent(
          id: 'stale-alarm',
          planId: 'plan-stale',
          scheduledTime: DateTime.utc(2026, 5, 14, 9), // past
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          enabled: true,
          androidAlarmId: 100,
        ),
        AlarmEvent(
          id: 'stale-pre',
          planId: 'plan-stale',
          scheduledTime: DateTime.utc(2026, 5, 14, 8, 59), // past
          type: AlarmEventType.preWarning,
          toneProfile: ToneProfile.preBreak,
          enabled: true,
          androidAlarmId: 101,
        ),
        AlarmEvent(
          id: 'future-alarm',
          planId: 'plan-stale',
          scheduledTime: DateTime.utc(2026, 5, 20, 9), // future
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          enabled: true,
          androidAlarmId: 102,
        ),
      ],
    ),
  };

  @override
  Future<void> deleteDraft(String id) async => drafts.remove(id);

  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => drafts.values.toList();

  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async => plans.values
      .expand((plan) => plan.alarms)
      .where(
        (event) =>
            event.enabled &&
            event.status == AlarmEventStatus.scheduled &&
            event.scheduledTime.isAfter(DateTime.utc(2026, 5, 15)),
      )
      .toList();

  @override
  Future<List<AlarmPlan>> getAllPlans() async => plans.values.toList();

  @override
  Future<ScheduleDraft?> getDraft(String id) async => drafts[id];

  @override
  Future<List<AlarmEvent>> getEventsForPlan(String planId) async =>
      plans[planId]?.alarms ?? const [];

  @override
  Future<AlarmPlan?> getPlan(String id) async => plans[id];

  @override
  Future<void> saveDraft(ScheduleDraft draft) async => drafts[draft.id] = draft;

  @override
  Future<void> savePlan(AlarmPlan plan) async => plans[plan.id] = plan;

  @override
  Future<List<int>> pruneStaleEnabledEvents(DateTime now) async {
    // Simulate pruning: return stale native IDs
    return [100, 101];
  }

  @override
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status) async {}

  @override
  Future<void> updateAlarmEvent(AlarmEvent event) async {}

  @override
  Future<List<AlarmEvent>> getAlarmHistory() async => [];

  @override
  Future<void> purgeHistoryOlderThan(DateTime cutoff) async {}
}

final class _RecordingAlarmScheduler implements AlarmScheduler {
  final List<int> cancelledIds = [];
  final List<DateTime> pruneRequests = [];

  @override
  Future<int> schedule(AlarmEvent event) async => event.id.hashCode;

  @override
  Future<void> cancel(int nativeAlarmId) async {
    cancelledIds.add(nativeAlarmId);
  }

  @override
  Future<void> rescheduleAll(List<AlarmEvent> events) async {}

  @override
  Future<void> pruneNativeStaleAlarms(DateTime now) async {
    pruneRequests.add(now);
  }

  @override
  Future<List<Map<String, Object?>>> syncAlarmOutcomes() async => [];

  @override
  int nativeIdFor(AlarmEvent event) => event.id.hashCode;
}

final class _FakeTimer implements Timer {
  final void Function() onCancel;
  bool _isActive = true;

  _FakeTimer({required this.onCancel});

  @override
  void cancel() {
    _isActive = false;
    onCancel();
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;
}

final class _FakeRepositoryForSyncTest implements LocalRepository {
  final List<AlarmPlan> _plans;
  final Map<String, AlarmEventStatus> _statuses = {};
  final Map<String, DateTime?> _statusChangedAt = {};
  final List<String> callLog;

  _FakeRepositoryForSyncTest({
    required List<AlarmPlan> plans,
    List<String>? callOrder,
  }) : _plans = plans,
       callLog = callOrder ?? [];

  @override
  Future<List<AlarmPlan>> getAllPlans() async {
    callLog.add('getAllPlans');
    return _plans;
  }

  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async {
    callLog.add('getAllEnabledEvents');
    return _plans
        .expand((p) => p.alarms)
        .where((a) => a.enabled && (_statuses[a.id] ?? a.status) == AlarmEventStatus.scheduled)
        .toList();
  }

  @override
  Future<List<int>> pruneStaleEnabledEvents(DateTime now) async {
    callLog.add('pruneStaleEnabledEvents');
    final stale = await getAllEnabledEvents();
    final past = stale.where((a) => a.scheduledTime.isBefore(now)).toList();
    for (final a in past) {
      _statuses[a.id] = AlarmEventStatus.missed;
      _statusChangedAt[a.id] = now;
    }
    return past
        .where((a) => a.androidAlarmId != null)
        .map((a) => a.androidAlarmId!)
        .toList();
  }

  @override
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status) async {
    callLog.add('updateAlarmStatus');
    _statuses[id] = status;
    _statusChangedAt[id] = DateTime.now();
  }

  @override
  Future<void> updateAlarmEvent(AlarmEvent event) async {}

  @override
  Future<List<AlarmEvent>> getAlarmHistory() async {
    callLog.add('getAlarmHistory');
    final all = _plans.expand((p) => p.alarms).toList();
    return all
        .where((a) => (_statuses[a.id] ?? a.status) != AlarmEventStatus.scheduled)
        .map((a) => a.copyWith(
              status: _statuses[a.id] ?? a.status,
              statusChangedAt: _statusChangedAt[a.id],
            ))
        .toList();
  }

  @override
  Future<void> deleteDraft(String id) async {}
  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => [];
  @override
  Future<ScheduleDraft?> getDraft(String id) async => null;
  @override
  Future<List<AlarmEvent>> getEventsForPlan(String planId) async => [];
  @override
  Future<AlarmPlan?> getPlan(String id) async => null;
  @override
  Future<void> saveDraft(ScheduleDraft draft) async {}
  @override
  Future<void> savePlan(AlarmPlan plan) async {}
  @override
  Future<void> purgeHistoryOlderThan(DateTime cutoff) async {}
}

final class _FakeSchedulerWithOutcomes implements AlarmScheduler {
  final List<Map<String, Object?>> outcomes;
  final List<String> callLog;

  _FakeSchedulerWithOutcomes({
    required this.outcomes,
    List<String>? callOrder,
  }) : callLog = callOrder ?? [];

  @override
  int nativeIdFor(AlarmEvent event) => event.id.hashCode;

  @override
  Future<List<Map<String, Object?>>> syncAlarmOutcomes() async {
    callLog.add('syncAlarmOutcomes');
    return outcomes;
  }

  @override
  Future<int> schedule(AlarmEvent event) async => event.id.hashCode;
  @override
  Future<void> cancel(int nativeAlarmId) async {}
  @override
  Future<void> pruneNativeStaleAlarms(DateTime now) async {}
  @override
  Future<void> rescheduleAll(List<AlarmEvent> events) async {}
}
