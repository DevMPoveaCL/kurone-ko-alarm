import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// DTO for a raw entry on its way to/from persistence.
final class RawEntryDto {
  final String id;
  final ImportSource source;
  final Map<String, String> fields;
  final Confidence confidence;

  const RawEntryDto({
    required this.id,
    required this.source,
    required this.fields,
    required this.confidence,
  });
}

/// DTO for a schedule draft persisted as JSON.
final class ScheduleDraftDto {
  final String id;
  final ImportSource source;
  final List<RawEntryDto> entries;
  final DateTime createdAt;

  const ScheduleDraftDto({
    required this.id,
    required this.source,
    required this.entries,
    required this.createdAt,
  });
}
