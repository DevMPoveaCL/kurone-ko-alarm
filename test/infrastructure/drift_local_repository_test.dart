import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart' as domain;
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/database.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/drift_local_repository.dart';

void main() {
  late AppDatabase database;
  late DriftLocalRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftLocalRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DriftLocalRepository stale alarm pruning', () {
    test(
      'pruneStaleEnabledEvents disables enabled alarms with scheduledTime in the past',
      () async {
        final now = DateTime.utc(2026, 5, 15, 12, 0);
        final pastPlan = domain.AlarmPlan(
          id: 'plan-past',
          scheduleId: 'draft-past',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'stale-alarm',
              planId: 'plan-past',
              scheduledTime: DateTime.utc(2026, 5, 14, 9), // past
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
              androidAlarmId: 100,
            ),
            domain.AlarmEvent(
              id: 'stale-pre',
              planId: 'plan-past',
              scheduledTime: DateTime.utc(2026, 5, 14, 8, 59), // past
              type: domain.AlarmEventType.preWarning,
              toneProfile: domain.ToneProfile.preBreak,
              enabled: true,
              androidAlarmId: 101,
            ),
            domain.AlarmEvent(
              id: 'future-alarm',
              planId: 'plan-past',
              scheduledTime: DateTime.utc(2026, 5, 16, 9), // future
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
              androidAlarmId: 102,
            ),
            domain.AlarmEvent(
              id: 'past-but_disabled',
              planId: 'plan-past',
              scheduledTime: DateTime.utc(2026, 5, 14, 10), // past but disabled
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: false,
              androidAlarmId: 103,
            ),
          ],
        );
        await repository.savePlan(pastPlan);

        // Prune stale alarms
        final prunedIds = await repository.pruneStaleEnabledEvents(now);

        // Should return the androidAlarmIds of cancelled stale alarms
        expect(prunedIds, hasLength(2));
        expect(prunedIds, contains(100));
        expect(prunedIds, contains(101));

        // Future alarm must remain active
        final remaining = await repository.getAllEnabledEvents();
        expect(remaining.map((e) => e.id), ['future-alarm']);

        // Past-but-disabled also remains in DB (inert, not pruned)
        final eventsForPlan = await repository.getEventsForPlan('plan-past');
        final allIds = eventsForPlan.map((e) => e.id).toList();
        expect(allIds, contains('past-but_disabled'));
        expect(allIds, contains('future-alarm'));

        // Stale enabled alarms no longer appear in getAllEnabledEvents
        expect(remaining.map((e) => e.id), isNot(contains('stale-alarm')));
        expect(remaining.map((e) => e.id), isNot(contains('stale-pre')));

        // They still physically exist in DB (soft-deleted: enabled=false)
        final stillInDb = await repository.getEventsForPlan('plan-past');
        final staleInDb = stillInDb
            .where((e) => e.id == 'stale-alarm' || e.id == 'stale-pre')
            .toList();
        expect(staleInDb, hasLength(2));
        // Both stale alarms are now disabled (soft-deleted)
        expect(staleInDb.every((e) => !e.enabled), isTrue);
      },
    );

    test(
      'pruneStaleEnabledEvents marks stale alarms as missed and makes them visible in history',
      () async {
        final now = DateTime.utc(2026, 5, 15, 12, 0);
        final plan = domain.AlarmPlan(
          id: 'plan-history',
          scheduleId: 'draft-history',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'stale-main',
              planId: 'plan-history',
              scheduledTime: DateTime.utc(2026, 5, 14, 12, 30),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
              androidAlarmId: 400,
            ),
            domain.AlarmEvent(
              id: 'stale-pre',
              planId: 'plan-history',
              scheduledTime: DateTime.utc(2026, 5, 14, 12, 29),
              type: domain.AlarmEventType.preWarning,
              toneProfile: domain.ToneProfile.preBreak,
              enabled: true,
              androidAlarmId: 401,
            ),
            domain.AlarmEvent(
              id: 'future-main',
              planId: 'plan-history',
              scheduledTime: DateTime.utc(2026, 5, 16, 9),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
            ),
          ],
        );
        await repository.savePlan(plan);

        await repository.pruneStaleEnabledEvents(now);

        final history = await repository.getAlarmHistory();
        expect(history.map((e) => e.id), containsAll(['stale-main', 'stale-pre']));
        expect(history.every((e) => e.status == domain.AlarmEventStatus.missed), isTrue);
        expect(history.every((e) => e.statusChangedAt != null), isTrue);

        final future = history.where((e) => e.id == 'future-main');
        expect(future, isEmpty);
      },
    );

    test(
      'pruneStaleEnabledEvents returns empty list when no stale alarms exist',
      () async {
        final now = DateTime.utc(2026, 5, 15, 12, 0);
        final plan = domain.AlarmPlan(
          id: 'plan-future',
          scheduleId: 'draft-future',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'future-main',
              planId: 'plan-future',
              scheduledTime: DateTime.utc(2026, 5, 16, 9),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
              androidAlarmId: 200,
            ),
          ],
        );
        await repository.savePlan(plan);

        final prunedIds = await repository.pruneStaleEnabledEvents(now);

        expect(prunedIds, isEmpty);
        final remaining = await repository.getAllEnabledEvents();
        expect(remaining.map((e) => e.id), ['future-main']);
      },
    );

    test(
      'pruneStaleEnabledEvents returns IDs of stale alarms including pre-warnings',
      () async {
        final now = DateTime.utc(2026, 5, 15, 12, 0);
        final plan = domain.AlarmPlan(
          id: 'plan-mixed',
          scheduleId: 'draft-mixed',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'stale-main',
              planId: 'plan-mixed',
              scheduledTime: DateTime.utc(2026, 5, 14, 12, 30),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
              androidAlarmId: 300,
            ),
            domain.AlarmEvent(
              id: 'stale-pre',
              planId: 'plan-mixed',
              scheduledTime: DateTime.utc(2026, 5, 14, 12, 29),
              type: domain.AlarmEventType.preWarning,
              toneProfile: domain.ToneProfile.preBreak,
              enabled: true,
              androidAlarmId: 301,
            ),
          ],
        );
        await repository.savePlan(plan);

        final prunedIds = await repository.pruneStaleEnabledEvents(now);

        expect(prunedIds, hasLength(2));
        expect(prunedIds, containsAll([300, 301]));
      },
    );
  });

  group('DriftLocalRepository drafts', () {
    test(
      'persists and reads schedule drafts with raw entries and confidence metadata',
      () async {
        final draft = domain.ScheduleDraft(
          id: 'draft-1',
          source: ImportSource.excel,
          createdAt: DateTime.utc(2026, 5, 13, 9, 30),
          entries: const [
            domain.RawEntry(
              id: 'entry-1',
              source: ImportSource.excel,
              fields: {'entrada': '09:00', 'descanso': '13:00'},
              confidence: Confidence.low(
                reason: 'merged cells',
                ambiguousColumns: ['descanso'],
              ),
            ),
          ],
        );

        await repository.saveDraft(draft);

        final saved = await repository.getDraft('draft-1');

        expect(saved?.id, 'draft-1');
        expect(saved?.source, ImportSource.excel);
        expect(saved?.createdAt, DateTime.utc(2026, 5, 13, 9, 30));
        expect(saved?.entries, hasLength(1));
        expect(saved?.entries.single.fields, {
          'entrada': '09:00',
          'descanso': '13:00',
        });
        expect(saved?.entries.single.confidence.level, ConfidenceLevel.low);
        expect(saved?.entries.single.confidence.reason, 'merged cells');
        expect(saved?.entries.single.confidence.ambiguousColumns, ['descanso']);
      },
    );

    test('deletes only the requested draft', () async {
      await repository.saveDraft(
        domain.ScheduleDraft(
          id: 'keep',
          source: ImportSource.image,
          createdAt: DateTime.utc(2026, 5, 13, 8),
          entries: const [],
        ),
      );
      await repository.saveDraft(
        domain.ScheduleDraft(
          id: 'delete-me',
          source: ImportSource.excel,
          createdAt: DateTime.utc(2026, 5, 13, 9),
          entries: const [],
        ),
      );

      await repository.deleteDraft('delete-me');
      final drafts = await repository.getAllDrafts();

      expect(await repository.getDraft('delete-me'), isNull);
      expect(drafts.map((draft) => draft.id), ['keep']);
    });
  });

  group('DriftLocalRepository alarm plans', () {
    test('persists plans together with their alarm events', () async {
      final localScheduledTime = DateTime(2026, 5, 13, 13);
      final plan = domain.AlarmPlan(
        id: 'plan-1',
        scheduleId: 'draft-1',
        createdAt: DateTime.utc(2026, 5, 13, 10),
        alarms: [
          domain.AlarmEvent(
            id: 'main-1',
            planId: 'plan-1',
            scheduledTime: localScheduledTime,
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            androidAlarmId: 42,
          ),
          domain.AlarmEvent(
            id: 'pre-1',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 13, 12, 59),
            type: domain.AlarmEventType.preWarning,
            toneProfile: domain.ToneProfile.preBreak,
            enabled: false,
          ),
        ],
      );

      await repository.savePlan(plan);

      final saved = await repository.getPlan('plan-1');
      final events = await repository.getEventsForPlan('plan-1');
      final enabled = await repository.getAllEnabledEvents();

      expect(saved?.id, 'plan-1');
      expect(saved?.scheduleId, 'draft-1');
      expect(saved?.createdAt, DateTime.utc(2026, 5, 13, 10));
      expect(saved?.alarms.map((alarm) => alarm.id), ['main-1', 'pre-1']);
      expect(events.map((alarm) => alarm.id), ['main-1', 'pre-1']);
      expect(events.first.type, domain.AlarmEventType.main);
      expect(events.first.toneProfile, domain.ToneProfile.breakStart);
      expect(events.first.scheduledTime, localScheduledTime);
      expect(events.first.scheduledTime.isUtc, isFalse);
      expect(events.first.androidAlarmId, 42);
      expect(events.last.enabled, isFalse);
      expect(enabled.map((alarm) => alarm.id), ['main-1']);
    });

    test('updateAlarmEvent changes only the targeted alarm fields', () async {
      final plan = domain.AlarmPlan(
        id: 'plan-update',
        scheduleId: 'draft-update',
        createdAt: DateTime(2026, 5, 13, 10),
        alarms: [
          domain.AlarmEvent(
            id: 'main-1',
            planId: 'plan-update',
            scheduledTime: DateTime(2026, 5, 13, 8),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            purpose: domain.AlarmEventPurpose.breakStart,
            sourceFieldKey: 'breakStart',
            androidAlarmId: 100,
          ),
          domain.AlarmEvent(
            id: 'main-2',
            planId: 'plan-update',
            scheduledTime: DateTime(2026, 5, 13, 15),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            purpose: domain.AlarmEventPurpose.breakStart,
            sourceFieldKey: 'secondBreakStart',
            androidAlarmId: 200,
          ),
        ],
      );
      await repository.savePlan(plan);

      final updated = domain.AlarmEvent(
        id: 'main-1',
        planId: 'plan-update',
        scheduledTime: DateTime(2026, 5, 13, 9, 30),
        type: domain.AlarmEventType.main,
        toneProfile: domain.ToneProfile.breakStart,
        purpose: domain.AlarmEventPurpose.breakStart,
        sourceFieldKey: 'breakStart',
        androidAlarmId: 100,
        status: domain.AlarmEventStatus.scheduled,
      );
      await repository.updateAlarmEvent(updated);

      final loaded = await repository.getPlan('plan-update');
      final alarms = loaded!.alarms;
      expect(alarms, hasLength(2));

      final first = alarms.firstWhere((a) => a.id == 'main-1');
      expect(first.scheduledTime, DateTime(2026, 5, 13, 9, 30));
      expect(first.androidAlarmId, 100);
      expect(first.sourceFieldKey, 'breakStart');

      final second = alarms.firstWhere((a) => a.id == 'main-2');
      expect(second.scheduledTime, DateTime(2026, 5, 13, 15));
      expect(second.androidAlarmId, 200);
      expect(second.sourceFieldKey, 'secondBreakStart');
    });

    test('persists purpose and sourceFieldKey for label correctness', () async {
      final plan = domain.AlarmPlan(
        id: 'plan-fields',
        scheduleId: 'draft-fields',
        createdAt: DateTime.utc(2026, 5, 13, 10),
        alarms: [
          domain.AlarmEvent(
            id: 'main-start',
            planId: 'plan-fields',
            scheduledTime: DateTime.utc(2026, 5, 13, 8),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            purpose: domain.AlarmEventPurpose.shiftStart,
            sourceFieldKey: 'startTime',
          ),
          domain.AlarmEvent(
            id: 'main-second-break',
            planId: 'plan-fields',
            scheduledTime: DateTime.utc(2026, 5, 13, 15),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            purpose: domain.AlarmEventPurpose.breakStart,
            sourceFieldKey: 'secondBreakStart',
          ),
        ],
      );

      await repository.savePlan(plan);
      final loaded = await repository.getPlan('plan-fields');
      final alarms = loaded!.alarms;

      expect(alarms.first.purpose, domain.AlarmEventPurpose.shiftStart);
      expect(alarms.first.sourceFieldKey, 'startTime');
      expect(alarms.last.purpose, domain.AlarmEventPurpose.breakStart);
      expect(alarms.last.sourceFieldKey, 'secondBreakStart');
    });
  });
}
