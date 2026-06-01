import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int fiveMegabytes = 5 * 1024 * 1024;

typedef CrashLogDirectoryProvider = Future<Directory> Function();

abstract interface class CrashLogClock {
  DateTime now();
}

enum CrashLogLevel { error, warning, info }

final class CrashLogEntry {
  final CrashLogLevel level;
  final String message;
  final String? error;
  final Map<String, Object?> context;

  const CrashLogEntry({
    required this.level,
    required this.message,
    this.error,
    this.context = const {},
  });
}

/// Local-only JSON-lines crash log with single-file rotation.
final class LocalJsonCrashLog {
  LocalJsonCrashLog({
    CrashLogDirectoryProvider? directoryProvider,
    CrashLogClock? clock,
    this.maxBytes = fiveMegabytes,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory,
       _clock = clock ?? const _SystemCrashLogClock();

  static const String fileName = 'crash_log.jsonl';

  final CrashLogDirectoryProvider _directoryProvider;
  final CrashLogClock _clock;
  final int maxBytes;

  Future<void> append(CrashLogEntry entry) async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File(p.join(directory.path, fileName));
    final line = '${jsonEncode(_toJson(entry))}\n';
    await _rotateIfNeeded(file, line.length);
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Map<String, Object?> _toJson(CrashLogEntry entry) {
    return {
      'timestamp': _clock.now().toUtc().toIso8601String(),
      'level': entry.level.name,
      'message': entry.message,
      if (entry.error != null) 'error': entry.error,
      if (entry.context.isNotEmpty) 'context': entry.context,
    };
  }

  Future<void> _rotateIfNeeded(File file, int nextEntryBytes) async {
    if (!await file.exists()) {
      return;
    }

    final currentBytes = await file.length();
    if (currentBytes + nextEntryBytes <= maxBytes) {
      return;
    }

    final rotated = File('${file.path}.1');
    if (await rotated.exists()) {
      await rotated.delete();
    }
    await file.rename(rotated.path);
  }
}

final class _SystemCrashLogClock implements CrashLogClock {
  const _SystemCrashLogClock();

  @override
  DateTime now() => DateTime.now();
}
