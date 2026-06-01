import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/column_inference_engine.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/confidence_scorer.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/content_classifier.dart';

/// Normalizes OCR and Excel tabular rows into shared RawEntry objects.
final class Normalizer {
  final ColumnInferenceEngine columnInferenceEngine;
  final ContentClassifier contentClassifier;
  final ConfidenceScorer confidenceScorer;

  const Normalizer({
    this.columnInferenceEngine = const ColumnInferenceEngine(),
    this.contentClassifier = const ContentClassifier(),
    this.confidenceScorer = const ConfidenceScorer(),
  });

  List<RawEntry> toCommonFormat({
    required ImportSource source,
    required List<List<String>> rows,
  }) {
    final normalizedRows = rows
        .map((row) => row.map((cell) => cell.trim()).toList())
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    if (normalizedRows.length < 2) {
      return const [];
    }

    final inference = columnInferenceEngine.detectColumnsFromRows(
      normalizedRows,
    );
    final dataRows = normalizedRows.skip(1);
    final entries = <RawEntry>[];

    for (final row in dataRows) {
      final classification = contentClassifier.classify(inference, row);
      if (classification.fields.isEmpty) {
        continue;
      }
      entries.add(
        RawEntry(
          id: '${source.name}_${entries.length}',
          source: source,
          fields: classification.fields,
          confidence: confidenceScorer.score(classification),
        ),
      );
    }

    return entries;
  }
}
