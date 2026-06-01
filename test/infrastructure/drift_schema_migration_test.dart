import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/database.dart';

void main() {
  group('Drift schema 1 -> 2 migration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_migration_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'existing rows receive status=scheduled and statusChangedAt=NULL after migration',
      () async {
        final dbFile = File('${tempDir.path}/migration.sqlite');

        // 1. Simulate schema v1 directly with sqlite3
        final raw = sqlite3.open(dbFile.path);
        raw.execute('''
          CREATE TABLE alarm_events (
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            scheduled_ms INTEGER NOT NULL,
            type TEXT NOT NULL,
            tone_profile TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            android_alarm_id INTEGER
          )
        ''');
        raw.execute('''
          INSERT INTO alarm_events (id, plan_id, scheduled_ms, type, tone_profile, enabled)
          VALUES ('evt-1', 'plan-1', 1717200000000, 'main', 'breakStart', 1)
        ''');
        raw.execute('PRAGMA user_version = 1');
        raw.dispose();

        // 2. Open with Drift-generated AppDatabase (schema v2)
        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        // Drift lazily opens; force open by running a query
        final row = await db.select(db.alarmEvents).getSingle();

        // 3. Assert defaults
        expect(row.status, 'scheduled');
        expect(row.statusChangedAtMs, isNull);

        await db.close();
      },
    );
  });

  group('Drift schema 2 -> 3 migration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_migration_test_v3');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'existing rows receive purpose=breakStart and sourceFieldKey="" after migration',
      () async {
        final dbFile = File('${tempDir.path}/migration_v3.sqlite');

        // 1. Simulate schema v2 directly with sqlite3
        final raw = sqlite3.open(dbFile.path);
        raw.execute('''
          CREATE TABLE alarm_events (
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            scheduled_ms INTEGER NOT NULL,
            type TEXT NOT NULL,
            tone_profile TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            android_alarm_id INTEGER,
            status TEXT NOT NULL DEFAULT 'scheduled',
            status_changed_at_ms INTEGER
          )
        ''');
        raw.execute('''
          INSERT INTO alarm_events (id, plan_id, scheduled_ms, type, tone_profile, enabled, status)
          VALUES ('evt-1', 'plan-1', 1717200000000, 'main', 'breakStart', 1, 'scheduled')
        ''');
        raw.execute('PRAGMA user_version = 2');
        raw.dispose();

        // 2. Open with Drift-generated AppDatabase (schema v3)
        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        final row = await db.select(db.alarmEvents).getSingle();

        // 3. Assert defaults
        expect(row.purpose, 'breakStart');
        expect(row.sourceFieldKey, '');

        await db.close();
      },
    );
  });
}
