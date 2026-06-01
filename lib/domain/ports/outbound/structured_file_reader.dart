/// Outbound port for reading structured data from files (e.g. Excel).
abstract class StructuredFileReader {
  /// Reads rows of data from the given file path.
  Future<List<List<String>>> readRows(String filePath);
}
