import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// --- Table definitions ---

class ScheduleDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get rawJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AlarmPlans extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AlarmEvents extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  IntColumn get scheduledMs => integer()();
  TextColumn get type => text()();
  TextColumn get toneProfile => text()();
  TextColumn get purpose => text().withDefault(const Constant('breakStart'))();
  TextColumn get sourceFieldKey => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get androidAlarmId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();
  IntColumn get statusChangedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ScheduleDrafts, AlarmPlans, AlarmEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(alarmEvents, alarmEvents.status);
        await m.addColumn(alarmEvents, alarmEvents.statusChangedAtMs);
      }
      if (from < 3) {
        await m.addColumn(alarmEvents, alarmEvents.purpose);
        await m.addColumn(alarmEvents, alarmEvents.sourceFieldKey);
      }
    },
  );

  // --- ScheduleDraft operations ---
  Future<void> insertDraft(ScheduleDraftsCompanion draft) =>
      into(scheduleDrafts).insertOnConflictUpdate(draft);

  Future<ScheduleDraft?> getDraftById(String id) =>
      (select(scheduleDrafts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ScheduleDraft>> getAllDrafts() => select(scheduleDrafts).get();

  Future<int> deleteDraftById(String id) =>
      (delete(scheduleDrafts)..where((t) => t.id.equals(id))).go();

  // --- AlarmPlan operations ---
  Future<void> insertPlan(AlarmPlansCompanion plan) =>
      into(alarmPlans).insertOnConflictUpdate(plan);

  Future<AlarmPlan?> getPlanById(String id) =>
      (select(alarmPlans)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<AlarmPlan>> getAllPlans() => select(alarmPlans).get();

  // --- AlarmEvent operations ---
  Future<void> insertEvent(AlarmEventsCompanion event) =>
      into(alarmEvents).insertOnConflictUpdate(event);

  Future<int> deleteEventsForPlanId(String planId) =>
      (delete(alarmEvents)..where((t) => t.planId.equals(planId))).go();

  Future<List<AlarmEvent>> getEventsForPlanId(String planId) =>
      (select(alarmEvents)..where((t) => t.planId.equals(planId))).get();

  Future<List<AlarmEvent>> getAllEnabledEvents() =>
      (select(alarmEvents)
            ..where(
              (t) => t.enabled.equals(true) & t.status.equals('scheduled'),
            ))
          .get();

  Future<void> markEventsDisabled(List<String> ids) async {
    await (update(alarmEvents)..where((t) => t.id.isIn(ids))).write(
      const AlarmEventsCompanion(enabled: Value(false)),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kurone_ko_alarm.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
