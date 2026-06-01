import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';

/// Draft schedule before human confirmation.
final class ScheduleDraft {
  final String id;
  final ImportSource source;
  final List<RawEntry> entries;
  final DateTime createdAt;

  const ScheduleDraft({
    required this.id,
    required this.source,
    required this.entries,
    required this.createdAt,
  });

  /// Returns only low-confidence entries for highlighted review.
  List<RawEntry> get lowConfidenceEntries =>
      entries.where((e) => e.confidence.level == ConfidenceLevel.low).toList();

  ScheduleDraft copyWith({
    String? id,
    ImportSource? source,
    List<RawEntry>? entries,
    DateTime? createdAt,
  }) {
    return ScheduleDraft(
      id: id ?? this.id,
      source: source ?? this.source,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleDraft &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          source == other.source &&
          entries == other.entries &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, source, entries, createdAt);

  @override
  String toString() =>
      'ScheduleDraft(id: $id, source: $source, entries: ${entries.length}, '
      'createdAt: $createdAt)';
}
