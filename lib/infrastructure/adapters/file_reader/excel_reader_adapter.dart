import 'dart:io';

import 'package:excel/excel.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/structured_file_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// Structured file reader backed by the `excel` package for `.xlsx` files.
final class ExcelReaderAdapter implements StructuredFileReader {
  @override
  Future<List<List<String>>> readRows(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook.tables.values.firstOrNull;
      if (sheet == null) {
        return const [];
      }

      return sheet.rows
          .map(_rowToStrings)
          .where((row) => row.any((cell) => cell.isNotEmpty))
          .map(_trimTrailingEmptyCells)
          .toList(growable: false);
    } catch (error) {
      throw ExtractionFailure(
        source: ImportSource.excel,
        message: 'Unable to parse xlsx file: $error',
      );
    }
  }

  List<String> _rowToStrings(List<Data?> row) {
    return row
        .map((cell) => _cellValueToString(cell?.value))
        .toList(growable: false);
  }

  String _cellValueToString(CellValue? value) {
    return switch (value) {
      null => '',
      DateCellValue() => _formatDate(value.year, value.month, value.day),
      DateTimeCellValue() =>
        value.hour == 0 &&
                value.minute == 0 &&
                value.second == 0 &&
                value.millisecond == 0 &&
                value.microsecond == 0
            ? _formatDate(value.year, value.month, value.day)
            : _formatTime(value.hour, value.minute, value.second),
      TimeCellValue() => _formatTime(value.hour, value.minute, value.second),
      _ => value.toString().trim(),
    };
  }

  String _formatDate(int year, int month, int day) {
    return '${day.toString().padLeft(2, '0')}-'
        '${month.toString().padLeft(2, '0')}-$year';
  }

  String _formatTime(int hour, int minute, int second) {
    final base =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
    return second == 0 ? base : '$base:${second.toString().padLeft(2, '0')}';
  }

  List<String> _trimTrailingEmptyCells(List<String> row) {
    var lastNonEmpty = row.length - 1;
    while (lastNonEmpty >= 0 && row[lastNonEmpty].isEmpty) {
      lastNonEmpty--;
    }
    return row.take(lastNonEmpty + 1).toList(growable: false);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
