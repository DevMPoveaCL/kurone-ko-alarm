import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/infrastructure/helpers/local_json_crash_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kurone_crash_log_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('appends structured JSON lines to the local crash log file', () async {
    final log = LocalJsonCrashLog(
      directoryProvider: () async => tempDir,
      clock: _FixedClock(DateTime.utc(2026, 5, 13, 10, 30)),
    );

    await log.append(
      const CrashLogEntry(
        level: CrashLogLevel.error,
        message: 'OCR extraction failed',
        error: 'bad image bytes',
        context: {'source': 'image'},
      ),
    );
    await log.append(
      const CrashLogEntry(
        level: CrashLogLevel.warning,
        message: 'Low confidence row',
        context: {'rowId': 'excel-2'},
      ),
    );

    final lines = await File('${tempDir.path}/crash_log.jsonl').readAsLines();
    final first = jsonDecode(lines[0]) as Map<String, Object?>;
    final second = jsonDecode(lines[1]) as Map<String, Object?>;

    expect(lines, hasLength(2));
    expect(first['timestamp'], '2026-05-13T10:30:00.000Z');
    expect(first['level'], 'error');
    expect(first['message'], 'OCR extraction failed');
    expect(first['error'], 'bad image bytes');
    expect(first['context'], {'source': 'image'});
    expect(second['level'], 'warning');
    expect(second['context'], {'rowId': 'excel-2'});
  });

  test(
    'rotates the current log before append when the next entry would exceed the byte limit',
    () async {
      final logFile = File('${tempDir.path}/crash_log.jsonl');
      await logFile.writeAsString('previous oversized log content');
      final log = LocalJsonCrashLog(
        directoryProvider: () async => tempDir,
        clock: _FixedClock(DateTime.utc(2026, 5, 13, 11)),
        maxBytes: 32,
      );

      await log.append(
        const CrashLogEntry(
          level: CrashLogLevel.error,
          message: 'new crash after rotation',
        ),
      );

      final rotated = File('${tempDir.path}/crash_log.jsonl.1');
      final currentLines = await logFile.readAsLines();
      final current = jsonDecode(currentLines.single) as Map<String, Object?>;

      expect(await rotated.readAsString(), 'previous oversized log content');
      expect(current['message'], 'new crash after rotation');
    },
  );
}

final class _FixedClock implements CrashLogClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
