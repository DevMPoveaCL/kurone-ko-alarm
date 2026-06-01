import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// Inbound port for importing a schedule from an image or Excel file.
abstract class ImportScheduleUseCase {
  /// Imports a schedule from the given file path.
  Future<ScheduleDraft> import({
    required String filePath,
    required ImportSource source,
  });
}
