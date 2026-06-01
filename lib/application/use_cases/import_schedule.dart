import 'dart:io';

import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/import_schedule.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/structured_file_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/agnostic_ocr_interpreter.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/interpretation/normalizer.dart';

/// Application service that imports a source file into a reviewable schedule draft.
final class ImportScheduleUseCaseImpl implements ImportScheduleUseCase {
  final OcrReader ocrReader;
  final StructuredFileReader structuredFileReader;
  final Normalizer normalizer;
  final AgnosticOcrInterpreter agnosticOcrInterpreter;
  final Clock clock;

  const ImportScheduleUseCaseImpl({
    required this.ocrReader,
    required this.structuredFileReader,
    required this.clock,
    this.normalizer = const Normalizer(),
    this.agnosticOcrInterpreter = const AgnosticOcrInterpreter(),
  });

  @override
  Future<ScheduleDraft> import({
    required String filePath,
    required ImportSource source,
  }) async {
    final imported = switch (source) {
      ImportSource.image => await _readImageRows(filePath),
      ImportSource.excel => _ImportedRows(
        rows: await structuredFileReader.readRows(filePath),
      ),
    };
    final entries =
        imported.entries ??
        normalizer.toCommonFormat(source: source, rows: imported.rows);

    if (entries.isEmpty) {
      throw ExtractionFailure(
        source: source,
        message: _noUsableEntriesMessage(imported.diagnostics),
      );
    }

    final now = clock.now();
    return ScheduleDraft(
      id: 'draft_${now.toUtc().toIso8601String()}',
      source: source,
      entries: entries,
      createdAt: now,
    );
  }

  Future<_ImportedRows> _readImageRows(String filePath) async {
    final imageBytes = await File(filePath).readAsBytes();
    final spatialCells = await ocrReader.extractTextCells(imageBytes);
    final lines = await ocrReader.extractLines(imageBytes);
    final trimmedLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var diagnostics = _OcrDiagnostics.fromLines(trimmedLines);

    final agnosticResult = agnosticOcrInterpreter.interpretWithDiagnostics(
      lines: trimmedLines,
      cells: spatialCells,
      source: ImportSource.image,
    );
    diagnostics = diagnostics.withAgnosticDiagnostics(
      agnosticResult.diagnostics,
    );

    final spatialResult = _readSpatialScreenshotTableRows(spatialCells);
    diagnostics = diagnostics.withSpatialResult(spatialResult);
    if (spatialResult.rows.isNotEmpty) {
      return _ImportedRows(rows: spatialResult.rows, diagnostics: diagnostics);
    }

    final screenshotRows = _readScreenshotTableRows(trimmedLines);
    if (screenshotRows.isNotEmpty) {
      return _ImportedRows(rows: screenshotRows, diagnostics: diagnostics);
    }

    if (agnosticResult.entries.isNotEmpty) {
      return _ImportedRows(
        entries: agnosticResult.entries,
        diagnostics: diagnostics,
      );
    }

    return _ImportedRows(
      rows: trimmedLines.map((line) => line.split(RegExp(r'\s+'))).toList(),
      diagnostics: diagnostics,
    );
  }

  _SpatialTableReadResult _readSpatialScreenshotTableRows(
    List<OcrTextCell> cells,
  ) {
    final rows = _clusterSpatialRows(cells);
    if (rows.length < 2) {
      return _SpatialTableReadResult.empty(
        cellCount: cells.where((cell) => cell.text.trim().isNotEmpty).length,
        spatialRowCount: rows.length,
      );
    }

    var maxHeaderAnchorCount = 0;
    for (
      var headerRowIndex = 0;
      headerRowIndex < rows.length - 1;
      headerRowIndex++
    ) {
      final headerCells = _inferSpatialHeaderAnchors(rows[headerRowIndex]);
      if (headerCells.length > maxHeaderAnchorCount) {
        maxHeaderAnchorCount = headerCells.length;
      }
      if (headerCells.length < 2) {
        continue;
      }

      final tableRows = <List<String>>[];
      for (final rowCells in rows.skip(headerRowIndex + 1)) {
        final row = _projectSpatialRowToHeaders(
          headers: headerCells,
          cells: rowCells,
        );
        if (row == null) {
          continue;
        }
        tableRows.add(row);
      }
      if (tableRows.isNotEmpty) {
        return _SpatialTableReadResult(
          rows: [headerCells.map((cell) => cell.text).toList(), ...tableRows],
          cellCount: cells.where((cell) => cell.text.trim().isNotEmpty).length,
          spatialRowCount: rows.length,
          headerAnchorCount: headerCells.length,
        );
      }
    }

    return _SpatialTableReadResult.empty(
      cellCount: cells.where((cell) => cell.text.trim().isNotEmpty).length,
      spatialRowCount: rows.length,
      headerAnchorCount: maxHeaderAnchorCount,
    );
  }

