import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/column_inference_engine.dart';

/// Classification output for one normalized row.
final class ClassificationResult {
  final Map<String, String> fields;
  final List<String> missingRequiredFields;
  final List<String> ambiguousColumns;

  const ClassificationResult({
    required this.fields,
    this.missingRequiredFields = const [],
    this.ambiguousColumns = const [],
  });
}

/// Maps inferred columns and row cells into semantic schedule fields.
final class ContentClassifier {
  static const _requiredFields = ['endTime'];

  const ContentClassifier();

  ClassificationResult classify(
    ColumnInferenceResult inference,
    List<String> row,
  ) {
    final fields = <String, String>{};

    for (final column in inference.columns) {
      if (column.index >= row.length) {
        continue;
      }
      final value = row[column.index].trim();
      if (value.isEmpty || column.semanticKey.startsWith('col_')) {
        continue;
      }
      fields[column.semanticKey] = value;
    }

    final missingRequiredFields = _requiredFields
        .where((field) => !fields.containsKey(field))
        .toList();

    return ClassificationResult(
      fields: fields,
      missingRequiredFields: missingRequiredFields,
      ambiguousColumns: inference.ambiguousColumns,
    );
  }
}
