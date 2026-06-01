import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

export 'package:kurone_ko_alarm/domain/ports/outbound/ocr_reader.dart'
    show OcrTextCell;

enum OcrTokenKind { date, time, label, unknown }

final class ClassifiedOcrToken {
  final String text;
  final OcrTokenKind kind;
  final OcrTextCell? cell;
  final int order;

  const ClassifiedOcrToken({
    required this.text,
    required this.kind,
    required this.order,
    this.cell,
  });
}

final class AgnosticOcrResult {
  final List<RawEntry> entries;
  final OcrIngestionDiagnostics diagnostics;

  const AgnosticOcrResult({required this.entries, required this.diagnostics});
}

final class OcrIngestionDiagnostics {
  final int lineCount;
  final int cellCount;
  final int dateTokenCount;
  final int timeTokenCount;
  final int candidateRowCount;
  final List<String> rejectionReasons;

  const OcrIngestionDiagnostics({
    required this.lineCount,
    required this.cellCount,
    required this.dateTokenCount,
    required this.timeTokenCount,
    required this.candidateRowCount,
    required this.rejectionReasons,
  });
}

final class ScheduleCandidate {
  final String date;
  final List<String> times;
  final bool fromGeometry;

  const ScheduleCandidate({
    required this.date,
    required this.times,
    required this.fromGeometry,
  });
}

final class TokenClassifier {
  const TokenClassifier();

  List<ClassifiedOcrToken> classifyLineTokens(List<String> lines) {
    var order = 0;
    final tokens = <ClassifiedOcrToken>[];
    for (final token in _splitTokens(lines.join(' '))) {
      tokens.add(
        ClassifiedOcrToken(
          text: token,
          kind: classifyText(token),
          order: order++,
        ),
      );
    }
    return tokens;
  }

  List<ClassifiedOcrToken> classifyCells(List<OcrTextCell> cells) {
    final sorted = cells.where((cell) => cell.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final topCompare = a.top.compareTo(b.top);
        return topCompare != 0 ? topCompare : a.left.compareTo(b.left);
      });
    var order = 0;
    final tokens = <ClassifiedOcrToken>[];
    for (final cell in sorted) {
      for (final token in _splitTokens(cell.text.trim())) {
        tokens.add(
          ClassifiedOcrToken(
            text: token,
            kind: classifyText(token),
            order: order++,
            cell: cell,
          ),
        );
      }
    }
    return tokens;
  }

  OcrTokenKind classifyText(String value) {
    final trimmed = value.trim();
    if (_datePattern.hasMatch(trimmed)) {
      return OcrTokenKind.date;
    }
    if (_timePattern.hasMatch(trimmed)) {
      return OcrTokenKind.time;
    }
    if (RegExp(r'[A-Za-zÁÉÍÓÚáéíóú]').hasMatch(trimmed)) {
      return OcrTokenKind.label;
    }
    return OcrTokenKind.unknown;
  }

  static Iterable<String> _splitTokens(String value) sync* {
    for (final match in RegExp(
      r'\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú0-9]+[-/]\d{4}|\d{1,2}:\d{2}|[^\s]+',
    ).allMatches(value)) {
      yield match.group(0)!;
    }
  }
}

final class ScheduleCandidateExtractor {
  final int maxCandidates;
  final double rowToleranceMultiplier;

  const ScheduleCandidateExtractor({
    this.maxCandidates = 24,
    this.rowToleranceMultiplier = 1.6,
  });

  List<ScheduleCandidate> extract({
    required List<ClassifiedOcrToken> lineTokens,
    required List<ClassifiedOcrToken> cellTokens,
  }) {
    final geometryCandidates = _extractFromGeometry(cellTokens);
    if (geometryCandidates.isNotEmpty) {
      return _deduplicateAndBound(geometryCandidates);
    }
    return _deduplicateAndBound(_extractFromTokenStream(lineTokens));
  }

