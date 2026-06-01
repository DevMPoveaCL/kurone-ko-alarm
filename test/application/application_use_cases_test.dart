import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/application/use_cases/import_schedule.dart';
import 'package:kurone_ko_alarm/application/use_cases/reviewed_alarm_plan_mapper.dart';
import 'package:kurone_ko_alarm/application/use_cases/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/permission_gateway.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/structured_file_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/file_reader/excel_reader_adapter.dart';

void main() {
  group('ImportScheduleUseCase', () {
    test('imports Excel rows into a reviewable schedule draft', () async {
      final useCase = ImportScheduleUseCaseImpl(
        ocrReader: _FakeOcrReader(),
        structuredFileReader: _FakeStructuredFileReader([
          ['Empleado', 'Entrada', 'Salida', 'Descanso'],
          ['Mika', '08:00', '17:00', '12:30'],
        ]),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 9, 30)),
      );

      final draft = await useCase.import(
        filePath: 'schedule.xlsx',
        source: ImportSource.excel,
      );

      expect(draft.id, 'draft_2026-05-14T09:30:00.000Z');
      expect(draft.source, ImportSource.excel);
      expect(draft.createdAt, DateTime.utc(2026, 5, 14, 9, 30));
      expect(draft.entries, hasLength(1));
      expect(draft.entries.single.fields, {
        'name': 'Mika',
        'startTime': '08:00',
        'endTime': '17:00',
        'breakStart': '12:30',
      });
      expect(draft.entries.single.confidence.level, ConfidenceLevel.high);
    });

    test(
      'imports real formatoExcel.xlsx with expected schedule semantics',
      () async {
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(),
          structuredFileReader: ExcelReaderAdapter(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9, 30)),
        );

        final draft = await useCase.import(
          filePath: 'formatoExcel.xlsx',
          source: ImportSource.excel,
        );
        final fields = draft.entries.first.fields;

        expect(
          fields.keys,
          containsAll(<String>[
            'date',
            'startTime',
            'breakStart',
            'breakEnd',
            'lunchStart',
            'lunchEnd',
            'extendedLunchStart',
            'extendedLunchEnd',
            'secondBreakStart',
            'secondBreakEnd',
            'endTime',
          ]),
        );

        final representativeDraft = ScheduleDraft(
          id: 'draft-real-excel-first-row',
          source: draft.source,
          createdAt: draft.createdAt,
          entries: [draft.entries.first],
        );
        final mainAlarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          representativeDraft,
          planId: 'plan-real-excel',
        );

        expect(
          mainAlarms.map((alarm) => alarm.purpose),
          unorderedEquals([
            AlarmEventPurpose.shiftStart,
            AlarmEventPurpose.breakStart,
            AlarmEventPurpose.breakEnd,
            AlarmEventPurpose.lunchStart,
            AlarmEventPurpose.lunchExtensionEnd,
            AlarmEventPurpose.breakStart,
            AlarmEventPurpose.breakEnd,
            AlarmEventPurpose.shiftEnd,
          ]),
        );
        expect(mainAlarms, hasLength(8));
        expect(
          mainAlarms.map((alarm) => alarm.scheduledTime),
          isNot(contains(DateTime(2026, 5, 20, 5, 30))),
        );
      },
    );

    test(
      'imports Excel with accented termino headers and schedules correct alarms',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kurone_accented_headers_',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final path = '${tempDir.path}${Platform.pathSeparator}accented.xlsx';
        final workbook = Excel.createExcel();
        workbook.rename('Sheet1', 'Horarios');
        const headers = [
          'Fecha',
          'Hora Inicio',
          "1° Break Inicio",
          "1° Break Término",
          'Lunch Inicio',
          'Lunch Término',
          'Ext. Lunch Inicio',
          'Ext. Lunch Término',
          "2° Break Inicio",
          "2° Break Término",
          'Hora Término',
        ];
        const values = [
          '20-MAYO-2026',
          '00:00',
          '02:30',
          '02:45',
          '05:00',
          '05:30',
          '05:30',
          '05:45',
          '08:00',
          '08:15',
          '10:00',
        ];
        for (var col = 0; col < headers.length; col++) {
          workbook.updateCell(
            'Horarios',
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
            TextCellValue(headers[col]),
          );
          workbook.updateCell(
            'Horarios',
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1),
            TextCellValue(values[col]),
          );
        }
        await File(path).writeAsBytes(workbook.encode()!, flush: true);

        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(),
          structuredFileReader: ExcelReaderAdapter(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 9, 30)),
        );

        final draft = await useCase.import(
          filePath: path,
          source: ImportSource.excel,
        );
        final mainAlarms = ReviewedAlarmPlanMapper.buildMainAlarms(
          ScheduleDraft(
            id: 'draft-accented',
            source: draft.source,
            createdAt: draft.createdAt,
            entries: [draft.entries.first],
          ),
          planId: 'plan-accented',
        );

        expect(mainAlarms, hasLength(8));
        expect(
          mainAlarms.map((alarm) => alarm.purpose),
          unorderedEquals([
            AlarmEventPurpose.shiftStart,
            AlarmEventPurpose.breakStart,
            AlarmEventPurpose.breakEnd,
            AlarmEventPurpose.lunchStart,
            AlarmEventPurpose.lunchExtensionEnd,
            AlarmEventPurpose.breakStart,
            AlarmEventPurpose.breakEnd,
            AlarmEventPurpose.shiftEnd,
          ]),
        );
        expect(
          mainAlarms.map((alarm) => alarm.scheduledTime),
          orderedEquals([
            DateTime(2026, 5, 20, 0),
            DateTime(2026, 5, 20, 2, 30),
            DateTime(2026, 5, 20, 2, 45),
            DateTime(2026, 5, 20, 5),
            DateTime(2026, 5, 20, 5, 45),
            DateTime(2026, 5, 20, 8),
            DateTime(2026, 5, 20, 8, 15),
            DateTime(2026, 5, 20, 10),
          ]),
        );
      },
    );

    test('imports image bytes through OCR before normalization', () async {
      final tempDir = await Directory.systemTemp.createTemp('import_schedule_');
      addTearDown(() async => tempDir.delete(recursive: true));
      final image = File('${tempDir.path}/schedule.png');
      await image.writeAsBytes([1, 2, 3, 4]);
      final ocrReader = _FakeOcrReader(
        lines: ['Empleado Entrada Salida Descanso', 'Neko 09:00 18:00 13:15'],
      );
      final useCase = ImportScheduleUseCaseImpl(
        ocrReader: ocrReader,
        structuredFileReader: _FakeStructuredFileReader(const []),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
      );

      final draft = await useCase.import(
        filePath: image.path,
        source: ImportSource.image,
      );

      expect(ocrReader.receivedBytes, Uint8List.fromList([1, 2, 3, 4]));
      expect(draft.source, ImportSource.image);
      expect(draft.entries.single.fields, {
        'name': 'Neko',
        'startTime': '09:00',
        'endTime': '18:00',
        'breakStart': '13:15',
      });
    });

    test(
      'imports screenshot-like OCR schedule columns into usable entries',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Fecha',
              'Hora Inicio',
              '1° Break Inicio',
              '1° Break Termino',
              'Lunch Inicio',
              'Lunch Termino',
              'Ext. Lunch Inicio',
              'Ext. Lunch Termino',
              '2° Break Inicio',
              '2° Break Termino',
              'Hora Termino',
              '09-MAYO-2026 02:00 02:30 02:45 05:00 05:30 05:30 05:45 08:00 08:15 10:00',
              '10-MAYO-2026 02:00 02:30 02:45 05:00 05:30 05:30 05:45 08:00 08:15 10:00',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(2));
        expect(
          draft.entries.first.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.first.fields, containsPair('startTime', '02:00'));
        expect(draft.entries.first.fields, containsPair('breakStart', '02:30'));
        expect(draft.entries.first.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.last.fields, containsPair('date', '10-MAYO-2026'));
      },
    );

    test(
      'imports screenshot OCR when headers are recognized as one line',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Fecha Hora Inicio 1° Break Inicio 1° Break Termino Lunch Inicio Lunch Termino Ext. Lunch Inicio Ext. Lunch Termino 2° Break Inicio 2° Break Termino Hora Termino',
              '11/MAYO/2026 03:00 03:30 03:45 06:00 06:30 06:30 06:45 09:00 09:15 11:00',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(1));
        expect(
          draft.entries.single.fields,
          containsPair('date', '11/MAYO/2026'),
        );
        expect(draft.entries.single.fields, containsPair('startTime', '03:00'));
        expect(draft.entries.single.fields, containsPair('breakEnd', '03:45'));
        expect(
          draft.entries.single.fields,
          containsPair('lunchStart', '06:00'),
        );
        expect(draft.entries.single.fields, containsPair('endTime', '11:00'));
      },
    );

    test(
      'imports screenshot OCR when ML Kit returns vertical column text',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Fecha',
              '09-MAYO-2026',
              '10-MAYO-2026',
              'Hora Inicio',
              '00:00',
              '00:00',
              '1º Break Inicio',
              '02:30',
              '02:30',
              '1º Break Término',
              '02:45',
              '02:45',
              'Lunch Inicio',
              '05:00',
              '05:00',
              'Lunch Termino',
              '05:30',
              '05:30',
              'Ext. Lunch Inicio',
              '05:30',
              '05:30',
              'Ext. Lunch Termino',
              '05:45',
              '05:45',
              '2° Break Inicio',
              '08:00',
              '08:00',
              '2° Break Termino',
              '08:15',
              '08:15',
              'Hora Termino',
              '10:00',
              '10:00',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(2));
        expect(
          draft.entries.first.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.first.fields, containsPair('startTime', '00:00'));
        expect(draft.entries.first.fields, containsPair('breakStart', '02:30'));
        expect(draft.entries.first.fields, containsPair('breakEnd', '02:45'));
        expect(draft.entries.first.fields, containsPair('lunchStart', '05:00'));
        expect(draft.entries.first.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.last.fields, containsPair('date', '10-MAYO-2026'));
      },
    );

    test(
      'imports screenshot OCR when ML Kit returns the whole table as one block',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Fecha Hora Inicio 1° Break Inicio 1° Break Termino Lunch Inicio Lunch Termino Ext. Lunch Inicio Ext. Lunch Termino 2° Break Inicio 2° Break Termino Hora Termino 12-MAYO-2026 00:00 02:30 02:45 05:00 05:30 05:30 05:45 08:00 08:15 10:00',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(1));
        expect(
          draft.entries.single.fields,
          containsPair('date', '12-MAYO-2026'),
        );
        expect(draft.entries.single.fields, containsPair('startTime', '00:00'));
        expect(
          draft.entries.single.fields,
          containsPair('breakStart', '02:30'),
        );
        expect(draft.entries.single.fields, containsPair('endTime', '10:00'));
      },
    );

    test(
      'imports sparse screenshot OCR when one line contains row-major date and time tokens',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Agente Turno Breaks Almuerzo Termino',
              'Fecha Hora Inicio 1° Break Inicio 1° Break Termino Lunch Inicio Lunch Termino Ext. Lunch Inicio Ext. Lunch Termino 2° Break Inicio 2° Break Termino Hora Termino',
              '09-MAYO-2026 00:00 02:30 02:45 04:30 05:00 05:30 05:45 08:00 08:15 10:00 10-MAYO-2026 00:15 02:45 03:00 04:45 05:15 05:45 06:00 08:30 08:45 10:15',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(2));
        expect(
          draft.entries.first.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.first.fields, containsPair('startTime', '00:00'));
        expect(draft.entries.first.fields, containsPair('breakEnd', '02:45'));
        expect(draft.entries.first.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.last.fields, containsPair('date', '10-MAYO-2026'));
        expect(draft.entries.last.fields, containsPair('startTime', '00:15'));
        expect(draft.entries.last.fields, containsPair('lunchStart', '04:45'));
        expect(draft.entries.last.fields, containsPair('endTime', '10:15'));
      },
    );

    test(
      'imports sparse screenshot OCR when token stream is column-major',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Fecha Hora Inicio 1° Break Inicio 1° Break Termino Lunch Inicio Lunch Termino Ext. Lunch Inicio Ext. Lunch Termino 2° Break Inicio 2° Break Termino Hora Termino',
              '09-MAYO-2026 10-MAYO-2026 00:00 00:15 02:30 02:45 02:45 03:00 04:30 04:45 05:00 05:15 05:30 05:45 05:45 06:00 08:00 08:30 08:15 08:45 10:00 10:15',
              'Supervisor A Supervisor B',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(2));
        expect(
          draft.entries.first.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.first.fields, containsPair('startTime', '00:00'));
        expect(draft.entries.first.fields, containsPair('breakStart', '02:30'));
        expect(draft.entries.first.fields, containsPair('lunchStart', '04:30'));
        expect(draft.entries.first.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.last.fields, containsPair('date', '10-MAYO-2026'));
        expect(draft.entries.last.fields, containsPair('startTime', '00:15'));
        expect(draft.entries.last.fields, containsPair('breakStart', '02:45'));
        expect(draft.entries.last.fields, containsPair('lunchStart', '04:45'));
        expect(draft.entries.last.fields, containsPair('endTime', '10:15'));
      },
    );

    test(
      'prefers spatial OCR cells to rebuild wide schedule rows from geometry',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/wide-schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              '09-MAYO-2026 10-MAYO-2026',
              '00:00 00:15 02:30 02:45 05:00 05:15 10:00 10:15',
              'Captura privada de turno ancho',
            ],
            spatialCells: const [
              OcrTextCell(
                text: 'Fecha',
                left: 10,
                top: 10,
                width: 42,
                height: 12,
              ),
              OcrTextCell(
                text: 'Hora Inicio',
                left: 110,
                top: 10,
                width: 78,
                height: 12,
              ),
              OcrTextCell(
                text: '1° Break Inicio',
                left: 220,
                top: 10,
                width: 92,
                height: 12,
              ),
              OcrTextCell(
                text: 'Lunch Inicio',
                left: 360,
                top: 10,
                width: 86,
                height: 12,
              ),
              OcrTextCell(
                text: 'Hora Termino',
                left: 500,
                top: 10,
                width: 88,
                height: 12,
              ),
              OcrTextCell(
                text: '09-MAYO-2026',
                left: 10,
                top: 44,
                width: 90,
                height: 12,
              ),
              OcrTextCell(
                text: '00:00',
                left: 110,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '02:30',
                left: 220,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '05:00',
                left: 360,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '10:00',
                left: 500,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '10-MAYO-2026',
                left: 10,
                top: 72,
                width: 90,
                height: 12,
              ),
              OcrTextCell(
                text: '00:15',
                left: 110,
                top: 72,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '02:45',
                left: 220,
                top: 72,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '05:15',
                left: 360,
                top: 72,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '10:15',
                left: 500,
                top: 72,
                width: 44,
                height: 12,
              ),
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(2));
        expect(
          draft.entries.first.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.first.fields, containsPair('startTime', '00:00'));
        expect(draft.entries.first.fields, containsPair('breakStart', '02:30'));
        expect(draft.entries.first.fields, containsPair('lunchStart', '05:00'));
        expect(draft.entries.first.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.last.fields, containsPair('date', '10-MAYO-2026'));
        expect(draft.entries.last.fields, containsPair('startTime', '00:15'));
        expect(draft.entries.last.fields, containsPair('lunchStart', '05:15'));
        expect(draft.entries.last.fields, containsPair('endTime', '10:15'));
      },
    );

    test(
      'does not report OCR lines 3 failure when spatial schedule cells exist',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/wide-schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'texto con 09-MAYO-2026',
              'texto privado',
              'otro texto privado',
            ],
            spatialCells: const [
              OcrTextCell(
                text: 'Fecha',
                left: 10,
                top: 10,
                width: 42,
                height: 12,
              ),
              OcrTextCell(
                text: 'Hora Inicio',
                left: 110,
                top: 10,
                width: 78,
                height: 12,
              ),
              OcrTextCell(
                text: 'Lunch Inicio',
                left: 250,
                top: 10,
                width: 86,
                height: 12,
              ),
              OcrTextCell(
                text: 'Hora Termino',
                left: 390,
                top: 10,
                width: 88,
                height: 12,
              ),
              OcrTextCell(
                text: '09-MAYO-2026',
                left: 10,
                top: 44,
                width: 90,
                height: 12,
              ),
              OcrTextCell(
                text: '00:00',
                left: 110,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '05:00',
                left: 250,
                top: 44,
                width: 44,
                height: 12,
              ),
              OcrTextCell(
                text: '10:00',
                left: 390,
                top: 44,
                width: 44,
                height: 12,
              ),
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(1));
        expect(
          draft.entries.single.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.single.fields, containsPair('startTime', '00:00'));
        expect(
          draft.entries.single.fields,
          containsPair('lunchStart', '05:00'),
        );
        expect(draft.entries.single.fields, containsPair('endTime', '10:00'));
      },
    );

    test('infers spatial schedule headers from adjacent token cells', () async {
      final tempDir = await Directory.systemTemp.createTemp('import_schedule_');
      addTearDown(() async => tempDir.delete(recursive: true));
      final image = File('${tempDir.path}/tokenized-wide-schedule.png');
      await image.writeAsBytes([9, 5, 20, 26]);
      final useCase = ImportScheduleUseCaseImpl(
        ocrReader: _FakeOcrReader(
          lines: const [
            'texto con 09-MAYO-2026',
            'texto privado',
            'otro texto privado',
          ],
          spatialCells: [
            _cell('Rut', 10, 8, width: 24),
            _cell('Agente', 40, 8, width: 50),
            _cell('Nombre', 120, 8, width: 54),
            _cell('Agente', 180, 8, width: 50),
            _cell('Buscar', 260, 8, width: 46),
            _cell('Importante', 330, 8, width: 78),
            _cell('Fecha', 10, 40, width: 42),
            _cell('Hora', 100, 40, width: 36),
            _cell('Inicio', 145, 40, width: 44),
            _cell('1º', 215, 40, width: 24),
            _cell('Break', 248, 40, width: 44),
            _cell('Inicio', 302, 40, width: 44),
            _cell('1°', 365, 40, width: 24),
            _cell('Break', 398, 40, width: 44),
            _cell('Término', 452, 40, width: 60),
            _cell('Lunch', 535, 40, width: 48),
            _cell('Inicio', 592, 40, width: 44),
            _cell('Lunch', 665, 40, width: 48),
            _cell('Termino', 722, 40, width: 60),
            _cell('Ext.', 800, 40, width: 32),
            _cell('Lunch', 840, 40, width: 48),
            _cell('Inicio', 898, 40, width: 44),
            _cell('Ext', 982, 40, width: 28),
            _cell('Lunch', 1020, 40, width: 48),
            _cell('Término', 1078, 40, width: 60),
            _cell('2', 1160, 40, width: 14),
            _cell('Break', 1188, 40, width: 44),
            _cell('Inicio', 1242, 40, width: 44),
            _cell('2°', 1310, 40, width: 24),
            _cell('Break', 1343, 40, width: 44),
            _cell('Termino', 1397, 40, width: 60),
            _cell('Hora', 1480, 40, width: 36),
            _cell('Termino', 1526, 40, width: 60),
            _cell('09-MAYO-2026', 10, 76, width: 90),
            _cell('00:00', 123, 76),
            _cell('02:30', 265, 76),
            _cell('02:45', 418, 76),
            _cell('04:30', 565, 76),
            _cell('05:00', 698, 76),
            _cell('05:30', 870, 76),
            _cell('06:00', 1050, 76),
            _cell('07:30', 1220, 76),
            _cell('07:45', 1375, 76),
            _cell('10:00', 1505, 76),
          ],
        ),
        structuredFileReader: _FakeStructuredFileReader(const []),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
      );

      final draft = await useCase.import(
        filePath: image.path,
        source: ImportSource.image,
      );

      expect(draft.entries, hasLength(1));
      expect(draft.entries.single.fields, containsPair('date', '09-MAYO-2026'));
      expect(draft.entries.single.fields, containsPair('startTime', '00:00'));
      expect(draft.entries.single.fields, containsPair('breakStart', '02:30'));
      expect(draft.entries.single.fields, containsPair('breakEnd', '02:45'));
      expect(draft.entries.single.fields, containsPair('lunchStart', '04:30'));
      expect(draft.entries.single.fields, containsPair('lunchEnd', '05:00'));
      expect(draft.entries.single.fields, containsPair('endTime', '10:00'));
    });

    test(
      'uses agnostic interpretation when labels are not spatial schedule headers',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/labels-only.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const ['Rut Agente', 'Nombre Agente', 'Buscar Importante'],
            spatialCells: [
              _cell('Rut', 10, 8, width: 24),
              _cell('Agente', 40, 8, width: 50),
              _cell('Nombre', 120, 8, width: 54),
              _cell('Agente', 180, 8, width: 50),
              _cell('Buscar', 260, 8, width: 46),
              _cell('Importante', 330, 8, width: 78),
              _cell('09-MAYO-2026', 10, 40, width: 90),
              _cell('00:00', 140, 40),
              _cell('10:00', 240, 40),
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(1));
        expect(
          draft.entries.single.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.single.fields, containsPair('startTime', '00:00'));
        expect(draft.entries.single.fields, containsPair('endTime', '10:00'));
        expect(draft.entries.single.confidence.level, ConfidenceLevel.medium);
      },
    );

    test(
      'routes zero-header OCR date and many times through agnostic interpretation',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/headerless-schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'sin encabezados privados',
              '09-MAYO-2026 00:00 02:30 02:45 04:30 05:00 05:00 05:15 07:00 07:15 08:30',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final draft = await useCase.import(
          filePath: image.path,
          source: ImportSource.image,
        );

        expect(draft.entries, hasLength(1));
        expect(
          draft.entries.single.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(draft.entries.single.fields, containsPair('startTime', '00:00'));
        expect(
          draft.entries.single.fields,
          containsPair('breakStart', '02:30'),
        );
        expect(
          draft.entries.single.fields,
          containsPair('lunchStart', '04:30'),
        );
        expect(draft.entries.single.fields, containsPair('endTime', '08:30'));
        expect(draft.entries.single.confidence.level, ConfidenceLevel.medium);
      },
    );

    test(
      'adds privacy-preserving OCR diagnostics when image extraction fails',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'Captura privada',
              'Notas privadas de la captura',
              '09-MAYO-2026',
              '00:00',
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final failure = await _captureExtractionFailure(
          () =>
              useCase.import(filePath: image.path, source: ImportSource.image),
        );

        expect(failure.message, contains('OCR lines: 4'));
        expect(failure.message, contains('date tokens: 1'));
        expect(failure.message, contains('time tokens: 1'));
        expect(failure.message, contains('candidate rows: 0'));
        expect(failure.message, contains('rejected:'));
        expect(
          failure.message,
          contains('sample: [text], [text], [date], [time]'),
        );
        expect(failure.message, isNot(contains('Mika')));
        expect(failure.message, isNot(contains('Notas privadas')));
        expect(failure.message, isNot(contains('09-MAYO-2026')));
        expect(failure.message, isNot(contains('00:00')));
        expect(failure.message, isNot(contains('header anchors')));
      },
    );

    test(
      'uses agnostic diagnostics instead of legacy header diagnostics on OCR failure',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'import_schedule_',
        );
        addTearDown(() async => tempDir.delete(recursive: true));
        final image = File('${tempDir.path}/wide-schedule.png');
        await image.writeAsBytes([9, 5, 20, 26]);
        final useCase = ImportScheduleUseCaseImpl(
          ocrReader: _FakeOcrReader(
            lines: const [
              'texto con 09-MAYO-2026',
              'texto privado',
              'otro texto privado',
            ],
            spatialCells: const [
              OcrTextCell(
                text: '09-MAYO-2026 sin horas legibles',
                left: 10,
                top: 40,
                width: 220,
                height: 12,
              ),
            ],
          ),
          structuredFileReader: _FakeStructuredFileReader(const []),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 10)),
        );

        final failure = await _captureExtractionFailure(
          () =>
              useCase.import(filePath: image.path, source: ImportSource.image),
        );

        expect(failure.message, contains('date tokens: 2'));
        expect(failure.message, contains('time tokens: 0'));
        expect(failure.message, contains('candidate rows: 0'));
        expect(failure.message, contains('rejected: no time tokens detected'));
        expect(failure.message, isNot(contains('header anchors')));
      },
    );

    test('fails when extraction yields no usable schedule entries', () async {
      final useCase = ImportScheduleUseCaseImpl(
        ocrReader: _FakeOcrReader(),
        structuredFileReader: _FakeStructuredFileReader(const [
          ['Entrada'],
        ]),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 11)),
      );

      expect(
        () =>
            useCase.import(filePath: 'empty.xlsx', source: ImportSource.excel),
        throwsA(isA<ExtractionFailure>()),
      );
    });
  });

  group('ReviewAndConfirmUseCase', () {
    test('opens a draft in reviewing state before confirmation', () {
      final useCase = ReviewAndConfirmUseCaseImpl(
        repository: _FakeLocalRepository(),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 12)),
        scheduler: _RecordingAlarmScheduler(),
      );

      final review = useCase.startReview(_draftWithLowConfidenceEntry());

      expect(review.state, ReviewState.reviewing);
      expect(review.draft.id, 'draft-1');
      expect(review.canConfirm, isTrue);
    });

    test('updates one entry without mutating the rest of the draft', () {
      final useCase = ReviewAndConfirmUseCaseImpl(
        repository: _FakeLocalRepository(),
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 12)),
        scheduler: _RecordingAlarmScheduler(),
      );
      final draft = _draftWithLowConfidenceEntry(extraEntry: true);

      final updated = useCase.updateEntry(
        draft,
        entryId: 'entry-1',
        fields: {'endTime': '17:30', 'breakStart': '12:45'},
      );

      expect(updated.entries.first.fields, {
        'name': 'Mika',
        'date': '20-MAYO-2026',
        'startTime': '08:00',
        'endTime': '17:30',
        'breakStart': '12:45',
      });
      expect(updated.entries.last.fields, {
        'name': 'Neko',
        'date': '20-MAYO-2026',
        'endTime': '18:00',
      });
      expect(draft.entries.first.fields['endTime'], '');
    });

    test(
      'confirm missing full-screen intent permission requests permission and does not call scheduler',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final permissionGateway = _FakePermissionGateway(
          fullScreenIntentPermissionGranted: false,
          requestFullScreenIntentPermissionResult: false,
        );
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
          permissionGateway: permissionGateway,
        );

        await expectLater(
          () => useCase.confirm(
            _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
          ),
          throwsA(
            isA<PermissionDenied>().having(
              (failure) => failure.permission,
              'permission',
              'fullScreenIntent',
            ),
          ),
        );

        expect(permissionGateway.fullScreenIntentChecks, 1);
        expect(permissionGateway.fullScreenIntentRequests, 1);
        expect(scheduler.rescheduledEvents, isEmpty);
        expect(await repository.getAllPlans(), isEmpty);
      },
    );

    test(
      'confirm missing exact alarm permission requests permission and does not call scheduler',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final permissionGateway = _FakePermissionGateway(
          exactAlarmPermissionGranted: false,
          requestExactAlarmResult: false,
        );
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
          permissionGateway: permissionGateway,
        );

        await expectLater(
          () => useCase.confirm(
            _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
          ),
          throwsA(
            isA<PermissionDenied>().having(
              (failure) => failure.permission,
              'permission',
              'exactAlarm',
            ),
          ),
        );

        expect(permissionGateway.exactAlarmChecks, 1);
        expect(permissionGateway.exactAlarmRequests, 1);
        expect(scheduler.rescheduledEvents, isEmpty);
        expect(await repository.getAllPlans(), isEmpty);
      },
    );

    test(
      'confirm schedules alarms after full-screen intent permission is granted',
      () async {
        final scheduler = _RecordingAlarmScheduler();
        final permissionGateway = _FakePermissionGateway(
          fullScreenIntentPermissionGranted: false,
          requestFullScreenIntentPermissionResult: true,
        );
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
          permissionGateway: permissionGateway,
        );

        final plan = await useCase.confirm(
          _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
        );

        expect(permissionGateway.fullScreenIntentChecks, 1);
        expect(permissionGateway.fullScreenIntentRequests, 1);
        expect(scheduler.rescheduledEvents, plan.alarms);
      },
    );

    test(
      'confirm schedules alarms after exact alarm permission is granted',
      () async {
        final scheduler = _RecordingAlarmScheduler();
        final permissionGateway = _FakePermissionGateway(
          exactAlarmPermissionGranted: false,
          requestExactAlarmResult: true,
        );
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
          permissionGateway: permissionGateway,
        );

        final plan = await useCase.confirm(
          _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
        );

        expect(permissionGateway.exactAlarmChecks, 1);
        expect(permissionGateway.exactAlarmRequests, 1);
        expect(scheduler.rescheduledEvents, plan.alarms);
      },
    );

    test(
      'confirm missing notification permission requests permission and avoids scheduling',
      () async {
        final scheduler = _RecordingAlarmScheduler();
        final permissionGateway = _FakePermissionGateway(
          notificationPermissionGranted: false,
          requestNotificationPermissionResult: false,
        );
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
          permissionGateway: permissionGateway,
        );

        await expectLater(
          () => useCase.confirm(
            _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
          ),
          throwsA(
            isA<PermissionDenied>().having(
              (failure) => failure.permission,
              'permission',
              'notifications',
            ),
          ),
        );

        expect(permissionGateway.notificationChecks, 1);
        expect(permissionGateway.notificationRequests, 1);
        expect(scheduler.rescheduledEvents, isEmpty);
      },
    );

    test(
      'confirm persists reviewed draft and schedules all unique break and lunch alarm times',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
        );
        final draft = _draftWithBreakStartAndEndRows();

        final plan = await useCase.confirm(draft);

        expect(await repository.getDraft('draft-breaks'), draft);
        expect(await repository.getPlan('plan_draft-breaks'), plan);
        expect(plan.id, 'plan_draft-breaks');
        expect(plan.scheduleId, 'draft-breaks');
        expect(plan.mainAlarms.map((alarm) => alarm.scheduledTime), [
          DateTime(2026, 5, 20, 9),
          DateTime(2026, 5, 20, 9, 15),
          DateTime(2026, 5, 20, 10),
          DateTime(2026, 5, 20, 10, 15),
          DateTime(2026, 5, 20, 11),
          DateTime(2026, 5, 20, 11, 15),
          DateTime(2026, 5, 20, 12),
          DateTime(2026, 5, 20, 12, 15),
        ]);
        expect(scheduler.rescheduledEvents, plan.alarms);
        expect(scheduler.rescheduledEvents, hasLength(16));
        expect(plan.createdAt, DateTime.utc(2026, 5, 14, 12, 30));
      },
    );

    test(
      'confirm schedules every enabled alarm through the alarm scheduler',
      () async {
        final scheduler = _RecordingAlarmScheduler();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: scheduler,
        );

        final plan = await useCase.confirm(
          _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
        );

        expect(plan.alarms, hasLength(4));
        expect(scheduler.rescheduledEvents, hasLength(4));
        expect(scheduler.rescheduledEvents.map((event) => event.type), [
          AlarmEventType.preWarning,
          AlarmEventType.main,
          AlarmEventType.preWarning,
          AlarmEventType.main,
        ]);
        expect(
          scheduler.rescheduledEvents.map((event) => event.scheduledTime),
          [
            DateTime(2026, 6, 15, 1, 44),
            DateTime(2026, 6, 15, 1, 45),
            DateTime(2026, 6, 15, 1, 59),
            DateTime(2026, 6, 15, 2),
          ],
        );
      },
    );

    test(
      'confirm surfaces scheduler failures instead of pretending success',
      () {
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: _RecordingAlarmScheduler(
            failure: const SchedulingFailure(message: 'exact alarm denied'),
          ),
        );

        expect(
          () => useCase.confirm(
            _draftWithNumericDateAndSecondPrecisionTimes(date: '15-06-2026'),
          ),
          throwsA(
            isA<SchedulingFailure>().having(
              (failure) => failure.message,
              'message',
              contains('exact alarm denied'),
            ),
          ),
        );
      },
    );

    test(
      'confirm does not fall back to import date when schedule date is missing',
      () async {
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: _FakeLocalRepository(),
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: _RecordingAlarmScheduler(),
        );
        final draft = _draftWithBreakStartAndEndRows(includeDate: false);

        expect(
          () => useCase.confirm(draft),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('date'),
            ),
          ),
        );
      },
    );

    test(
      'reviewed alarm mapping uses parsed date instead of draft creation date',
      () {
        final plan = ReviewedAlarmPlanMapper.buildPlan(
          _draftWithBreakStartAndEndRows(),
          createdAt: DateTime.utc(2026, 5, 14, 12, 30),
        );

        expect(plan.mainAlarms.first.scheduledTime, DateTime(2026, 5, 20, 9));
        expect(plan.mainAlarms.first.scheduledTime.day, isNot(14));
      },
    );

    test(
      'confirm accepts numeric dash dates and Excel times with seconds',
      () async {
        final repository = _FakeLocalRepository();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 30)),
          scheduler: _RecordingAlarmScheduler(),
        );
        final draft = _draftWithNumericDateAndSecondPrecisionTimes(
          date: '15-06-2026',
        );

        final plan = await useCase.confirm(draft);

        expect(plan.mainAlarms.map((alarm) => alarm.scheduledTime), [
          DateTime(2026, 6, 15, 1, 45),
          DateTime(2026, 6, 15, 2),
        ]);
        expect(plan.alarms, hasLength(4));
        expect(await repository.getPlan('plan_draft-numeric-date'), plan);
      },
    );

    test('reviewed alarm mapping accepts 24-hour local wall-clock times', () {
      final plan = ReviewedAlarmPlanMapper.buildPlan(
        _draftWithSingleEntryTimes(
          date: '15-06-2026',
          times: ['02:00', '14:30', '23:59'],
        ),
        createdAt: DateTime(2026, 5, 14, 12, 30),
      );

      expect(plan.mainAlarms.map((alarm) => alarm.scheduledTime), [
        DateTime(2026, 6, 15, 2),
        DateTime(2026, 6, 15, 14, 30),
        DateTime(2026, 6, 15, 23, 59),
      ]);
      expect(
        plan.mainAlarms.every((alarm) => alarm.scheduledTime.isUtc),
        isFalse,
      );
    });

    test(
      'confirm rejects AM/PM and invalid 24-hour times instead of silently scheduling',
      () async {
        for (final invalidTime in ['2 PM', '2:00 PM', '24:00']) {
          final repository = _FakeLocalRepository();
          final scheduler = _RecordingAlarmScheduler();
          final useCase = ReviewAndConfirmUseCaseImpl(
            repository: repository,
            clock: _FixedClock(DateTime(2026, 5, 14, 12, 30)),
            scheduler: scheduler,
          );

          await expectLater(
            () => useCase.confirm(
              _draftWithSingleEntryTimes(
                date: '15-06-2026',
                times: [invalidTime],
              ),
            ),
            throwsA(
              isA<ScheduleValidationFailure>().having(
                (failure) => failure.message,
                'message',
                contains('24 horas'),
              ),
            ),
          );

          expect(scheduler.rescheduledEvents, isEmpty);
          expect(await repository.getAllPlans(), isEmpty);
        }
      },
    );

    test(
      'confirm blocks past enabled alarm events before persistence and scheduling',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime(2026, 6, 15, 2, 1)),
          scheduler: scheduler,
        );

        await expectLater(
          () => useCase.confirm(
            _draftWithSingleEntryTimes(date: '15-06-2026', times: ['02:00']),
          ),
          throwsA(
            isA<ScheduleValidationFailure>().having(
              (failure) => failure.message,
              'message',
              contains('Actualiza la fecha u hora'),
            ),
          ),
        );

        expect(scheduler.rescheduledEvents, isEmpty);
        expect(await repository.getAllPlans(), isEmpty);
      },
    );

    test(
      'confirm schedules future enabled alarm events successfully',
      () async {
        final repository = _FakeLocalRepository();
        final scheduler = _RecordingAlarmScheduler();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime(2026, 6, 15, 1, 58)),
          scheduler: scheduler,
        );

        final plan = await useCase.confirm(
          _draftWithSingleEntryTimes(date: '15-06-2026', times: ['02:00']),
        );

        expect(plan.mainAlarms.single.scheduledTime, DateTime(2026, 6, 15, 2));
        expect(scheduler.rescheduledEvents, plan.alarms);
        expect(await repository.getPlan(plan.id), plan);
      },
    );

    test(
      'reviewed alarm mapping accepts numeric slash dates and HH:mm:ss times',
      () {
        final plan = ReviewedAlarmPlanMapper.buildPlan(
          _draftWithNumericDateAndSecondPrecisionTimes(date: '15/06/2026'),
          createdAt: DateTime.utc(2026, 5, 14, 12, 30),
        );

        expect(plan.mainAlarms.map((alarm) => alarm.scheduledTime), [
          DateTime(2026, 6, 15, 1, 45),
          DateTime(2026, 6, 15, 2),
        ]);
      },
    );

    test(
      'reviewed alarm mapping deduplicates repeated date and time values',
      () {
        final plan = ReviewedAlarmPlanMapper.buildPlan(
          _draftWithBreakStartAndEndRows(duplicateFirstTime: true),
          createdAt: DateTime.utc(2026, 5, 14, 12, 30),
        );

        expect(
          plan.mainAlarms
              .where((alarm) => alarm.scheduledTime == DateTime(2026, 5, 20, 9))
              .length,
          1,
        );
        expect(plan.mainAlarms, hasLength(7));
      },
    );

    test(
      'confirmReview transitions a reviewing session to confirmed',
      () async {
        final repository = _FakeLocalRepository();
        final useCase = ReviewAndConfirmUseCaseImpl(
          repository: repository,
          clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 35)),
          scheduler: _RecordingAlarmScheduler(),
        );
        final reviewing = useCase.startReview(_draftWithLowConfidenceEntry());

        final confirmed = await useCase.confirmReview(reviewing);

        expect(confirmed.state, ReviewState.confirmed);
        expect(confirmed.draft.id, 'draft-1');
        expect(confirmed.canConfirm, isFalse);
        expect(await repository.getPlan('plan_draft-1'), isNotNull);
      },
    );

    test('cancel discards the draft without creating an alarm plan', () async {
      final repository = _FakeLocalRepository();
      await repository.saveDraft(_draftWithLowConfidenceEntry());
      final useCase = ReviewAndConfirmUseCaseImpl(
        repository: repository,
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 45)),
        scheduler: _RecordingAlarmScheduler(),
      );

      await useCase.cancel(_draftWithLowConfidenceEntry());

      expect(await repository.getDraft('draft-1'), isNull);
      expect(await repository.getAllPlans(), isEmpty);
    });

    test('cancelReview transitions a reviewing session to cancelled', () async {
      final repository = _FakeLocalRepository();
      await repository.saveDraft(_draftWithLowConfidenceEntry());
      final useCase = ReviewAndConfirmUseCaseImpl(
        repository: repository,
        clock: _FixedClock(DateTime.utc(2026, 5, 14, 12, 50)),
        scheduler: _RecordingAlarmScheduler(),
      );
      final reviewing = useCase.startReview(_draftWithLowConfidenceEntry());

      final cancelled = await useCase.cancelReview(reviewing);

      expect(cancelled.state, ReviewState.cancelled);
      expect(cancelled.draft.id, 'draft-1');
      expect(cancelled.canConfirm, isFalse);
      expect(await repository.getDraft('draft-1'), isNull);
    });
  });
}

