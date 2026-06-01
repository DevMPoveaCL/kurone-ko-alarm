import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/import_schedule.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/presentation/providers/import_flow_controller.dart';
import 'package:kurone_ko_alarm/presentation/screens/import_screen.dart';
import 'package:kurone_ko_alarm/presentation/widgets/alarm_timeline.dart';

void main() {
  testWidgets(
    'import screen shows calm source selection and review-ready checklist',
    (tester) async {
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: _FakeReviewUseCase(),
        ),
      );

      expect(find.text('Kurone-ko Alarm'), findsOneWidget);
      expect(find.text('Importar Excel'), findsOneWidget);
      expect(find.text('Importar imagen'), findsOneWidget);
      expect(find.text('Sin alarmas programadas todavía'), findsOneWidget);

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();

      expect(find.text('Revisión lista'), findsOneWidget);
      expect(find.text('turno.xlsx'), findsOneWidget);
      expect(find.text('Mika'), findsOneWidget);
      expect(find.text('20-MAYO-2026'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
      expect(find.text('12:45'), findsOneWidget);
      expect(find.text('Revisar'), findsOneWidget);
      expect(find.text('Preaviso 12:29'), findsOneWidget);
      expect(find.text('Alarma 12:30'), findsOneWidget);
      expect(find.text('Preaviso 12:44'), findsOneWidget);
      expect(find.text('Alarma 12:45'), findsOneWidget);
    },
  );

  testWidgets('import UI uses neutral Spanish instead of voseo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'turno.xlsx',
            fileName: 'turno.xlsx',
          ),
        ),
        importUseCase: _FakeImportUseCase(draft: _draft()),
        reviewUseCase: _FakeReviewUseCase(),
      ),
    );

    expect(
      find.text(
        'Importa tus descansos, revisa cada fila y confirma solo cuando el horario esté claro.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Elige la fuente que tienes a mano. Todo se procesa localmente en el dispositivo.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Importá'), findsNothing);
    expect(find.textContaining('revisá'), findsNothing);
    expect(find.textContaining('confirmá'), findsNothing);
    expect(find.textContaining('Elegí'), findsNothing);
    expect(find.textContaining('tenés'), findsNothing);

    final appAndNativeSource =
        [Directory('lib'), Directory('android/app/src/main')]
            .expand((directory) => directory.listSync(recursive: true))
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.dart') ||
                  file.path.endsWith('.kt') ||
                  file.path.endsWith('.xml'),
            )
            .map((file) => file.readAsStringSync())
            .join('\n');
    for (final banned in [
      'Prepará',
      'Importá',
      'revisá',
      'confirmá',
      'Elegí',
      'tenés',
      'necesitás',
      'habilitá',
      'volvé',
      'Revisá',
      'Agregá',
    ]) {
      expect(appAndNativeSource, isNot(contains(banned)), reason: banned);
    }
  });

  testWidgets('review screen allows correction before explicit confirmation', (
    tester,
  ) async {
    final reviewUseCase = _FakeReviewUseCase();
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'turno.xlsx',
            fileName: 'turno.xlsx',
          ),
        ),
        importUseCase: _FakeImportUseCase(draft: _draft()),
        reviewUseCase: reviewUseCase,
      ),
    );

    await tester.tap(find.text('Importar Excel'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-1-breakStart')),
      '12:45',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -560));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Cargado con éxito en alarmas activas'), findsOneWidget);
    expect(find.text('2 alarmas preparadas para programación'), findsNothing);
    expect(
      reviewUseCase.confirmedDraft?.entries.single.fields['breakStart'],
      '12:45',
    );
  });

  testWidgets('import errors are visible and offer manual fallback guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(path: 'bad.xlsx', fileName: 'bad.xlsx'),
        ),
        importUseCase: _FakeImportUseCase(error: Exception('archivo corrupto')),
        reviewUseCase: _FakeReviewUseCase(),
      ),
    );

    await tester.tap(find.text('Importar Excel'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos importar el horario'), findsOneWidget);
    expect(find.textContaining('archivo corrupto'), findsOneWidget);
    expect(find.text('Cargar manualmente'), findsOneWidget);
  });

  testWidgets('review screen limits eager editable cards for large imports', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'captura.png',
            fileName: 'captura.png',
          ),
        ),
        importUseCase: _FakeImportUseCase(draft: _largeDraft(entryCount: 80)),
        reviewUseCase: _FakeReviewUseCase(),
      ),
    );

    await tester.tap(find.text('Importar imagen'));
    await tester.pumpAndSettle();

      expect(find.text('Revisión lista'), findsOneWidget);
      expect(find.text('Mostrando 24 de 80 filas detectadas.'), findsOneWidget);
      // date + startTime + breakStart + endTime = 4 fields per entry
      expect(find.byType(TextFormField), findsNWidgets(96));
      expect(find.text('Sin nombre'), findsNWidgets(24));
  });

  testWidgets(
    'review screen exposes date and break end editing before confirmation',
    (tester) async {
      final reviewUseCase = _FakeReviewUseCase();
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: reviewUseCase,
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-1-date')),
      '21-MAYO-2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('entry-1-breakEnd')),
      '12:50',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -660));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
    await tester.pumpAndSettle();

      expect(
        reviewUseCase.confirmedDraft?.entries.single.fields['date'],
        '21-MAYO-2026',
      );
      expect(
        reviewUseCase.confirmedDraft?.entries.single.fields['breakEnd'],
        '12:50',
      );
    },
  );

  testWidgets('alarm timeline renders contextual labels without global ordinals', (
    tester,
  ) async {
    final main = AlarmEvent(
      id: 'main-1',
      planId: 'plan-1',
      scheduledTime: DateTime(2026, 5, 20, 12, 30),
      type: AlarmEventType.main,
      toneProfile: ToneProfile.breakStart,
      purpose: AlarmEventPurpose.breakStart,
      sourceFieldKey: 'breakStart',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: [main.preWarningFor(), main],
          ),
        ),
      ),
    );

    expect(find.text('Próximas alarmas programadas'), findsOneWidget);
    // Nearest future day is expanded by default
    expect(find.text('12:29'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.text('Preaviso: 1° Break Inicio'), findsOneWidget);
    expect(find.text('Alarma: 1° Break Inicio'), findsOneWidget);
    expect(find.text('Activa'), findsNWidgets(2));

    // Collapse and re-expand to verify interactivity
    await tester.tap(find.text('20-05-2026'));
    await tester.pumpAndSettle();
    expect(find.text('12:29'), findsNothing);
    await tester.tap(find.text('20-05-2026'));
    await tester.pumpAndSettle();
    expect(find.text('12:29'), findsOneWidget);
  });

  testWidgets('alarm timeline renders history with status chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: const [],
            history: [
              AlarmEvent(
                id: 'hist-1',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 5, 20, 10),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
                sourceFieldKey: 'breakStart',
                status: AlarmEventStatus.dismissed,
                statusChangedAt: DateTime(2026, 5, 20, 10, 1),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Alarma: 1° Break Inicio'), findsOneWidget);
    expect(find.text('Descartada'), findsOneWidget);
  });

  testWidgets('alarm timeline shows empty history state when no history exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: [
              AlarmEvent(
                id: 'main-1',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 5, 20, 12, 30),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('No hay alarmas en el historial.'), findsOneWidget);
  });

  testWidgets('alarm timeline groups upcoming alarms by date and is expandable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: [
              AlarmEvent(
                id: 'd19-main',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 6, 19, 10, 0),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
              ),
              AlarmEvent(
                id: 'd20-main',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 6, 20, 10, 0),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Próximas alarmas programadas'), findsOneWidget);
    // Date headers are visible
    expect(find.text('19-06-2026'), findsOneWidget);
    expect(find.text('20-06-2026'), findsOneWidget);

    // Only the nearest future day should be expanded by default
    expect(find.text('10:00'), findsOneWidget); // only the first (19th)

    // Expand the second day
    await tester.tap(find.text('20-06-2026'));
    await tester.pumpAndSettle();
    expect(find.text('10:00'), findsNWidgets(2));
  });

  testWidgets('active alarm rows show Editar button, history rows do not', (
    tester,
  ) async {
    final main = AlarmEvent(
      id: 'main-1',
      planId: 'plan-1',
      scheduledTime: DateTime(2026, 5, 20, 12, 30),
      type: AlarmEventType.main,
      toneProfile: ToneProfile.breakStart,
      purpose: AlarmEventPurpose.breakStart,
      sourceFieldKey: 'breakStart',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
        body: AlarmTimeline(
          alarms: [main.preWarningFor(), main],
          history: [
            AlarmEvent(
              id: 'hist-1',
              planId: 'plan-1',
              scheduledTime: DateTime(2026, 5, 20, 10),
              type: AlarmEventType.main,
              toneProfile: ToneProfile.breakStart,
              purpose: AlarmEventPurpose.breakStart,
              sourceFieldKey: 'breakStart',
              status: AlarmEventStatus.dismissed,
              statusChangedAt: DateTime(2026, 5, 20, 10, 1),
            ),
          ],
          onEditAlarm: (_) {},
        ),
        ),
      ),
    );

    // Active alarms show Editar
    expect(find.text('Editar'), findsNWidgets(2));

    // History does not show Editar
    expect(find.text('Descartada'), findsOneWidget);
    // Verify no extra Editar beyond the 2 active ones
    expect(find.text('Editar'), findsNWidgets(2));
  });

  testWidgets('tapping Editar on an active alarm invokes onEditAlarm callback', (
    tester,
  ) async {
    AlarmEvent? editedAlarm;
    final main = AlarmEvent(
      id: 'main-1',
      planId: 'plan-1',
      scheduledTime: DateTime(2026, 5, 20, 12, 30),
      type: AlarmEventType.main,
      toneProfile: ToneProfile.breakStart,
      purpose: AlarmEventPurpose.breakStart,
      sourceFieldKey: 'breakStart',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: [main],
            onEditAlarm: (alarm) => editedAlarm = alarm,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(editedAlarm, isNotNull);
    expect(editedAlarm!.id, 'main-1');
  });

  testWidgets('alarm timeline shows history section before upcoming alarms', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlarmTimeline(
            alarms: [
              AlarmEvent(
                id: 'future',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 6, 20, 10, 0),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
              ),
            ],
            history: [
              AlarmEvent(
                id: 'past',
                planId: 'plan-1',
                scheduledTime: DateTime(2026, 5, 20, 10, 0),
                type: AlarmEventType.main,
                toneProfile: ToneProfile.breakStart,
                purpose: AlarmEventPurpose.breakStart,
                status: AlarmEventStatus.dismissed,
                statusChangedAt: DateTime(2026, 5, 20, 10, 1),
              ),
            ],
          ),
        ),
      ),
    );

    final historial = find.text('Historial');
    final proximas = find.text('Próximas alarmas programadas');
    expect(historial, findsOneWidget);
    expect(proximas, findsOneWidget);

    // Historial must appear before Próximas in the widget tree
    final historialRect = tester.getRect(historial);
    final proximasRect = tester.getRect(proximas);
    expect(historialRect.top, lessThan(proximasRect.top));
  });

  testWidgets('review UI states the 24-hour local time policy', (tester) async {
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'turno.xlsx',
            fileName: 'turno.xlsx',
          ),
        ),
        importUseCase: _FakeImportUseCase(draft: _draft()),
        reviewUseCase: _FakeReviewUseCase(),
      ),
    );

    await tester.tap(find.text('Importar Excel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('24 horas'), findsWidgets);
    expect(find.textContaining('hora local'), findsWidgets);
  });

  testWidgets('after confirm per-row edit remains on active alarm rows', (
    tester,
  ) async {
    final reviewUseCase = _FakeReviewUseCase();
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(
          result: const FilePickResult(
            path: 'turno.xlsx',
            fileName: 'turno.xlsx',
          ),
        ),
        importUseCase: _FakeImportUseCase(draft: _draft()),
        reviewUseCase: reviewUseCase,
      ),
    );

    await tester.tap(find.text('Importar Excel'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -660));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Transient success instead of confirmed card
    expect(find.text('Cargado con éxito en alarmas activas'), findsOneWidget);
    // Per-row edit is available in the authoritative active block
    expect(find.text('Editar'), findsNWidgets(2));
  });

  testWidgets(
    'review screen shows Hora Inicio and Hora Termino when present in draft',
    (tester) async {
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draftWithAllFields()),
          reviewUseCase: _FakeReviewUseCase(),
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();

      // Hora inicio and Hora termino fields must be visible and editable
      expect(
        find.byKey(const ValueKey('entry-1-startTime')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('entry-1-endTime')),
        findsOneWidget,
      );
      expect(find.textContaining('Hora inicio'), findsWidgets);
      expect(find.textContaining('Hora término'), findsWidgets);
    },
  );

  testWidgets(
    'review screen renders labels for Término almuerzo extendido and Inicio segundo descanso',
    (tester) async {
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draftWithAllFields()),
          reviewUseCase: _FakeReviewUseCase(),
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Término almuerzo extendido'), findsWidgets);
      expect(find.textContaining('Inicio segundo descanso'), findsWidgets);
      expect(find.text('Término almuerzo'), findsNothing);
      expect(find.text('Inicio almuerzo extendido'), findsNothing);
    },
  );

  testWidgets(
    'review screen hides informational-only fields from Excel import',
    (tester) async {
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draftWithAllFields()),
          reviewUseCase: _FakeReviewUseCase(),
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();

      // These fields must NOT appear as editable alarm fields
      expect(
        find.byKey(const ValueKey('entry-1-lunchEnd')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('entry-1-extendedLunchStart')),
        findsNothing,
      );

      // But the schedulable ones must still be there
      expect(
        find.byKey(const ValueKey('entry-1-breakStart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('entry-1-lunchStart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('entry-1-extendedLunchEnd')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('entry-1-secondBreakStart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('entry-1-secondBreakEnd')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'review screen shows exactly the eight settable alarm fields for full row',
    (tester) async {
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draftWithAllFields()),
          reviewUseCase: _FakeReviewUseCase(),
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();

      // 1 date field + 8 settable time fields = 9 TextFormFields total
      expect(find.byType(TextFormField), findsNWidgets(9));
    },
  );

  testWidgets(
    'confirmed alarms can be imported again for full re-editing',
    (tester) async {
      final reviewUseCase = _FakeReviewUseCase();
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: reviewUseCase,
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -660));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Transient success shown in authoritative active block
      expect(find.text('Cargado con éxito en alarmas activas'), findsOneWidget);
      expect(find.text('Alarmas activas'), findsOneWidget);

      // Scroll back to top to re-import from the source card
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();

      // Re-import from the source card to edit again
      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('entry-1-breakStart')),
        '13:10',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -660));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        reviewUseCase.confirmedDraft?.entries.single.fields['breakStart'],
        '13:10',
      );
    },
  );

  testWidgets('edit button visible when persisted active alarms exist after startup', (
    tester,
  ) async {
    final repository = _FakeLocalRepositoryWithActiveAlarms();
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(result: null),
        importUseCase: _FakeImportUseCase(),
        reviewUseCase: _FakeReviewUseCase(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alarmas activas'), findsOneWidget);
    // Global edit button removed; per-row edit remains
    expect(find.text('Editar alarmas'), findsNothing);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Descartada'), findsOneWidget);
  });

  testWidgets(
    'active alarm section has no global Editar alarmas or Ocultar todas',
    (tester) async {
      final repository = _FakeLocalRepositoryWithActiveAlarms();
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(result: null),
          importUseCase: _FakeImportUseCase(),
          reviewUseCase: _FakeReviewUseCase(),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alarmas activas'), findsOneWidget);
      // Global buttons must NOT appear
      expect(find.text('Editar alarmas'), findsNothing);
      expect(find.text('Ocultar todas'), findsNothing);
    },
  );

  testWidgets(
    'after confirm only one Alarmas activas block exists with transient success',
    (tester) async {
      final reviewUseCase = _FakeReviewUseCase();
      await tester.pumpWidget(
        _app(
          filePicker: _FakeFilePicker(
            result: const FilePickResult(
              path: 'turno.xlsx',
              fileName: 'turno.xlsx',
            ),
          ),
          importUseCase: _FakeImportUseCase(draft: _draft()),
          reviewUseCase: reviewUseCase,
        ),
      );

      await tester.tap(find.text('Importar Excel'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -660));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar alarmas'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only one authoritative active block
      expect(find.text('Alarmas activas'), findsOneWidget);
      // Transient success feedback
      expect(find.text('Cargado con éxito en alarmas activas'), findsOneWidget);
      // No duplicate Historial / Próximas blocks
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Próximas alarmas programadas'), findsOneWidget);
    },
  );

  testWidgets('manual refresh still works after startup auto-load', (
    tester,
  ) async {
    final repository = _FakeLocalRepositoryWithActiveAlarms();
    await tester.pumpWidget(
      _app(
        filePicker: _FakeFilePicker(result: null),
        importUseCase: _FakeImportUseCase(),
        reviewUseCase: _FakeReviewUseCase(),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Descartada'), findsOneWidget);

    // Update repository data to simulate a new alarm state
    repository.history = [
      AlarmEvent(
        id: 'new-hist',
        planId: 'plan-1',
        scheduledTime: DateTime(2026, 5, 20, 10),
        type: AlarmEventType.main,
        toneProfile: ToneProfile.breakStart,
        purpose: AlarmEventPurpose.breakStart,
        status: AlarmEventStatus.fired,
        statusChangedAt: DateTime(2026, 5, 20, 10, 1),
      ),
    ];

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();

    expect(find.text('Sonada'), findsOneWidget);
  });
}

Widget _app({
  required FilePicker filePicker,
  required ImportScheduleUseCase importUseCase,
  required ReviewAndConfirmUseCase reviewUseCase,
  LocalRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      filePickerProvider.overrideWithValue(filePicker),
      importScheduleUseCaseProvider.overrideWithValue(importUseCase),
      reviewAndConfirmUseCaseProvider.overrideWithValue(reviewUseCase),
      localRepositoryProvider.overrideWithValue(repository ?? _FakeLocalRepository()),
      alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
    ],
    child: const MaterialApp(home: ImportScreen()),
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
          'date': '20-MAYO-2026',
          'name': 'Mika',
          'startTime': '08:00',
          'endTime': '17:00',
          'breakStart': '12:30',
          'breakEnd': '12:45',
        },
        confidence: Confidence.low(reason: 'Ambiguous break column'),
      ),
    ],
  );
}

