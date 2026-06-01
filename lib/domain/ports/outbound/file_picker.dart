/// Result of a file picking operation.
final class FilePickResult {
  final String path;
  final String fileName;
  final String? extension;

  const FilePickResult({
    required this.path,
    required this.fileName,
    this.extension,
  });
}

/// Supported file types for import.
enum FilePickType { image, excel, any }

/// Outbound port for picking files from the device.
abstract class FilePicker {
  /// Opens the file picker for the given file type.
  Future<FilePickResult?> pick({required FilePickType type});
}