  List<OcrTextCell> _inferSpatialHeaderAnchors(List<OcrTextCell> row) {
    final wholeCellHeaders =
        row
            .map((cell) {
              final header = _knownScreenshotHeaderFor(cell.text);
              return header == null ? null : cell.copyWith(text: header);
            })
            .nonNulls
            .toList()
          ..sort((a, b) => a.centerX.compareTo(b.centerX));
    if (_isUsableSpatialHeaderRow(wholeCellHeaders)) {
      return wholeCellHeaders;
    }

    final sorted = [...row]..sort((a, b) => a.centerX.compareTo(b.centerX));
    final normalizedCells = sorted
        .map((cell) => _normalizeOcrHeader(cell.text))
        .toList(growable: false);
    final anchors = <OcrTextCell>[];
    final usedIndexes = <int>{};

    for (var index = 0; index < sorted.length; index++) {
      if (usedIndexes.contains(index)) {
        continue;
      }
      final match = _matchHeaderAt(normalizedCells, index);
      if (match == null) {
        continue;
      }
      for (
        var matchIndex = index;
        matchIndex < index + match.width;
        matchIndex++
      ) {
        usedIndexes.add(matchIndex);
      }
      final matchedCells = sorted.sublist(index, index + match.width);
      final left = matchedCells.first.left;
      final right = matchedCells
          .map((cell) => cell.left + cell.width)
          .reduce((a, b) => a > b ? a : b);
      final top = matchedCells
          .map((cell) => cell.top)
          .reduce((a, b) => a < b ? a : b);
      final bottom = matchedCells
          .map((cell) => cell.top + cell.height)
          .reduce((a, b) => a > b ? a : b);
      anchors.add(
        OcrTextCell(
          text: match.header,
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
        ),
      );
    }

    anchors.sort((a, b) => a.centerX.compareTo(b.centerX));
    return _isUsableSpatialHeaderRow(anchors) ? anchors : const [];
  }

  ({String header, int width})? _matchHeaderAt(
    List<String> normalizedCells,
    int startIndex,
  ) {
    ({String header, int width})? bestMatch;
    for (final header in _knownScreenshotHeaders) {
      final headerTokens = _normalizeOcrHeader(header).split(' ');
      if (startIndex + headerTokens.length > normalizedCells.length) {
        continue;
      }
      final cellTokens = normalizedCells.sublist(
        startIndex,
        startIndex + headerTokens.length,
      );
      if (!_sameStringList(cellTokens, headerTokens)) {
        continue;
      }
      if (bestMatch == null || headerTokens.length > bestMatch.width) {
        bestMatch = (header: header, width: headerTokens.length);
      }
    }
    return bestMatch;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isUsableSpatialHeaderRow(List<OcrTextCell> anchors) =>
      anchors.length >= 2 && anchors.first.text == 'Fecha';

  List<List<OcrTextCell>> _clusterSpatialRows(List<OcrTextCell> cells) {
    final nonEmptyCells =
        cells
            .map((cell) => cell.copyWith(text: cell.text.trim()))
            .where((cell) => cell.text.isNotEmpty)
            .toList()
          ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (nonEmptyCells.isEmpty) {
      return const [];
    }

    final rows = <List<OcrTextCell>>[];
    for (final cell in nonEmptyCells) {
      if (rows.isEmpty ||
          (cell.centerY - _averageCenterY(rows.last)).abs() >
              _rowTolerance(rows.last)) {
        rows.add([cell]);
      } else {
        rows.last.add(cell);
      }
    }

    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }

  List<String>? _projectSpatialRowToHeaders({
    required List<OcrTextCell> headers,
    required List<OcrTextCell> cells,
  }) {
    final row = <String>[];
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      final leftBoundary = columnIndex == 0
          ? double.negativeInfinity
          : (headers[columnIndex - 1].centerX + headers[columnIndex].centerX) /
                2;
      final rightBoundary = columnIndex == headers.length - 1
          ? double.infinity
          : (headers[columnIndex].centerX + headers[columnIndex + 1].centerX) /
                2;
      final value = cells
          .where(
            (cell) =>
                cell.centerX >= leftBoundary && cell.centerX < rightBoundary,
          )
          .map((cell) => cell.text)
          .join(' ')
          .trim();
      row.add(value);
    }

    if (!_looksLikeDate(row.first) ||
        row.skip(1).where(_looksLikeTime).isEmpty) {
      return null;
    }
    return row;
  }

