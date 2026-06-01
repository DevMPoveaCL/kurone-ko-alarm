/// A single OCR text cell with spatial coordinates.
final class SpatialTextCell {
  final String text;
  final double x;
  final double y;

  const SpatialTextCell({required this.text, required this.x, required this.y});
}

/// A column inferred from either a tabular header or OCR x-coordinate cluster.
final class InferredColumn {
  final int index;
  final String header;
  final String semanticKey;
  final double? xCenter;

  const InferredColumn({
    required this.index,
    required this.header,
    required this.semanticKey,
    this.xCenter,
  });
}

/// Column inference result shared by tabular and OCR inputs.
final class ColumnInferenceResult {
  final List<InferredColumn> columns;
  final List<String> ambiguousColumns;

  const ColumnInferenceResult({
    required this.columns,
    required this.ambiguousColumns,
  });

  List<String> get headers => columns.map((column) => column.header).toList();
}

/// Infers schedule columns from flexible headers and OCR spatial clusters.
final class ColumnInferenceEngine {
  final double xTolerance;

  const ColumnInferenceEngine({this.xTolerance = 24});

  ColumnInferenceResult detectColumnsFromRows(List<List<String>> rows) {
    final headerRow = rows.firstWhere(
      (row) => row.any((cell) => cell.trim().isNotEmpty),
      orElse: () => const [],
    );

    return _inferFromHeaders(headerRow);
  }

  ColumnInferenceResult detectColumnsFromSpatialCells(
    List<SpatialTextCell> cells,
  ) {
    final nonEmptyCells =
        cells.where((cell) => cell.text.trim().isNotEmpty).toList()
          ..sort((a, b) => a.x.compareTo(b.x));

    final clusters = <List<SpatialTextCell>>[];
    for (final cell in nonEmptyCells) {
      if (clusters.isEmpty ||
          (cell.x - _averageX(clusters.last)).abs() > xTolerance) {
        clusters.add([cell]);
      } else {
        clusters.last.add(cell);
      }
    }

    final columns = <InferredColumn>[];
    final ambiguousColumns = <String>[];
    for (var index = 0; index < clusters.length; index++) {
      final cluster = clusters[index]..sort((a, b) => a.y.compareTo(b.y));
      final header = _normalizeHeader(cluster.first.text);
      final semanticKey = _semanticKeyFor(header) ?? 'col_$index';
      if (semanticKey.startsWith('col_')) {
        ambiguousColumns.add(semanticKey);
      }
      columns.add(
        InferredColumn(
          index: index,
          header: header,
          semanticKey: semanticKey,
          xCenter: _averageX(cluster),
        ),
      );
    }

    return ColumnInferenceResult(
      columns: columns,
      ambiguousColumns: ambiguousColumns,
    );
  }

  ColumnInferenceResult _inferFromHeaders(List<String> headers) {
    final columns = <InferredColumn>[];
    final ambiguousColumns = <String>[];

    for (var index = 0; index < headers.length; index++) {
      final header = _normalizeHeader(headers[index]);
      final semanticKey = _semanticKeyFor(header) ?? 'col_$index';
      if (semanticKey.startsWith('col_')) {
        ambiguousColumns.add(semanticKey);
      }
      columns.add(
        InferredColumn(index: index, header: header, semanticKey: semanticKey),
      );
    }

    return ColumnInferenceResult(
      columns: columns,
      ambiguousColumns: ambiguousColumns,
    );
  }

  static double _averageX(List<SpatialTextCell> cells) =>
      cells.map((cell) => cell.x).reduce((a, b) => a + b) / cells.length;

  static String _normalizeHeader(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  static String? _semanticKeyFor(String header) {
    if (_containsAny(header, const ['fecha', 'date'])) {
      return 'date';
    }
    if (header.contains('hora inicio')) {
      return 'startTime';
    }
    if (header.contains('hora termino')) {
      return 'endTime';
    }
    if (header.contains('1') && header.contains('break')) {
      return header.contains('termino') ? 'breakEnd' : 'breakStart';
    }
    if (header.contains('2') && header.contains('break')) {
      return header.contains('termino') ? 'secondBreakEnd' : 'secondBreakStart';
    }
    if (header.contains('ext') && header.contains('lunch')) {
      return header.contains('termino')
          ? 'extendedLunchEnd'
          : 'extendedLunchStart';
    }
    if (header.contains('lunch')) {
      return header.contains('termino') ? 'lunchEnd' : 'lunchStart';
    }
    if (_containsAny(header, const ['empleado', 'nombre', 'persona'])) {
      return 'name';
    }
    if (_containsAny(header, const ['entrada', 'inicio'])) {
      return 'startTime';
    }
    if (_containsAny(header, const ['salida', 'fin'])) {
      return 'endTime';
    }
    if (_containsAny(header, const ['descanso', 'break', 'pausa'])) {
      return 'breakStart';
    }
    if (_containsAny(header, const ['turno'])) {
      return 'shift';
    }
    if (_containsAny(header, const ['horario', 'hora'])) {
      return 'schedule';
    }
    return null;
  }

  static bool _containsAny(String value, List<String> keywords) =>
      keywords.any(value.contains);
}