ScheduleDraft _draftWithBreakStartAndEndRows({
  bool includeDate = true,
  bool duplicateFirstTime = false,
}) {
  final rows = [
    ('entry-1', '09:00', duplicateFirstTime ? '09:00' : '09:15'),
    ('entry-2', '10:00', '10:15'),
    ('entry-3', '11:00', '11:15'),
    ('entry-4', '12:00', '12:15'),
  ];
  return ScheduleDraft(
    id: 'draft-breaks',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: [
      for (final row in rows)
        RawEntry(
          id: row.$1,
          source: ImportSource.excel,
          fields: {
            if (includeDate) 'date': '20-MAYO-2026',
            'breakStart': row.$2,
            'breakEnd': row.$3,
          },
          confidence: const Confidence.high(),
        ),
    ],
  );
}

ScheduleDraft _draftWithNumericDateAndSecondPrecisionTimes({
  required String date,
}) {
  return ScheduleDraft(
    id: 'draft-numeric-date',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 9),
    entries: [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          'date': date,
          'breakStart': '01:45:00',
          'breakEnd': '02:00:00',
        },
        confidence: const Confidence.high(),
      ),
    ],
  );
}

ScheduleDraft _draftWithSingleEntryTimes({
  required String date,
  required List<String> times,
}) {
  final keys = ReviewedAlarmPlanMapper.alarmTimeFieldKeys;
  return ScheduleDraft(
    id: 'draft-single-entry-times-${times.join('-')}',
    source: ImportSource.excel,
    createdAt: DateTime(2026, 5, 14, 9),
    entries: [
      RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          'date': date,
          for (var index = 0; index < times.length; index++)
            keys[index]: times[index],
        },
        confidence: const Confidence.high(),
      ),
    ],
  );
}

