/// Confidence level for extracted schedule entries.
enum ConfidenceLevel { high, medium, low }

/// A confidence score with optional reason and ambiguous column tags.
final class Confidence {
  final ConfidenceLevel level;
  final String? reason;
  final List<String> ambiguousColumns;

  const Confidence({
    required this.level,
    this.reason,
    this.ambiguousColumns = const [],
  });

  const Confidence.high() : this(level: ConfidenceLevel.high);

  const Confidence.medium({String? reason, List<String>? ambiguousColumns})
    : this(
        level: ConfidenceLevel.medium,
        reason: reason,
        ambiguousColumns: ambiguousColumns ?? const [],
      );

  const Confidence.low({required String reason, List<String>? ambiguousColumns})
    : this(
        level: ConfidenceLevel.low,
        reason: reason,
        ambiguousColumns: ambiguousColumns ?? const [],
      );

  bool get isLow => level == ConfidenceLevel.low;
  bool get isHigh => level == ConfidenceLevel.high;
  bool get isMedium => level == ConfidenceLevel.medium;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Confidence &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          reason == other.reason &&
          ambiguousColumns == other.ambiguousColumns;

  @override
  int get hashCode => Object.hash(level, reason, ambiguousColumns);

  @override
  String toString() =>
      'Confidence(level: $level, reason: $reason, ambiguousColumns: $ambiguousColumns)';
}
