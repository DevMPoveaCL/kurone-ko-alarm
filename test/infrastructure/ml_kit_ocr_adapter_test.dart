import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/ocr/ml_kit_ocr_adapter.dart';

void main() {
  group('MlKitOcrAdapter', () {
    test(
      'extractLines returns trimmed non-empty lines in recognizer order',
      () async {
        final recognizer = _FakeTextRecognizerGateway(
          lines: [
            ' Entrada 09:00 ',
            '',
            ' Descanso 13:00 ',
            '   ',
            'Salida 18:00',
          ],
        );
        final adapter = MlKitOcrAdapter(recognizer: recognizer);

        final lines = await adapter.extractLines(Uint8List.fromList([1, 2, 3]));

        expect(lines, ['Entrada 09:00', 'Descanso 13:00', 'Salida 18:00']);
        expect(recognizer.receivedBytes, [1, 2, 3]);
      },
    );

    test('extractTextCells preserves recognized text geometry', () async {
      final recognizer = _FakeTextRecognizerGateway(
        spatialCells: const [
          OcrTextCell(text: ' Fecha ', left: 12, top: 8, width: 40, height: 10),
          OcrTextCell(text: '   ', left: 60, top: 8, width: 12, height: 10),
          OcrTextCell(
            text: '09-MAYO-2026',
            left: 12,
            top: 36,
            width: 88,
            height: 10,
          ),
        ],
      );
      final adapter = MlKitOcrAdapter(recognizer: recognizer);

      final cells = await adapter.extractTextCells(
        Uint8List.fromList([4, 5, 6]),
      );

      expect(cells, [
        const OcrTextCell(
          text: 'Fecha',
          left: 12,
          top: 8,
          width: 40,
          height: 10,
        ),
        const OcrTextCell(
          text: '09-MAYO-2026',
          left: 12,
          top: 36,
          width: 88,
          height: 10,
        ),
      ]);
      expect(recognizer.receivedBytes, [4, 5, 6]);
    });

    test(
      'extractLines wraps recognizer failures as image extraction failures',
      () async {
        final adapter = MlKitOcrAdapter(
          recognizer: _FakeTextRecognizerGateway(
            error: FormatException('not an image'),
          ),
        );

        final extraction = adapter.extractLines(
          Uint8List.fromList([255, 0, 255]),
        );

        await expectLater(
          extraction,
          throwsA(
            isA<ExtractionFailure>()
                .having(
                  (failure) => failure.source,
                  'source',
                  ImportSource.image,
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  contains('not an image'),
                ),
          ),
        );
      },
    );

    test('preprocessor upscales very wide low-height screenshots for OCR', () {
      const preprocessor = OcrImagePreprocessor();
      final source = img.Image(width: 1600, height: 320);
      final bytes = Uint8List.fromList(img.encodePng(source));

      final result = preprocessor.prepareForOcr(bytes);

      expect(result.preprocessed, isTrue);
      expect(result.reason, contains('wide screenshot'));
      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.width, 3200);
      expect(decoded.height, 640);
    });

    test(
      'preprocessor can run the same resize work off the UI isolate',
      () async {
        const preprocessor = OcrImagePreprocessor();
        final source = img.Image(width: 1600, height: 320);
        final bytes = Uint8List.fromList(img.encodePng(source));

        final result = await preprocessor.prepareForOcrInBackground(bytes);

        expect(result.preprocessed, isTrue);
        expect(result.reason, contains('wide screenshot'));
        final decoded = img.decodeImage(result.bytes)!;
        expect(decoded.width, 3200);
        expect(decoded.height, 640);
      },
    );

    test(
      'preprocessor leaves sufficiently large non-wide images untouched',
      () {
        const preprocessor = OcrImagePreprocessor();
        final source = img.Image(width: 1200, height: 1200);
        final bytes = Uint8List.fromList(img.encodePng(source));

        final result = preprocessor.prepareForOcr(bytes);

        expect(result.preprocessed, isFalse);
        expect(result.bytes, bytes);
      },
    );
  });
}

final class _FakeTextRecognizerGateway implements MlKitTextRecognizerGateway {
  _FakeTextRecognizerGateway({
    this.lines = const [],
    this.spatialCells = const [],
    this.error,
  });

  final List<String> lines;
  final List<OcrTextCell> spatialCells;
  final Object? error;
  List<int>? receivedBytes;

  @override
  Future<List<String>> extractLinesFromImageBytes(Uint8List imageBytes) async {
    receivedBytes = imageBytes.toList(growable: false);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return lines;
  }

  @override
  Future<List<OcrTextCell>> extractTextCellsFromImageBytes(
    Uint8List imageBytes,
  ) async {
    receivedBytes = imageBytes.toList(growable: false);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return spatialCells;
  }

  @override
  Future<void> close() async {}
}
