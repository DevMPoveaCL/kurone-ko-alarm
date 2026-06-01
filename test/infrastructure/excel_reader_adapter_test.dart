import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/file_reader/excel_reader_adapter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kurone_excel_reader_test_',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ExcelReaderAdapter', () {
    test('readRows parses the first worksheet into string cells', () async {
      final path = '${tempDir.path}${Platform.pathSeparator}schedule.xlsx';
      final workbook = Excel.createExcel();
      workbook.rename('Sheet1', 'Horarios');
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('A1'),
        TextCellValue('Nombre'),
      );
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('B1'),
        TextCellValue('Entrada'),
      );
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('C1'),
        TextCellValue('Descanso'),
      );
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('A2'),
        TextCellValue('Mika'),
      );
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('B2'),
        TextCellValue('09:00'),
      );
      workbook.updateCell(
        'Horarios',
        CellIndex.indexByString('C2'),
        TextCellValue('13:00'),
      );
      await File(path).writeAsBytes(workbook.encode()!, flush: true);

      final rows = await ExcelReaderAdapter().readRows(path);

      expect(rows, [
        ['Nombre', 'Entrada', 'Descanso'],
        ['Mika', '09:00', '13:00'],
      ]);
    });

    test(
      'readRows skips fully empty rows while preserving empty cells inside a row',
      () async {
        final path =
            '${tempDir.path}${Platform.pathSeparator}schedule_with_gap.xlsx';
        final workbook = Excel.createExcel();
        workbook.rename('Sheet1', 'Horarios');
        workbook.updateCell(
          'Horarios',
          CellIndex.indexByString('A1'),
          TextCellValue('Nombre'),
        );
        workbook.updateCell(
          'Horarios',
          CellIndex.indexByString('C1'),
          TextCellValue('Salida'),
        );
        workbook.updateCell(
          'Horarios',
          CellIndex.indexByString('A3'),
          TextCellValue('Neko'),
        );
        workbook.updateCell(
          'Horarios',
          CellIndex.indexByString('C3'),
          TextCellValue('18:00'),
        );
        await File(path).writeAsBytes(workbook.encode()!, flush: true);

        final rows = await ExcelReaderAdapter().readRows(path);

        expect(rows, [
          ['Nombre', '', 'Salida'],
          ['Neko', '', '18:00'],
        ]);
      },
    );

    test(
      'readRows wraps corrupted workbooks as excel extraction failures',
      () async {
        final path = '${tempDir.path}${Platform.pathSeparator}corrupted.xlsx';
        await File(path).writeAsString('this is not an xlsx file', flush: true);

        final extraction = ExcelReaderAdapter().readRows(path);

        await expectLater(
          extraction,
          throwsA(
            isA<ExtractionFailure>()
                .having(
                  (failure) => failure.source,
                  'source',
                  ImportSource.excel,
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  contains('xlsx'),
                ),
          ),
        );
      },
    );
  });
}
