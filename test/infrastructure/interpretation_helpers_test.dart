import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/column_inference_engine.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/content_classifier.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/confidence_scorer.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/normalizer.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/agnostic_ocr_interpreter.dart';

void main() {
  group('ColumnInferenceEngine', () {
    test('detects semantic columns from Spanish headers in tabular rows', () {
      const engine = ColumnInferenceEngine();

      final result = engine.detectColumnsFromRows([
        ['Empleado', 'Entrada', 'Salida', 'Descanso'],
        ['Mika', '08:00', '17:00', '12:30'],
      ]);

      expect(
        result.headers,
        equals(['empleado', 'entrada', 'salida', 'descanso']),
      );
      expect(
        result.columns.map((column) => column.semanticKey),
        equals(['name', 'startTime', 'endTime', 'breakStart']),
      );
      expect(result.ambiguousColumns, isEmpty);
    });

    test('clusters OCR cells by x coordinate before matching headers', () {
      const engine = ColumnInferenceEngine(xTolerance: 18);

      final result = engine.detectColumnsFromSpatialCells(const [
        SpatialTextCell(text: 'Turno', x: 15, y: 0),
        SpatialTextCell(text: 'Horario', x: 105, y: 0),
        SpatialTextCell(text: 'Descanso', x: 210, y: 0),
        SpatialTextCell(text: 'A', x: 18, y: 30),
        SpatialTextCell(text: '08:00-17:00', x: 112, y: 30),
        SpatialTextCell(text: '12:00', x: 205, y: 30),
      ]);

      expect(result.headers, equals(['turno', 'horario', 'descanso']));
      expect(
        result.columns.map((column) => column.semanticKey),
        equals(['shift', 'schedule', 'breakStart']),
      );
      expect(result.ambiguousColumns, isEmpty);
    });

    test('detects real Excel headers with accent variants', () {
      const engine = ColumnInferenceEngine();

      final result = engine.detectColumnsFromRows([
        [
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
        ],
        [
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
        ],
      ]);

      expect(
        result.columns.map((column) => column.semanticKey),
        equals([
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
    });
  });

  group('ContentClassifier', () {
    test('maps recognized headers and row cells to semantic fields', () {
      const classifier = ContentClassifier();

      final result = classifier.classify(
        const ColumnInferenceResult(
          columns: [
            InferredColumn(index: 0, header: 'empleado', semanticKey: 'name'),
            InferredColumn(
              index: 1,
              header: 'entrada',
              semanticKey: 'startTime',
            ),
            InferredColumn(index: 2, header: 'salida', semanticKey: 'endTime'),
            InferredColumn(
              index: 3,
              header: 'descanso',
              semanticKey: 'breakStart',
            ),
          ],
          ambiguousColumns: [],
        ),
        ['Mika', '08:00', '17:00', '12:30'],
      );

      expect(
        result.fields,
        equals({
          'name': 'Mika',
          'startTime': '08:00',
          'endTime': '17:00',
          'breakStart': '12:30',
        }),
      );
      expect(result.missingRequiredFields, isEmpty);
    });

    test('reports missing required schedule fields for incomplete rows', () {
      const classifier = ContentClassifier();

      final result = classifier.classify(
        const ColumnInferenceResult(
          columns: [
            InferredColumn(index: 0, header: 'empleado', semanticKey: 'name'),
            InferredColumn(
              index: 1,
              header: 'entrada',
              semanticKey: 'startTime',
            ),
          ],
          ambiguousColumns: [],
        ),
        ['Mika', '08:00'],
      );

      expect(result.fields, equals({'name': 'Mika', 'startTime': '08:00'}));
      expect(result.missingRequiredFields, equals(['endTime']));
    });
  });

  group('ConfidenceScorer', () {
    test('assigns high confidence to complete unambiguous classifications', () {
      const scorer = ConfidenceScorer();

      final confidence = scorer.score(
        const ClassificationResult(
          fields: {
            'startTime': '08:00',
            'endTime': '17:00',
            'breakStart': '12:30',
          },
        ),
      );

      expect(confidence.level, ConfidenceLevel.high);
      expect(confidence.reason, isNull);
      expect(confidence.ambiguousColumns, isEmpty);
    });

    test(
      'assigns low confidence with reasons for missing and ambiguous data',
      () {
        const scorer = ConfidenceScorer();

        final confidence = scorer.score(
          const ClassificationResult(
            fields: {'startTime': '08:00'},
            missingRequiredFields: ['endTime'],
            ambiguousColumns: ['col_2'],
          ),
        );

        expect(confidence.level, ConfidenceLevel.low);
        expect(confidence.reason, contains('Missing required fields: endTime'));
        expect(confidence.reason, contains('Ambiguous columns: col_2'));
        expect(confidence.ambiguousColumns, equals(['col_2']));
      },
    );
  });

  group('Normalizer', () {
    test('converts Excel rows into RawEntry objects with semantic fields', () {
      const normalizer = Normalizer();

      final entries = normalizer.toCommonFormat(
        source: ImportSource.excel,
        rows: [
          [' Empleado ', 'Entrada', 'Salida', 'Descanso'],
          ['Mika', '08:00', '17:00', '12:30'],
          ['Neko', '09:00', '18:00', '13:00'],
        ],
      );

      expect(entries.map((entry) => entry.id), equals(['excel_0', 'excel_1']));
      expect(
        entries.first.fields,
        equals({
          'name': 'Mika',
          'startTime': '08:00',
          'endTime': '17:00',
          'breakStart': '12:30',
        }),
      );
      expect(entries.first.confidence.level, ConfidenceLevel.high);
    });

    test('skips empty rows and tags ambiguous OCR rows as low confidence', () {
      const normalizer = Normalizer();

      final entries = normalizer.toCommonFormat(
        source: ImportSource.image,
        rows: [
          ['Horario', 'Columna rara'],
          ['', ''],
          ['08:00-17:00', '??'],
        ],
      );

      expect(entries.length, 1);
      expect(entries.single.id, 'image_0');
      expect(entries.single.fields, equals({'schedule': '08:00-17:00'}));
      expect(entries.single.confidence.level, ConfidenceLevel.low);
      expect(entries.single.confidence.ambiguousColumns, equals(['col_1']));
    });
  });

  group('Agnostic OCR interpretation', () {
    test(
      'classifies zero-header date and many times into a reviewable draft entry',
      () {
        const interpreter = AgnosticOcrInterpreter();

        final entries = interpreter.interpret(
          lines: const [
            '09-MAYO-2026 00:00 02:30 02:45 04:30 05:00 05:00 05:15 07:00 07:15 08:30',
          ],
          cells: const [],
          source: ImportSource.image,
        );

        expect(entries, hasLength(1));
        expect(entries.single.fields, containsPair('date', '09-MAYO-2026'));
        expect(entries.single.fields, containsPair('startTime', '00:00'));
        expect(entries.single.fields, containsPair('breakStart', '02:30'));
        expect(entries.single.fields, containsPair('breakEnd', '02:45'));
        expect(entries.single.fields, containsPair('lunchStart', '04:30'));
        expect(entries.single.fields, containsPair('lunchEnd', '05:00'));
        expect(entries.single.fields, containsPair('endTime', '08:30'));
        expect(entries.single.confidence.level, ConfidenceLevel.medium);
        expect(entries.single.confidence.reason, contains('headerless'));
      },
    );

    test(
      'tokenizes a large OCR cell into date and time tokens before candidate extraction',
      () {
        const interpreter = AgnosticOcrInterpreter();

        final result = interpreter.interpretWithDiagnostics(
          lines: const ['Captura privada'],
          cells: const [
            OcrTextCell(
              text: '09-MAYO-2026 00:00 02:30 02:45 04:30 05:00 08:30',
              left: 10,
              top: 40,
              width: 620,
              height: 24,
            ),
          ],
          source: ImportSource.image,
        );

        expect(result.entries, hasLength(1));
        expect(result.diagnostics.dateTokenCount, 1);
        expect(result.diagnostics.timeTokenCount, 6);
        expect(result.diagnostics.candidateRowCount, 1);
        expect(
          result.entries.single.fields,
          containsPair('date', '09-MAYO-2026'),
        );
        expect(
          result.entries.single.fields,
          containsPair('startTime', '00:00'),
        );
        expect(result.entries.single.fields, containsPair('endTime', '08:30'));
      },
    );

    test(
      'explains candidate rejection when dates exist but no enough times',
      () {
        const interpreter = AgnosticOcrInterpreter();

        final result = interpreter.interpretWithDiagnostics(
          lines: const ['09-MAYO-2026 sin horas utilizables'],
          cells: const [],
          source: ImportSource.image,
        );

        expect(result.entries, isEmpty);
        expect(result.diagnostics.dateTokenCount, 1);
        expect(result.diagnostics.timeTokenCount, 0);
        expect(
          result.diagnostics.rejectionReasons,
          contains('no time tokens detected'),
        );
      },
    );

    test('uses sparse geometry rows before header anchors are available', () {
      const interpreter = AgnosticOcrInterpreter();

      final entries = interpreter.interpret(
        lines: const [
          'texto con 09-MAYO-2026',
          'texto privado',
          'otro texto privado',
        ],
        cells: const [
          OcrTextCell(text: 'Rut', left: 10, top: 8, width: 24, height: 12),
          OcrTextCell(text: 'Agente', left: 40, top: 8, width: 50, height: 12),
          OcrTextCell(
            text: '09-MAYO-2026',
            left: 10,
            top: 40,
            width: 90,
            height: 12,
          ),
          OcrTextCell(text: '00:00', left: 140, top: 40, width: 44, height: 12),
          OcrTextCell(text: '10:00', left: 240, top: 40, width: 44, height: 12),
        ],
        source: ImportSource.image,
      );

      expect(entries, hasLength(1));
      expect(entries.single.fields, containsPair('date', '09-MAYO-2026'));
      expect(entries.single.fields, containsPair('startTime', '00:00'));
      expect(entries.single.fields, containsPair('endTime', '10:00'));
      expect(entries.single.confidence.level, ConfidenceLevel.medium);
    });

    test('does not pretend success for a row with date and only one time', () {
      const interpreter = AgnosticOcrInterpreter();

      final entries = interpreter.interpret(
        lines: const ['09-MAYO-2026 00:00'],
        cells: const [],
        source: ImportSource.image,
      );

      expect(entries, isEmpty);
    });

    test(
      'keeps night-shift end after midnight as reviewable medium confidence',
      () {
        const interpreter = AgnosticOcrInterpreter();

        final entries = interpreter.interpret(
          lines: const ['09-MAYO-2026 22:00 23:30 23:45 02:00'],
          cells: const [],
          source: ImportSource.image,
        );

        expect(entries, hasLength(1));
        expect(entries.single.fields, containsPair('startTime', '22:00'));
        expect(entries.single.fields, containsPair('breakStart', '23:30'));
        expect(entries.single.fields, containsPair('breakEnd', '23:45'));
        expect(entries.single.fields, containsPair('endTime', '02:00'));
        expect(entries.single.confidence.level, ConfidenceLevel.medium);
        expect(entries.single.confidence.reason, contains('non-monotonic'));
      },
    );

    test(
      'deduplicates and bounds a noisy OCR token stream before review output',
      () {
        const interpreter = AgnosticOcrInterpreter();

        final repeatedRows = [
          for (var index = 0; index < 36; index++)
            '${(index % 30) + 1}-MAYO-2026 00:00 02:30 02:45 08:30',
        ];

        final entries = interpreter.interpret(
          lines: repeatedRows,
          cells: const [],
          source: ImportSource.image,
        );

        expect(entries, hasLength(24));
        expect(
          entries.map((entry) => entry.fields['date']).toSet(),
          hasLength(24),
        );
        expect(entries.first.fields, containsPair('date', '1-MAYO-2026'));
        expect(entries.last.fields, containsPair('date', '24-MAYO-2026'));
      },
    );
  });
}
