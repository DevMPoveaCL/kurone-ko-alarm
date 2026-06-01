import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart' as domain;
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

  group('DriftLocalRepository alarm history', () {
    test('getAlarmHistory excludes scheduled events', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      final plan = domain.AlarmPlan(
        id: 'plan-history',
        scheduleId: 'draft-history',
        createdAt: now,
        alarms: [
          domain.AlarmEvent(
            id: 'scheduled-alarm',
            planId: 'plan-history',
            scheduledTime: DateTime.utc(2026, 6, 2, 9),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.scheduled,
          ),
          domain.AlarmEvent(
            id: 'fired-alarm',
            planId: 'plan-history',
            scheduledTime: DateTime.utc(2026, 6, 1, 8),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.fired,
            statusChangedAt: DateTime.utc(2026, 6, 1, 8, 1),
          ),
          domain.AlarmEvent(
            id: 'dismissed-alarm',
            planId: 'plan-history',
            scheduledTime: DateTime.utc(2026, 6, 1, 10),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.dismissed,
            statusChangedAt: DateTime.utc(2026, 6, 1, 10, 2),
          ),
        ],
      );
      await repository.savePlan(plan);

      final history = await repository.getAlarmHistory();

      expect(history.map((e) => e.id), containsAll(['fired-alarm', 'dismissed-alarm']));
      expect(history.map((e) => e.id), isNot(contains('scheduled-alarm')));
    });

    test('updateAlarmStatus sets status and timestamp', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      final plan = domain.AlarmPlan(
        id: 'plan-update',
        scheduleId: 'draft-update',
        createdAt: now,
        alarms: [
          domain.AlarmEvent(
            id: 'to-dismiss',
            planId: 'plan-update',
            scheduledTime: DateTime.utc(2026, 6, 1, 9),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
          ),
        ],
      );
      await repository.savePlan(plan);

      await repository.updateAlarmStatus(
        'to-dismiss',
        domain.AlarmEventStatus.dismissed,
      );

      final history = await repository.getAlarmHistory();
      final updated = history.firstWhere((e) => e.id == 'to-dismiss');
      expect(updated.status, domain.AlarmEventStatus.dismissed);
      expect(updated.statusChangedAt, isNotNull);
    });

    test(
      'getAllEnabledEvents excludes dismissed and fired alarms from active list',
      () async {
        final now = DateTime.utc(2026, 6, 1, 12);
        final plan = domain.AlarmPlan(
          id: 'plan-active',
          scheduleId: 'draft-active',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'scheduled-future',
              planId: 'plan-active',
              scheduledTime: DateTime.utc(2026, 6, 2, 9),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              status: domain.AlarmEventStatus.scheduled,
              enabled: true,
            ),
            domain.AlarmEvent(
              id: 'dismissed-future',
              planId: 'plan-active',
              scheduledTime: DateTime.utc(2026, 6, 2, 10),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              status: domain.AlarmEventStatus.dismissed,
              enabled: true,
              statusChangedAt: DateTime.utc(2026, 6, 1, 10, 2),
            ),
            domain.AlarmEvent(
              id: 'fired-future',
              planId: 'plan-active',
              scheduledTime: DateTime.utc(2026, 6, 2, 11),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              status: domain.AlarmEventStatus.fired,
              enabled: true,
              statusChangedAt: DateTime.utc(2026, 6, 1, 11, 1),
            ),
          ],
        );
        await repository.savePlan(plan);

        final active = await repository.getAllEnabledEvents();
        expect(active.map((e) => e.id), ['scheduled-future']);
        expect(active, isNot(contains('dismissed-future')));
        expect(active, isNot(contains('fired-future')));
      },
    );

    test(
      'updateAlarmStatus disables alarm when changing to dismissed or fired',
      () async {
        final now = DateTime.utc(2026, 6, 1, 12);
        final plan = domain.AlarmPlan(
          id: 'plan-disable',
          scheduleId: 'draft-disable',
          createdAt: now,
          alarms: [
            domain.AlarmEvent(
              id: 'to-dismiss',
              planId: 'plan-disable',
              scheduledTime: DateTime.utc(2026, 6, 2, 9),
              type: domain.AlarmEventType.main,
              toneProfile: domain.ToneProfile.breakStart,
              enabled: true,
            ),
          ],
        );
        await repository.savePlan(plan);

        await repository.updateAlarmStatus(
          'to-dismiss',
          domain.AlarmEventStatus.dismissed,
        );

        final active = await repository.getAllEnabledEvents();
        expect(active.map((e) => e.id), isNot(contains('to-dismiss')));

        final history = await repository.getAlarmHistory();
        final updated = history.firstWhere((e) => e.id == 'to-dismiss');
        expect(updated.status, domain.AlarmEventStatus.dismissed);
        expect(updated.enabled, isFalse);
      },
    );

    test('purgeHistoryOlderThan removes entries older than cutoff', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      final plan = domain.AlarmPlan(
        id: 'plan-purge',
        scheduleId: 'draft-purge',
        createdAt: now,
        alarms: [
          domain.AlarmEvent(
            id: 'old-fired',
            planId: 'plan-purge',
            scheduledTime: DateTime.utc(2026, 5, 31, 8),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.fired,
            statusChangedAt: DateTime.utc(2026, 5, 31, 8, 1),
          ),
          domain.AlarmEvent(
            id: 'recent-dismissed',
            planId: 'plan-purge',
            scheduledTime: DateTime.utc(2026, 6, 1, 10),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.dismissed,
            statusChangedAt: DateTime.utc(2026, 6, 1, 10, 2),
          ),
        ],
      );
      await repository.savePlan(plan);

      final cutoff = DateTime.utc(2026, 6, 1, 0);
      await repository.purgeHistoryOlderThan(cutoff);

      final history = await repository.getAlarmHistory();
      expect(history.map((e) => e.id), ['recent-dismissed']);
    });

    test('pruneStaleEnabledEvents only marks scheduled alarms as missed', () async {
      final now = DateTime.utc(2026, 6, 1, 12);
      final plan = domain.AlarmPlan(
        id: 'plan-prune',
        scheduleId: 'draft-prune',
        createdAt: now,
        alarms: [
          domain.AlarmEvent(
            id: 'scheduled-past',
            planId: 'plan-prune',
            scheduledTime: DateTime.utc(2026, 5, 31, 8),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.scheduled,
          ),
          domain.AlarmEvent(
            id: 'dismissed-past',
            planId: 'plan-prune',
            scheduledTime: DateTime.utc(2026, 5, 31, 9),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.dismissed,
            statusChangedAt: DateTime.utc(2026, 5, 31, 9, 1),
          ),
          domain.AlarmEvent(
            id: 'fired-past',
            planId: 'plan-prune',
            scheduledTime: DateTime.utc(2026, 5, 31, 10),
            type: domain.AlarmEventType.main,
            toneProfile: domain.ToneProfile.breakStart,
            status: domain.AlarmEventStatus.fired,
            statusChangedAt: DateTime.utc(2026, 5, 31, 10, 1),
          ),
        ],
      );
      await repository.savePlan(plan);

      final prunedIds = await repository.pruneStaleEnabledEvents(now);
      expect(prunedIds, isEmpty);

      final history = await repository.getAlarmHistory();
      final scheduledPast = history.firstWhere((e) => e.id == 'scheduled-past');
      final dismissedPast = history.firstWhere((e) => e.id == 'dismissed-past');
      final firedPast = history.firstWhere((e) => e.id == 'fired-past');

      expect(scheduledPast.status, domain.AlarmEventStatus.missed);
      expect(dismissedPast.status, domain.AlarmEventStatus.dismissed);
      expect(firedPast.status, domain.AlarmEventStatus.fired);
    });
  });
}