  double _averageCenterY(List<OcrTextCell> cells) =>
      cells.map((cell) => cell.centerY).reduce((a, b) => a + b) / cells.length;

  double _rowTolerance(List<OcrTextCell> row) {
    final averageHeight =
        row.map((cell) => cell.height).reduce((a, b) => a + b) / row.length;
    return averageHeight * 1.6;
  }

  List<List<String>> _readScreenshotTableRows(List<String> lines) {
    final singleBlockRows = _readSingleBlockScreenshotTableRows(lines);
    if (singleBlockRows.isNotEmpty) {
      return singleBlockRows;
    }

    final sparseTokenRows = _readSparseTokenStreamScreenshotTableRows(lines);
    if (sparseTokenRows.isNotEmpty) {
      return sparseTokenRows;
    }

    final verticalRows = _readVerticalScreenshotTableRows(lines);
    if (verticalRows.isNotEmpty) {
      return verticalRows;
    }

    final dataRows = <List<String>>[];
    final headerLines = <String>[];

    for (final line in lines) {
      final row = _parseDateAndTimesRow(line);
      if (row == null) {
        headerLines.add(line);
      } else {
        dataRows.add(row);
      }
    }

    if (dataRows.isEmpty) {
      return const [];
    }

    final headers = _extractScreenshotHeaders(headerLines);
    if (headers.length < dataRows.first.length) {
      return const [];
    }

    final width = dataRows.first.length;
    return [
      headers.take(width).toList(),
      ...dataRows.where((row) => row.length == width),
    ];
  }

  List<List<String>> _readSingleBlockScreenshotTableRows(List<String> lines) {
    if (lines.length != 1) {
      return const [];
    }

    final dataRow = _parseDateAndTimesRow(lines.single);
    if (dataRow == null) {
      return const [];
    }

    final headers = _extractScreenshotHeaders(lines);
    if (headers.length < dataRow.length) {
      return const [];
    }

    return [headers.take(dataRow.length).toList(), dataRow];
  }

  List<List<String>> _readSparseTokenStreamScreenshotTableRows(
    List<String> lines,
  ) {
    final headers = _extractScreenshotHeaders(lines);
    if (headers.length < _knownScreenshotHeaders.length) {
      return const [];
    }

    final tokenText = lines.join(' ');
    final dateMatches = RegExp(
      r'\b\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú]+[-/]\d{4}\b',
    ).allMatches(tokenText).toList();
    if (dateMatches.length < 2) {
      return const [];
    }

    final timeTokens = RegExp(r'\b\d{1,2}:\d{2}\b')
        .allMatches(tokenText)
        .map((match) => _OcrToken(index: match.start, value: match.group(0)!))
        .toList();
    final timesPerRow = _knownScreenshotHeaders.length - 1;
    if (timeTokens.length < dateMatches.length * timesPerRow) {
      return const [];
    }

    final dates = dateMatches
        .map((match) => _OcrToken(index: match.start, value: match.group(0)!))
        .toList();
    final rows = _readRowMajorTokenRows(
      dates: dates,
      timeTokens: timeTokens,
      timesPerRow: timesPerRow,
    );
    if (rows.isNotEmpty) {
      return [headers.take(_knownScreenshotHeaders.length).toList(), ...rows];
    }

    final columnRows = _readColumnMajorTokenRows(
      dates: dates,
      timeTokens: timeTokens,
      timesPerRow: timesPerRow,
    );
    if (columnRows.isEmpty) {
      return const [];
    }

    return [
      headers.take(_knownScreenshotHeaders.length).toList(),
      ...columnRows,
    ];
  }