  List<ScheduleCandidate> _deduplicateAndBound(
    List<ScheduleCandidate> candidates,
  ) {
    final signatures = <String>{};
    final bounded = <ScheduleCandidate>[];
    for (final candidate in candidates) {
      final signature = '${candidate.date}|${candidate.times.join('|')}';
      if (!signatures.add(signature)) {
        continue;
      }
      bounded.add(candidate);
      if (bounded.length >= maxCandidates) {
        break;
      }
    }
    return bounded;
  }

  List<ScheduleCandidate> _extractFromGeometry(
    List<ClassifiedOcrToken> cellTokens,
  ) {
    final cells = cellTokens.where((token) => token.cell != null).toList();
    if (cells.isEmpty) {
      return const [];
    }
    cells.sort((a, b) => a.cell!.centerY.compareTo(b.cell!.centerY));
    final rows = <List<ClassifiedOcrToken>>[];
    for (final token in cells) {
      if (rows.isEmpty ||
          (token.cell!.centerY - _averageCenterY(rows.last)).abs() >
              _rowTolerance(rows.last)) {
        rows.add([token]);
      } else {
        rows.last.add(token);
      }
    }

    final candidates = <ScheduleCandidate>[];
    for (final row in rows) {
      row.sort((a, b) => a.cell!.centerX.compareTo(b.cell!.centerX));
      final candidate = _candidateFromTokens(row, fromGeometry: true);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  List<ScheduleCandidate> _extractFromTokenStream(
    List<ClassifiedOcrToken> tokens,
  ) {
    final candidates = <ScheduleCandidate>[];
    for (var index = 0; index < tokens.length; index++) {
      if (tokens[index].kind != OcrTokenKind.date) {
        continue;
      }
      final nextDateIndex = tokens.indexWhere(
        (token) =>
            token.kind == OcrTokenKind.date &&
            token.order > tokens[index].order,
      );
      final end = nextDateIndex == -1 ? tokens.length : nextDateIndex;
      final candidate = _candidateFromTokens(
        tokens.sublist(index, end),
        fromGeometry: false,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  ScheduleCandidate? _candidateFromTokens(
    List<ClassifiedOcrToken> tokens, {
    required bool fromGeometry,
  }) {
    final date = tokens
        .where((token) => token.kind == OcrTokenKind.date)
        .map((token) => _datePattern.firstMatch(token.text)?.group(0))
        .nonNulls
        .firstOrNull;
    if (date == null) {
      return null;
    }
    final times = tokens
        .where((token) => token.kind == OcrTokenKind.time)
        .map((token) => _timePattern.firstMatch(token.text)?.group(0))
        .nonNulls
        .toList();
    if (times.length < 2) {
      return null;
    }
    return ScheduleCandidate(
      date: date,
      times: times,
      fromGeometry: fromGeometry,
    );
  }

  double _averageCenterY(List<ClassifiedOcrToken> row) =>
      row.map((token) => token.cell!.centerY).reduce((a, b) => a + b) /
      row.length;

  double _rowTolerance(List<ClassifiedOcrToken> row) {
    final averageHeight =
        row.map((token) => token.cell!.height).reduce((a, b) => a + b) /
        row.length;
    return averageHeight * rowToleranceMultiplier;
  }
}

final class TemporalRoleAssigner {
  const TemporalRoleAssigner();

  RawEntry assign({
    required ScheduleCandidate candidate,
    required ImportSource source,
    required int index,
  }) {
    final fields = <String, String>{
      'date': candidate.date,
      'startTime': candidate.times.first,
      'endTime': candidate.times.last,
    };
    final middleTimes = candidate.times.sublist(1, candidate.times.length - 1);
    const pairKeys = [
      ('breakStart', 'breakEnd'),
      ('lunchStart', 'lunchEnd'),
      ('extendedLunchStart', 'extendedLunchEnd'),
      ('secondBreakStart', 'secondBreakEnd'),
    ];
    for (var pairIndex = 0; pairIndex < pairKeys.length; pairIndex++) {
      final timeIndex = pairIndex * 2;
      if (timeIndex >= middleTimes.length) {
        break;
      }
      fields[pairKeys[pairIndex].$1] = middleTimes[timeIndex];
      if (timeIndex + 1 < middleTimes.length) {
        fields[pairKeys[pairIndex].$2] = middleTimes[timeIndex + 1];
      }
    }

    final reasons = <String>['headerless temporal inference'];
    if (!candidate.fromGeometry) {
      reasons.add('line/token fallback');
    }
    if (_isNonMonotonic(candidate.times)) {
      reasons.add('non-monotonic times may indicate an overnight shift');
    }
    if (middleTimes.length.isOdd) {
      reasons.add('unpaired break/lunch time');
    }

    return RawEntry(
      id: '${source.name}_$index',
      source: source,
      fields: fields,
      confidence: Confidence.medium(reason: reasons.join('; ')),
    );
  }

  bool _isNonMonotonic(List<String> times) {
    var previous = _minutesSinceMidnight(times.first);
    for (final time in times.skip(1)) {
      final current = _minutesSinceMidnight(time);
      if (current < previous) {
        return true;
      }
      previous = current;
    }
    return false;
  }

  int _minutesSinceMidnight(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

final class AgnosticOcrInterpreter {
  final TokenClassifier tokenClassifier;
  final ScheduleCandidateExtractor candidateExtractor;
  final TemporalRoleAssigner roleAssigner;

  const AgnosticOcrInterpreter({
    this.tokenClassifier = const TokenClassifier(),
    this.candidateExtractor = const ScheduleCandidateExtractor(),
    this.roleAssigner = const TemporalRoleAssigner(),
  });

  List<RawEntry> interpret({
    required List<String> lines,
    required List<OcrTextCell> cells,
    required ImportSource source,
  }) {
    return interpretWithDiagnostics(
      lines: lines,
      cells: cells,
      source: source,
    ).entries;
  }

  AgnosticOcrResult interpretWithDiagnostics({
    required List<String> lines,
    required List<OcrTextCell> cells,
    required ImportSource source,
  }) {
    final lineTokens = tokenClassifier.classifyLineTokens(lines);
    final cellTokens = tokenClassifier.classifyCells(cells);
    final candidates = candidateExtractor.extract(
      lineTokens: lineTokens,
      cellTokens: cellTokens,
    );
    final entries = [
      for (var index = 0; index < candidates.length; index++)
        roleAssigner.assign(
          candidate: candidates[index],
          source: source,
          index: index,
        ),
    ];
    final allTokens = [...lineTokens, ...cellTokens];
    final dateTokenCount = allTokens
        .where((token) => token.kind == OcrTokenKind.date)
        .length;
    final timeTokenCount = allTokens
        .where((token) => token.kind == OcrTokenKind.time)
        .length;
    return AgnosticOcrResult(
      entries: entries,
      diagnostics: OcrIngestionDiagnostics(
        lineCount: lines.where((line) => line.trim().isNotEmpty).length,
        cellCount: cells.where((cell) => cell.text.trim().isNotEmpty).length,
        dateTokenCount: dateTokenCount,
        timeTokenCount: timeTokenCount,
        candidateRowCount: candidates.length,
        rejectionReasons: _rejectionReasons(
          dateTokenCount: dateTokenCount,
          timeTokenCount: timeTokenCount,
          candidateRowCount: candidates.length,
        ),
      ),
    );
  }

  List<String> _rejectionReasons({
    required int dateTokenCount,
    required int timeTokenCount,
    required int candidateRowCount,
  }) {
    if (candidateRowCount > 0) {
      return const [];
    }
    if (dateTokenCount == 0 && timeTokenCount == 0) {
      return const ['no date or time tokens detected'];
    }
    if (dateTokenCount == 0) {
      return const ['no date tokens detected'];
    }
    if (timeTokenCount == 0) {
      return const ['no time tokens detected'];
    }
    if (timeTokenCount < dateTokenCount * 2) {
      return const ['fewer than two time tokens per detected date'];
    }
    return const ['date/time tokens did not form a candidate row'];
  }
}

final _datePattern = RegExp(r'\b\d{1,2}[-/][A-Za-zÁÉÍÓÚáéíóú0-9]+[-/]\d{4}\b');
final _timePattern = RegExp(r'\b\d{1,2}:\d{2}\b');
