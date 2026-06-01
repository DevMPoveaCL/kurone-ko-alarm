import 'dart:typed_data';

/// OCR text with image-space geometry preserved for spatial table recovery.
final class OcrTextCell {
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  const OcrTextCell({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get centerX => left + width / 2;

  double get centerY => top + height / 2;

  OcrTextCell copyWith({String? text}) => OcrTextCell(
    text: text ?? this.text,
    left: left,
    top: top,
    width: width,
    height: height,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrTextCell &&
          other.text == text &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(text, left, top, width, height);
}

/// Outbound port for OCR text extraction from images.
abstract class OcrReader {
  /// Extracts lines of text from an image.
  Future<List<String>> extractLines(Uint8List imageBytes);

  /// Extracts text cells with bounding boxes when the OCR adapter supports it.
  Future<List<OcrTextCell>> extractTextCells(Uint8List imageBytes) async =>
      const [];
}