  List<List<String>> _readRowMajorTokenRows({
    required List<_OcrToken> dates,
    required List<_OcrToken> timeTokens,
    required int timesPerRow,
  }) {
    final rows = <List<String>>[];
    for (var dateIndex = 0; dateIndex < dates.length; dateIndex++) {
      final date = dates[dateIndex];
      final nextDateIndex = dateIndex + 1 < dates.length
          ? dates[dateIndex + 1].index
          : null;
      final rowTimes = timeTokens
          .where(
            (token) =>
                token.index > date.index &&
                (nextDateIndex == null || token.index < nextDateIndex),
          )
          .map((token) => token.value)
          .toList();
      if (rowTimes.length < timesPerRow) {
        return const [];
      }
      rows.add([date.value, ...rowTimes.take(timesPerRow)]);
    }
    return rows;
  }

  List<List<String>> _readColumnMajorTokenRows({
    required List<_OcrToken> dates,
    required List<_OcrToken> timeTokens,
    required int timesPerRow,
  }) {
    if (timeTokens.first.index < dates.last.index) {
      return const [];
    }

    final rowCount = dates.length;
    final rows = [
      for (final date in dates) [date.value],
    ];

    for (var columnIndex = 0; columnIndex < timesPerRow; columnIndex++) {
      final offset = columnIndex * rowCount;
      if (offset + rowCount > timeTokens.length) {
        return const [];
      }
      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
        rows[rowIndex].add(timeTokens[offset + rowIndex].value);
      }
    }