Future<ExtractionFailure> _captureExtractionFailure(
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ExtractionFailure catch (failure) {
    return failure;
  }
  fail('Expected ExtractionFailure');
}

ScheduleDraft _draftWithLowConfidenceEntry({bool extraEntry = false}) {
  return ScheduleDraft(
    id: 'draft-1',
    source: ImportSource.excel,
    createdAt: DateTime.utc(2026, 5, 14, 12),
    entries: [
      const RawEntry(
        id: 'entry-1',
        source: ImportSource.excel,
        fields: {
          'name': 'Mika',
          'date': '20-MAYO-2026',
          'startTime': '08:00',
          'endTime': '',
        },
        confidence: Confidence.low(reason: 'Missing required fields: endTime'),
      ),
      if (extraEntry)
        const RawEntry(
          id: 'entry-2',
          source: ImportSource.excel,
          fields: {'name': 'Neko', 'date': '20-MAYO-2026', 'endTime': '18:00'},
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

final class _FakeOcrReader implements OcrReader {
  final List<String> lines;
  final List<OcrTextCell> spatialCells;
  Uint8List? receivedBytes;

  _FakeOcrReader({this.lines = const [], this.spatialCells = const []});

  @override
  Future<List<String>> extractLines(Uint8List imageBytes) async {
    receivedBytes = imageBytes;
    return lines;
  }

  @override
  Future<List<OcrTextCell>> extractTextCells(Uint8List imageBytes) async {
    receivedBytes = imageBytes;
    return spatialCells;
  }
}

OcrTextCell _cell(
  String text,
  double left,
  double top, {
  double width = 44,
  double height = 12,
}) =>
    OcrTextCell(text: text, left: left, top: top, width: width, height: height);

final class _FakeStructuredFileReader implements StructuredFileReader {
  final List<List<String>> rows;

  const _FakeStructuredFileReader(this.rows);

  @override
  Future<List<List<String>>> readRows(String filePath) async => rows;
}

final class _FakeLocalRepository implements LocalRepository {
  final Map<String, ScheduleDraft> drafts = {};
  final Map<String, AlarmPlan> plans = {};

  @override
  Future<void> saveDraft(ScheduleDraft draft) async {
    drafts[draft.id] = draft;
  }

  @override
  Future<ScheduleDraft?> getDraft(String id) async => drafts[id];

  @override
  Future<List<ScheduleDraft>> getAllDrafts() async => drafts.values.toList();

  @override
  Future<void> deleteDraft(String id) async {
    drafts.remove(id);
  }

  @override
  Future<void> savePlan(AlarmPlan plan) async {
    plans[plan.id] = plan;
  }

  @override
  Future<AlarmPlan?> getPlan(String id) async => plans[id];

  @override
  Future<List<AlarmPlan>> getAllPlans() async => plans.values.toList();

  @override
  Future<List<AlarmEvent>> getEventsForPlan(String planId) async =>
      plans[planId]?.alarms ?? const [];

  @override
  Future<List<AlarmEvent>> getAllEnabledEvents() async => plans.values
      .expand((plan) => plan.alarms)
      .where((event) => event.enabled)
      .toList();

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

final class _RecordingAlarmScheduler implements AlarmScheduler {
  final Object? failure;
  List<AlarmEvent> rescheduledEvents = const [];

  _RecordingAlarmScheduler({this.failure});

  @override
  Future<int> schedule(AlarmEvent event) async {
    if (failure != null) {
      throw failure!;
    }
    return event.androidAlarmId ?? event.id.hashCode;
  }

  @override
  Future<void> cancel(int nativeAlarmId) async {}

  @override
  Future<void> pruneNativeStaleAlarms(DateTime now) async {}

  @override
  Future<void> rescheduleAll(List<AlarmEvent> events) async {
    if (failure != null) {
      throw failure!;
    }
    rescheduledEvents = events.where((event) => event.enabled).toList();
  }

  @override
  Future<List<Map<String, Object?>>> syncAlarmOutcomes() async => [];

  @override
  int nativeIdFor(AlarmEvent event) => event.androidAlarmId ?? event.id.hashCode;
}

final class _FakePermissionGateway implements PermissionGateway {
  final bool exactAlarmPermissionGranted;
  final bool requestExactAlarmResult;
  final bool notificationPermissionGranted;
  final bool requestNotificationPermissionResult;
  final bool fullScreenIntentPermissionGranted;
  final bool requestFullScreenIntentPermissionResult;
  int exactAlarmChecks = 0;
  int exactAlarmRequests = 0;
  int notificationChecks = 0;
  int notificationRequests = 0;
  int fullScreenIntentChecks = 0;
  int fullScreenIntentRequests = 0;

  _FakePermissionGateway({
    this.exactAlarmPermissionGranted = true,
    this.requestExactAlarmResult = true,
    this.notificationPermissionGranted = true,
    this.requestNotificationPermissionResult = true,
    this.fullScreenIntentPermissionGranted = true,
    this.requestFullScreenIntentPermissionResult = true,
  });

  @override
  Future<bool> hasExactAlarmPermission() async {
    exactAlarmChecks++;
    return exactAlarmPermissionGranted;
  }

  @override
  Future<bool> requestExactAlarm() async {
    exactAlarmRequests++;
    return requestExactAlarmResult;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    notificationChecks++;
    return notificationPermissionGranted;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    notificationRequests++;
    return requestNotificationPermissionResult;
  }

  @override
  Future<bool> requestBatteryOptimization() async => true;

  @override
  Future<bool> hasFullScreenIntentPermission() async {
    fullScreenIntentChecks++;
    return fullScreenIntentPermissionGranted;
  }

  @override
  Future<bool> requestFullScreenIntentPermission() async {
    fullScreenIntentRequests++;
    return requestFullScreenIntentPermissionResult;
  }
}
