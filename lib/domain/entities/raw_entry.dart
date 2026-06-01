import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// A raw extracted entry from OCR or Excel before classification.
final class RawEntry {
  final String id;
  final ImportSource source;
  final Map<String, String> fields;
  final Confidence confidence;

  const RawEntry({
    required this.id,
    required this.source,
    required this.fields,
    required this.confidence,
  });

  RawEntry copyWith({
    String? id,
    ImportSource? source,
    Map<String, String>? fields,
    Confidence? confidence,
  }) {
    return RawEntry(
      id: id ?? this.id,
      source: source ?? this.source,
      fields: fields ?? this.fields,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source &&
          fields == other.fields &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(id, source, fields, confidence);

  @override
  String toString() =>
      'RawEntry(id: $id, source: $source, fields: $fields, confidence: $confidence)';
}