    return rows;
  }

  List<List<String>> _readVerticalScreenshotTableRows(List<String> lines) {
    final headerPositions = <({int index, String header})>[];
    for (var index = 0; index < lines.length; index++) {
      final header = _knownScreenshotHeaderFor(lines[index]);
      if (header != null) {
        headerPositions.add((index: index, header: header));
      }
    }

    final dateHeaderIndex = headerPositions.indexWhere(
      (position) => position.header == 'Fecha',
    );
    if (dateHeaderIndex < 0 || headerPositions.length < 2) {
      return const [];
    }

    final columns = <({String header, List<String> values})>[];
    for (var index = 0; index < headerPositions.length; index++) {
      final current = headerPositions[index];
      final nextIndex = index + 1 < headerPositions.length
          ? headerPositions[index + 1].index
          : lines.length;
      final values = lines
          .sublist(current.index + 1, nextIndex)
          .where((line) => _knownScreenshotHeaderFor(line) == null)
          .toList();
      columns.add((header: current.header, values: values));
    }

    final rowCount = columns[dateHeaderIndex].values
        .where(_looksLikeDate)
        .length;
    if (rowCount == 0) {
      return const [];
    }

    final usableColumns = columns
        .where((column) => column.values.length >= rowCount)
        .toList();
    if (usableColumns.length < 2) {
      return const [];
    }

    return [
      usableColumns.map((column) => column.header).toList(),
      for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
        usableColumns.map((column) => column.values[rowIndex]).toList(),
    ];
  }

  List<String>? _parseDateAndTimesRow(String line) {
    final dateMatch = RegExp(
      r'\b\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú]+[-/]\d{4}\b',
    ).firstMatch(line);
    if (dateMatch == null) {
      return null;
    }

    final times = RegExp(
      r'\b\d{1,2}:\d{2}\b',
    ).allMatches(line).map((match) => match.group(0)!).toList();
    if (times.isEmpty) {
      return null;
    }

    return [dateMatch.group(0)!, ...times];
  }

  bool _looksLikeDate(String value) => RegExp(
    r'^\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú]+[-/]\d{4}$',
  ).hasMatch(value.trim());

  bool _looksLikeTime(String value) =>
      RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value.trim());

  List<String> _extractScreenshotHeaders(List<String> headerLines) {
    final headerText = headerLines.join(' ');
    final normalizedHeaderText = _normalizeOcrHeader(headerText);
    final matchedHeaders = <({int index, String header})>[];
    for (final header in _knownScreenshotHeaders) {
      final index = normalizedHeaderText.indexOf(_normalizeOcrHeader(header));
      if (index >= 0) {
        matchedHeaders.add((index: index, header: header));
      }
    }

    if (matchedHeaders.isNotEmpty) {
      matchedHeaders.sort((a, b) => a.index.compareTo(b.index));
      return matchedHeaders.map((match) => match.header).toList();
    }

    return headerLines;
  }

  String _normalizeOcrHeader(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('º', '°')
      .replaceAll('°', ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? _knownScreenshotHeaderFor(String value) {
    final normalized = _normalizeOcrHeader(value);
    for (final header in _knownScreenshotHeaders) {
      if (normalized == _normalizeOcrHeader(header)) {
        return header;
      }
    }
    return null;
  }

  String _noUsableEntriesMessage(_OcrDiagnostics? diagnostics) {
    const base = 'No usable schedule entries were extracted.';
    if (diagnostics == null) {
      return base;
    }
    final agnosticSummary = diagnostics.agnosticDiagnostics == null
        ? ''
        : ' OCR cells: ${diagnostics.agnosticDiagnostics!.cellCount}; '
              'date tokens: ${diagnostics.agnosticDiagnostics!.dateTokenCount}; '
              'time tokens: ${diagnostics.agnosticDiagnostics!.timeTokenCount}; '
              'candidate rows: ${diagnostics.agnosticDiagnostics!.candidateRowCount}; '
              'rejected: ${diagnostics.agnosticDiagnostics!.rejectionReasons.join(', ')};';
    return '$base OCR lines: ${diagnostics.lineCount};$agnosticSummary '
        'sample: ${diagnostics.redactedSample.join(', ')}';
  }
}

const _knownScreenshotHeaders = [
  'Fecha',
  'Hora Inicio',
  '1° Break Inicio',
  '1° Break Termino',
  'Lunch Inicio',
  'Lunch Termino',
  'Ext. Lunch Inicio',
  'Ext. Lunch Termino',
  '2° Break Inicio',
  '2° Break Termino',
  'Hora Termino',
];

final class _ImportedRows {
  final List<List<String>> rows;
  final List<RawEntry>? entries;
  final _OcrDiagnostics? diagnostics;

  const _ImportedRows({this.rows = const [], this.entries, this.diagnostics});
}

final class _SpatialTableReadResult {
  final List<List<String>> rows;
  final int cellCount;
  final int spatialRowCount;
  final int headerAnchorCount;

  const _SpatialTableReadResult({
    required this.rows,
    required this.cellCount,
    required this.spatialRowCount,
    required this.headerAnchorCount,
  });

  const _SpatialTableReadResult.empty({
    required this.cellCount,
    required this.spatialRowCount,
    this.headerAnchorCount = 0,
  }) : rows = const [];
}

final class _OcrToken {
  final int index;
  final String value;

  const _OcrToken({required this.index, required this.value});
}

final class _OcrDiagnostics {
  final int lineCount;
  final List<String> redactedSample;
  final int? ocrCellCount;
  final int? spatialRowCount;
  final int? headerAnchorCount;
  final OcrIngestionDiagnostics? agnosticDiagnostics;

  const _OcrDiagnostics({
    required this.lineCount,
    required this.redactedSample,
    this.ocrCellCount,
    this.spatialRowCount,
    this.headerAnchorCount,
    this.agnosticDiagnostics,
  });

  factory _OcrDiagnostics.fromLines(List<String> lines) {
    return _OcrDiagnostics(
      lineCount: lines.length,
      redactedSample: lines.take(4).map(_redactLine).toList(),
    );
  }

  _OcrDiagnostics withSpatialResult(_SpatialTableReadResult result) =>
      _OcrDiagnostics(
        lineCount: lineCount,
        redactedSample: redactedSample,
        ocrCellCount: result.cellCount,
        spatialRowCount: result.spatialRowCount,
        headerAnchorCount: result.headerAnchorCount,
        agnosticDiagnostics: agnosticDiagnostics,
      );

  _OcrDiagnostics withAgnosticDiagnostics(
    OcrIngestionDiagnostics diagnostics,
  ) => _OcrDiagnostics(
    lineCount: lineCount,
    redactedSample: redactedSample,
    ocrCellCount: ocrCellCount,
    spatialRowCount: spatialRowCount,
    headerAnchorCount: headerAnchorCount,
    agnosticDiagnostics: diagnostics,
  );

  static String _redactLine(String line) {
    final trimmed = line.trim();
    if (RegExp(
      r'^\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú]+[-/]\d{4}$',
    ).hasMatch(trimmed)) {
      return '[date]';
    }
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(trimmed)) {
      return '[time]';
    }
    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(trimmed)) {
      return '[text+time]';
    }
    if (RegExp(r'\d{4}|[-/]').hasMatch(trimmed)) {
      return '[text+date]';
    }
    return '[text]';
  }
}
