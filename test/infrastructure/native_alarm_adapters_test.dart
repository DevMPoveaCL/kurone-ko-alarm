import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/alarm/native_alarm_scheduler.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/permissions/android_permission_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.kuroneko.alarm/scheduler');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'scheduleAlarm' => 99,
            'hasExactAlarmPermission' => true,
            'requestExactAlarmPermission' => false,
            'hasNotificationPermission' => true,
            'requestNotificationPermission' => false,
            'requestBatteryOptimizationExemption' => true,
            'hasFullScreenIntentPermission' => true,
            'requestFullScreenIntentPermission' => false,
            'syncAlarmOutcomes' => '[{"id":42,"status":"dismissed","atMillis":1717200000000}]',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NativeAlarmScheduler', () {
    test(
      'sends main alarm scheduling requests through the scheduler channel',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final event = AlarmEvent(
          id: 'alarm-main-1',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 13),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          androidAlarmId: 42,
        );

        final nativeId = await scheduler.schedule(event);

        expect(nativeId, 99);
        expect(calls.single.method, 'scheduleAlarm');
        expect(calls.single.arguments, {
          'id': 42,
          'millis': DateTime.utc(2026, 5, 14, 13).millisecondsSinceEpoch,
          'channelId': 'break_alarms',
          'eventType': 'main',
          'scheduleMode': 'alarmClock',
          'title': 'Alarma: Break Inicio',
          'body': 'El descanso empieza ahora.',
          'purpose': 'breakStart',
          'breakOrdinal': null,
          'ringUntilDismissed': true,
          'autoStopMillis': 300000,
          'showFullScreenAlarm': true,
          'dismissAction': 'com.kuroneko.kurone_ko_alarm.DISMISS_ALARM',
          'prewarningId': NativeAlarmScheduler.computeNativeId(
            event.preWarningFor(),
          ),
        });
      },
    );

    test(
      'uses the pre-warning channel and generated stable native IDs when no Android ID exists',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final event = AlarmEvent(
          id: 'alarm-pre-1',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 59),
          type: AlarmEventType.preWarning,
          toneProfile: ToneProfile.preBreak,
        );

        await scheduler.schedule(event);
        final args = calls.single.arguments as Map<Object?, Object?>;

        expect(args['id'], NativeAlarmScheduler.computeNativeId(event));
        expect(args['channelId'], 'pre_break_warnings');
        expect(args['eventType'], 'preWarning');
        expect(args['scheduleMode'], 'exactNotification');
        expect(args['title'], 'Preaviso: Break Inicio');
        expect(args['body'], 'Prepara el inicio de tu descanso.');
        expect(args['ringUntilDismissed'], isFalse);
        expect(args['autoStopMillis'], 0);
        expect(args['showFullScreenAlarm'], isFalse);
      },
    );

    test(
      'uses the main alarm flow even when the tone profile is not enough to infer it',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final event = AlarmEvent(
          id: 'alarm-main-explicit-type',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 15),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.preBreak,
        );

        await scheduler.schedule(event);
        final args = calls.single.arguments as Map<Object?, Object?>;

        expect(args['eventType'], 'main');
        expect(args['scheduleMode'], 'alarmClock');
        expect(args['channelId'], 'break_alarms');
        expect(args['ringUntilDismissed'], isTrue);
        expect(args['autoStopMillis'], 300000);
        expect(args['showFullScreenAlarm'], isTrue);
      },
    );

    test(
      'uses contextual Spanish copy for break end and its pre-warning',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final main = AlarmEvent(
          id: 'break-end-main',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 45),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          purpose: AlarmEventPurpose.breakEnd,
        );
        final preWarning = main.preWarningFor();

        await scheduler.schedule(main);
        await scheduler.schedule(preWarning);

        final mainArgs = calls.first.arguments as Map<Object?, Object?>;
        final preArgs = calls.last.arguments as Map<Object?, Object?>;
        expect(mainArgs['title'], 'Alarma: Break Término');
        expect(
          mainArgs['body'],
          'El descanso terminó. Vuelve a tus actividades.',
        );
        expect(preArgs['title'], 'Preaviso: Break Término');
        expect(preArgs['body'], 'Prepara el regreso a tus actividades.');
      },
    );

    test(
      'uses contextual Spanish copy for lunch start and lunch end',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);

        await scheduler.schedule(
          AlarmEvent(
            id: 'lunch-start',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 14, 13),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.lunchStart,
          ),
        );
        await scheduler.schedule(
          AlarmEvent(
            id: 'lunch-end',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 14, 14),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.lunchEnd,
          ),
        );

        final startArgs = calls.first.arguments as Map<Object?, Object?>;
        final endArgs = calls.last.arguments as Map<Object?, Object?>;
        expect(startArgs['title'], 'Alarma: Inicio Almuerzo');
        expect(startArgs['body'], 'El almuerzo empieza ahora.');
        expect(endArgs['title'], 'Alarma: Término Almuerzo');
        expect(
          endArgs['body'],
          'El almuerzo terminó. Vuelve a tus actividades.',
        );
      },
    );

    test(
      'uses contextual Spanish copy for shift boundaries and lunch extension end',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);

        await scheduler.schedule(
          AlarmEvent(
            id: 'shift-start',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 14),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.shiftStart,
          ),
        );
        await scheduler.schedule(
          AlarmEvent(
            id: 'lunch-extension-end',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 14, 5, 45),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.lunchExtensionEnd,
          ),
        );
        await scheduler.schedule(
          AlarmEvent(
            id: 'shift-end',
            planId: 'plan-1',
            scheduledTime: DateTime.utc(2026, 5, 14, 10),
            type: AlarmEventType.main,
            toneProfile: ToneProfile.breakStart,
            purpose: AlarmEventPurpose.shiftEnd,
          ),
        );

        final shiftStartArgs = calls[0].arguments as Map<Object?, Object?>;
        final extensionEndArgs = calls[1].arguments as Map<Object?, Object?>;
        final shiftEndArgs = calls[2].arguments as Map<Object?, Object?>;
        expect(shiftStartArgs['title'], 'Alarma: Inicio Turno');
        expect(shiftStartArgs['body'], 'Tu turno empieza ahora.');
        expect(extensionEndArgs['title'], 'Alarma: Término Almuerzo Extendido');
        expect(
          extensionEndArgs['body'],
          'El almuerzo extendido terminó. Vuelve a tus actividades.',
        );
        expect(shiftEndArgs['title'], 'Alarma: Fin Turno');
        expect(shiftEndArgs['body'], 'Tu turno terminó.');
      },
    );

    test(
      'all main alarm purposes use the same full-screen ringing payload',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);

        for (final purpose in AlarmEventPurpose.values) {
          await scheduler.schedule(
            AlarmEvent(
              id: 'main-${purpose.name}',
              planId: 'plan-1',
              scheduledTime: DateTime.utc(2026, 5, 14, 13),
              type: AlarmEventType.main,
              toneProfile: ToneProfile.breakStart,
              purpose: purpose,
            ),
          );
        }

        expect(calls, hasLength(AlarmEventPurpose.values.length));
        for (final call in calls) {
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['showFullScreenAlarm'], isTrue);
          expect(args['ringUntilDismissed'], isTrue);
          expect(args['scheduleMode'], 'alarmClock');
          expect(args['channelId'], 'break_alarms');
          expect(args['autoStopMillis'], 300000);
        }
      },
    );

    test(
      'sets showFullScreenAlarm to false when full-screen intent permission is denied',
      () async {
        final scheduler = NativeAlarmScheduler(
          channel: channel,
          hasFullScreenIntentPermission: () async => false,
        );
        final event = AlarmEvent(
          id: 'main-denied',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 13),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
        );

        await scheduler.schedule(event);
        final args = calls.single.arguments as Map<Object?, Object?>;

        expect(args['showFullScreenAlarm'], isFalse);
      },
    );

    test(
      'cancels one native alarm and reschedules enabled alarms only',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final enabled = AlarmEvent(
          id: 'enabled',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 13),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
        );
        final disabled = AlarmEvent(
          id: 'disabled',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 14),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          enabled: false,
        );

        await scheduler.cancel(42);
        await scheduler.rescheduleAll([enabled, disabled]);

        expect(calls.map((call) => call.method), [
          'cancelAlarm',
          'scheduleAlarm',
        ]);
        expect(calls.first.arguments, {'id': 42});
        final scheduleArgs = calls.last.arguments as Map<Object?, Object?>;
        expect(scheduleArgs['id'], NativeAlarmScheduler.computeNativeId(enabled));
        expect(
          scheduleArgs['millis'],
          enabled.scheduledTime.millisecondsSinceEpoch,
        );
      },
    );

    test(
      'rescheduleAll computes break ordinals and passes them through title',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final break1Start = AlarmEvent(
          id: 'break1-start',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 10),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          purpose: AlarmEventPurpose.breakStart,
          sourceFieldKey: 'breakStart',
        );
        final break1End = AlarmEvent(
          id: 'break1-end',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 10, 15),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          purpose: AlarmEventPurpose.breakEnd,
          sourceFieldKey: 'breakEnd',
        );
        final break2Start = AlarmEvent(
          id: 'break2-start',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 14),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
          purpose: AlarmEventPurpose.breakStart,
          sourceFieldKey: 'secondBreakStart',
        );

        await scheduler.rescheduleAll([break1Start, break1End, break2Start]);

        final titles = calls
            .where((c) => c.method == 'scheduleAlarm')
            .map((c) => (c.arguments as Map<Object?, Object?>)['title'] as String)
            .toList();
        expect(titles, [
          'Alarma: 1° Break Inicio',
          'Alarma: 1° Break Término',
          'Alarma: 2° Break Inicio',
        ]);
      },
    );

    test(
      'delegates native boot reschedule requests through the channel',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);

        await scheduler.rescheduleAllOnBoot();

        expect(calls.single.method, 'rescheduleAllOnBoot');
        expect(calls.single.arguments, isNull);
      },
    );

    test(
      'delegates native stale-alarm pruning with the current time',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final now = DateTime.utc(2026, 5, 20, 10, 30);

        await scheduler.pruneNativeStaleAlarms(now);

        expect(calls.single.method, 'pruneStaleAlarms');
        expect(calls.single.arguments, {
          'nowMillis': now.millisecondsSinceEpoch,
        });
      },
    );

    test(
      'reads and parses alarm outcomes from the native log',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);

        final outcomes = await scheduler.syncAlarmOutcomes();

        expect(calls.single.method, 'syncAlarmOutcomes');
        expect(outcomes, hasLength(1));
        expect(outcomes.first['id'], 42);
        expect(outcomes.first['status'], 'dismissed');
        expect(outcomes.first['atMillis'], 1717200000000);
      },
    );
  });

  group('AndroidPermissionGateway', () {
    test(
      'delegates exact alarm and battery optimization permission requests to Android',
      () async {
        final gateway = AndroidPermissionGateway(channel: channel);

        final hasExact = await gateway.hasExactAlarmPermission();
        final exactRequested = await gateway.requestExactAlarm();
        final hasNotifications = await gateway.hasNotificationPermission();
        final notificationsRequested = await gateway
            .requestNotificationPermission();
        final batteryRequested = await gateway.requestBatteryOptimization();

        expect(hasExact, isTrue);
        expect(exactRequested, isFalse);
        expect(hasNotifications, isTrue);
        expect(notificationsRequested, isFalse);
        expect(batteryRequested, isTrue);
        expect(calls.map((call) => call.method), [
          'hasExactAlarmPermission',
          'requestExactAlarmPermission',
          'hasNotificationPermission',
          'requestNotificationPermission',
          'requestBatteryOptimizationExemption',
        ]);
      },
    );

    test(
      'delegates full-screen intent permission requests to Android',
      () async {
        final gateway = AndroidPermissionGateway(channel: channel);

        final hasFullScreen = await gateway.hasFullScreenIntentPermission();
        final requestedFullScreen = await gateway
            .requestFullScreenIntentPermission();

        expect(hasFullScreen, isTrue);
        expect(requestedFullScreen, isFalse);
        expect(calls.map((call) => call.method), [
          'hasFullScreenIntentPermission',
          'requestFullScreenIntentPermission',
        ]);
      },
    );

    test(
      'main alarm schedule passes a prewarningId distinct from its own id',
      () async {
        final scheduler = NativeAlarmScheduler(channel: channel);
        final main = AlarmEvent(
          id: 'break-main-1',
          planId: 'plan-1',
          scheduledTime: DateTime.utc(2026, 5, 14, 13),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
        );

        await scheduler.schedule(main);
        final args = calls.single.arguments as Map<Object?, Object?>;

        expect(args['prewarningId'], isNotNull);
        expect(args['prewarningId'], isNot(equals(args['id'])));
      },
    );
  });
}
