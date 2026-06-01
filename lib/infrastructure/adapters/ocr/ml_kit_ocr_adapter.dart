import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// Testable gateway around ML Kit's [TextRecognizer].
abstract interface class MlKitTextRecognizerGateway {
  Future<List<String>> extractLinesFromImageBytes(Uint8List imageBytes);

  Future<List<OcrTextCell>> extractTextCellsFromImageBytes(
    Uint8List imageBytes,
  );

  Future<void> close();
}

/// OCR adapter backed by on-device Google ML Kit text recognition.
final class MlKitOcrAdapter implements OcrReader {
  MlKitOcrAdapter({
    MlKitTextRecognizerGateway? recognizer,
    OcrImagePreprocessor preprocessor = const OcrImagePreprocessor(),
  }) : _recognizer = recognizer ?? _DefaultMlKitTextRecognizerGateway(),
       _preprocessor = preprocessor;

  final MlKitTextRecognizerGateway _recognizer;
  final OcrImagePreprocessor _preprocessor;

  @override
  Future<List<String>> extractLines(Uint8List imageBytes) async {
    try {
      final prepared = await _preprocessor.prepareForOcrInBackground(
        imageBytes,
      );
      final lines = await _recognizer.extractLinesFromImageBytes(
        prepared.bytes,
      );
      return lines
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw ExtractionFailure(
        source: ImportSource.image,
        message: 'Unable to extract text from image: $error',
      );
    }
  }

  @override
  Future<List<OcrTextCell>> extractTextCells(Uint8List imageBytes) async {
    try {
      final prepared = await _preprocessor.prepareForOcrInBackground(
        imageBytes,
      );
      final cells = await _recognizer.extractTextCellsFromImageBytes(
        prepared.bytes,
      );
      return cells
          .map((cell) => cell.copyWith(text: cell.text.trim()))
          .where((cell) => cell.text.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw ExtractionFailure(
        source: ImportSource.image,
        message: 'Unable to extract text geometry from image: $error',
      );
    }
  }

  Future<void> close() => _recognizer.close();
}

final class OcrPreparedImage {
  final Uint8List bytes;
  final bool preprocessed;
  final String? reason;

  const OcrPreparedImage({
    required this.bytes,
    required this.preprocessed,
    this.reason,
  });
}

final class OcrImagePreprocessor {
  final int minReadableHeight;
  final double wideAspectRatio;
  final int upscaleFactor;

  const OcrImagePreprocessor({
    this.minReadableHeight = 640,
    this.wideAspectRatio = 3.0,
    this.upscaleFactor = 2,
  });

  OcrPreparedImage prepareForOcr(Uint8List imageBytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } catch (_) {
      return OcrPreparedImage(bytes: imageBytes, preprocessed: false);
    }
    if (decoded == null) {
      return OcrPreparedImage(bytes: imageBytes, preprocessed: false);
    }

    final aspectRatio = decoded.width / decoded.height;
    final shouldUpscale =
        decoded.height < minReadableHeight && aspectRatio >= wideAspectRatio;
    if (!shouldUpscale) {
      return OcrPreparedImage(bytes: imageBytes, preprocessed: false);
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width * upscaleFactor,
      height: decoded.height * upscaleFactor,
      interpolation: img.Interpolation.cubic,
    );
    return OcrPreparedImage(
      bytes: Uint8List.fromList(img.encodePng(resized)),
      preprocessed: true,
      reason: 'wide screenshot upscaled for OCR readability',
    );
  }

  Future<OcrPreparedImage> prepareForOcrInBackground(Uint8List imageBytes) {
    return Isolate.run(() => prepareForOcr(imageBytes));
  }
}

final class _DefaultMlKitTextRecognizerGateway
    implements MlKitTextRecognizerGateway {
  _DefaultMlKitTextRecognizerGateway({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<List<String>> extractLinesFromImageBytes(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw const FormatException('image bytes are empty');
    }

    final imageFile = await _writeTemporaryImage(imageBytes);
    final tempDir = imageFile.parent;
    try {
      final recognizedText = await _recognizer.processImage(
        InputImage.fromFilePath(imageFile.path),
      );
      return [
        for (final block in recognizedText.blocks)
          for (final line in block.lines) line.text,
      ];
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<List<OcrTextCell>> extractTextCellsFromImageBytes(
    Uint8List imageBytes,
  ) async {
    if (imageBytes.isEmpty) {
      throw const FormatException('image bytes are empty');
    }

    final imageFile = await _writeTemporaryImage(imageBytes);
    final tempDir = imageFile.parent;
    try {
      final recognizedText = await _recognizer.processImage(
        InputImage.fromFilePath(imageFile.path),
      );
      return [
        for (final block in recognizedText.blocks)
          for (final line in block.lines)
            for (final element in line.elements)
              OcrTextCell(
                text: element.text,
                left: element.boundingBox.left,
                top: element.boundingBox.top,
                width: element.boundingBox.width,
                height: element.boundingBox.height,
              ),
      ];
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> close() => _recognizer.close();

  Future<File> _writeTemporaryImage(Uint8List imageBytes) async {
    final tempDir = await Directory.systemTemp.createTemp('kurone_mlkit_ocr_');
    final imageFile = File(
      '${tempDir.path}${Platform.pathSeparator}input-image.jpg',
    );
    return imageFile.writeAsBytes(imageBytes, flush: true);
  }
}
