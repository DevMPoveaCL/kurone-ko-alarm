import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/content_classifier.dart';

/// Converts classification completeness and ambiguity into review confidence.
final class ConfidenceScorer {
  const ConfidenceScorer();

  Confidence score(ClassificationResult result) {
    final reasons = <String>[];

    if (result.missingRequiredFields.isNotEmpty) {
      reasons.add(
        'Missing required fields: ${result.missingRequiredFields.join(', ')}',
      );
    }
    if (result.ambiguousColumns.isNotEmpty) {
      reasons.add('Ambiguous columns: ${result.ambiguousColumns.join(', ')}');
    }
    if (result.fields.isEmpty) {
      reasons.add('No usable schedule fields');
    }

    if (reasons.isEmpty) {
      return const Confidence.high();
    }

    if (result.missingRequiredFields.isEmpty && result.fields.isNotEmpty) {
      return Confidence.medium(
        reason: reasons.join('; '),
        ambiguousColumns: result.ambiguousColumns,
      );
    }

    return Confidence.low(
      reason: reasons.join('; '),
      ambiguousColumns: result.ambiguousColumns,
    );
  }
}