ScheduleDraft _draftWithAllFields() {
  return ScheduleDraft(
    id: 'draft-full',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: const [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          'date': '20-MAYO-2026',
          'name': 'Mika',
          'startTime': '08:00',
          'breakStart': '12:30',
          'breakEnd': '12:45',
          'lunchStart': '13:00',
          'lunchEnd': '14:00',
          'extendedLunchStart': '14:00',
          'extendedLunchEnd': '14:15',
          'secondBreakStart': '15:00',
          'secondBreakEnd': '15:15',
          'endTime': '17:00',
        },
        confidence: Confidence.high(),
      ),
    ],
  );
}

ScheduleDraft _largeDraft({required int entryCount}) {
  return ScheduleDraft(
    id: 'large-draft',
    source: ImportSource.image,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: [
      for (var index = 0; index < entryCount; index++)
        RawEntry(
          id: 'entry-$index',
          source: ImportSource.image,
          fields: {
            'date': '${(index % 30) + 1}-MAYO-2026',
            'startTime': '00:00',
            'breakStart': '02:30',
            'endTime': '08:30',
          },
          confidence: const Confidence.medium(reason: 'headerless'),
        ),
    ],
  );
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
  ScheduleDraft? confirmedDraft;

  @override
  Future<void> cancel(ScheduleDraft draft) async {}

  @override
  Future<AlarmPlan> confirm(ScheduleDraft draft) async {
    confirmedDraft = draft;
    return AlarmPlan(
      id: 'plan_${draft.id}',
      scheduleId: draft.id,
      alarms: [
        AlarmEvent(
          id: 'pre-1',
          planId: 'plan_${draft.id}',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 44),
          type: AlarmEventType.preWarning,
          toneProfile: ToneProfile.preBreak,
        ),
        AlarmEvent(
          id: 'main-1',
          planId: 'plan_${draft.id}',
          scheduledTime: DateTime.utc(2026, 5, 14, 12, 45),
          type: AlarmEventType.main,
          toneProfile: ToneProfile.breakStart,
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 14, 10),
    );
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
  @override
  Future<void> deleteDraft(String id) async {}

  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => const [];

  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async => const [];

  @override
  Future<List<AlarmPlan>> getAllPlans() async => const [];

  @override
  Future<ScheduleDraft?> getDraft(String id) async => null;

  @override
  Future<List<AlarmEvent>> getEventsForPlan(String planId) async => const [];

  @override
  Future<AlarmPlan?> getPlan(String id) async => null;

  @override
  Future<void> saveDraft(ScheduleDraft draft) async {}

  @override
  Future<void> savePlan(AlarmPlan plan) async {}

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

final class _FakeLocalRepositoryWithActiveAlarms implements LocalRepository {
  List<AlarmEvent> activeAlarms = [
    AlarmEvent(
      id: 'active-1',
      planId: 'plan-1',
      scheduledTime: DateTime(2026, 6, 20, 10, 0),
      type: AlarmEventType.main,
      toneProfile: ToneProfile.breakStart,
      purpose: AlarmEventPurpose.breakStart,
      enabled: true,
    ),
  ];
  List<AlarmEvent> history = [
    AlarmEvent(
      id: 'hist-1',
      planId: 'plan-1',
      scheduledTime: DateTime(2026, 5, 20, 10, 0),
      type: AlarmEventType.main,
      toneProfile: ToneProfile.breakStart,
      purpose: AlarmEventPurpose.breakStart,
      status: AlarmEventStatus.dismissed,
      statusChangedAt: DateTime(2026, 5, 20, 10, 1),
    ),
  ];

  @override
  Future<void> deleteDraft(String id) async {}
  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => [];
  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async => activeAlarms;
  @override
  Future<List<AlarmPlan>> getAllPlans() async => [];
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
  Future<List<int>> pruneStaleEnabledEvents(DateTime now) async => [];
  @override
  Future<void> updateAlarmStatus(String id, AlarmEventStatus status) async {}
  @override
  Future<void> updateAlarmEvent(AlarmEvent event) async {}
  @override
  Future<List<AlarmEvent>> getAlarmHistory() async => history;
  @override
  Future<void> purgeHistoryOlderThan(DateTime cutoff) async {}
}

final class _FakeAlarmScheduler implements AlarmScheduler {
  @override
  Future<int> schedule(AlarmEvent event) async => event.id.hashCode;

  @override
  Future<void> cancel(int nativeAlarmId) async {}

  @override
  Future<void> rescheduleAll(List<AlarmEvent> events) async {}

  @override
  Future<void> pruneNativeStaleAlarms(DateTime now) async {}

  @override
  Future<List<Map<String, Object?>>> syncAlarmOutcomes() async => [];

  @override
  int nativeIdFor(AlarmEvent event) => event.id.hashCode;
}
