import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart' as domain;
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart' as domain;
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/database.dart'
    as persistence;

/// Drift-backed implementation of the local persistence port.
final class DriftLocalRepository implements LocalRepository {
  final persistence.AppDatabase _database;

  const DriftLocalRepository(this._database);

  @override
  Future<void> saveDraft(domain.ScheduleDraft draft) {
    return _database.insertDraft(
      persistence.ScheduleDraftsCompanion(
        id: Value(draft.id),
        source: Value(draft.source.name),
        rawJson: Value(_encodeRawEntries(draft.entries)),
        createdAt: Value(draft.createdAt.millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<domain.ScheduleDraft?> getDraft(String id) async {
    final row = await _database.getDraftById(id);
    return row == null ? null : _toDomainDraft(row);
  }

  @override
  Future<List<domain.ScheduleDraft>> getAllDrafts() async {
    final rows = await _database.getAllDrafts();
    return rows.map(_toDomainDraft).toList();
  }

  @override
  Future<void> deleteDraft(String id) async {
    await _database.deleteDraftById(id);
  }

  @override
  Future<void> savePlan(domain.AlarmPlan plan) {
    return _database.transaction(() async {
      await _database.insertPlan(
        persistence.AlarmPlansCompanion(
          id: Value(plan.id),
          scheduleId: Value(plan.scheduleId),
          createdAt: Value(plan.createdAt.millisecondsSinceEpoch),
        ),
      );
      await _database.deleteEventsForPlanId(plan.id);
      for (final alarm in plan.alarms) {
        await _database.insertEvent(_toEventCompanion(alarm));
      }
    });
  }

  @override
  Future<domain.AlarmPlan?> getPlan(String id) async {
    final row = await _database.getPlanById(id);
    if (row == null) {
      return null;
    }

    final events = await getEventsForPlan(id);
    return _toDomainPlan(row, events);
  }

  @override
  Future<List<domain.AlarmPlan>> getAllPlans() async {
    final rows = await _database.getAllPlans();
    final plans = <domain.AlarmPlan>[];
    for (final row in rows) {
      plans.add(_toDomainPlan(row, await getEventsForPlan(row.id)));
    }
    return plans;
  }

  @override
  Future<List<domain.AlarmEvent>> getEventsForPlan(String planId) async {
    final rows = await _database.getEventsForPlanId(planId);
    return rows.map(_toDomainEvent).toList();
  }

  @override
  Future<List<domain.AlarmEvent>> getAllEnabledEvents() async {
    final rows = await _database.getAllEnabledEvents();
    return rows.map(_toDomainEvent).toList();
  }

  @override
  Future<List<int>> pruneStaleEnabledEvents(DateTime now) async {
    final allEnabled = await _database.getAllEnabledEvents();
    final staleRows = allEnabled.where(
      (row) =>
          DateTime.fromMillisecondsSinceEpoch(row.scheduledMs).isBefore(now) &&
          row.status == 'scheduled',
    );
    final staleIds = staleRows.map((row) => row.id).toList();
    if (staleIds.isEmpty) return [];

    // Mark stale alarms as missed and disable them so they move to history
    final changedAt = now.millisecondsSinceEpoch;
    await (_database.update(_database.alarmEvents)
          ..where((t) => t.id.isIn(staleIds)))
        .write(
      persistence.AlarmEventsCompanion(
        enabled: const Value(false),
        status: const Value('missed'),
        statusChangedAtMs: Value(changedAt),
      ),
    );

    // Return androidAlarmIds so caller can cancel native alarms too
    return staleRows
        .where((row) => row.androidAlarmId != null)
        .map((row) => row.androidAlarmId!)
        .toList();
  }

  @override
  Future<void> updateAlarmStatus(String id, domain.AlarmEventStatus status) async {
    await (_database.update(_database.alarmEvents)
          ..where((t) => t.id.equals(id)))
        .write(
      persistence.AlarmEventsCompanion(
        status: Value(status.name),
        statusChangedAtMs: Value(DateTime.now().millisecondsSinceEpoch),
        enabled: Value(status == domain.AlarmEventStatus.scheduled),
      ),
    );
  }

  @override
  Future<void> updateAlarmEvent(domain.AlarmEvent event) async {
    await (_database.update(_database.alarmEvents)
          ..where((t) => t.id.equals(event.id)))
        .write(_toEventCompanion(event));
  }

  @override
  Future<List<domain.AlarmEvent>> getAlarmHistory() async {
    final rows = await (_database.select(_database.alarmEvents)
          ..where((t) => t.status.equals('scheduled').not()))
        .get();
    return rows.map(_toDomainEvent).toList();
  }

  @override
  Future<void> purgeHistoryOlderThan(DateTime cutoff) async {
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    await (_database.delete(_database.alarmEvents)
          ..where(
            (t) =>
                t.status.equals('scheduled').not() &
                t.statusChangedAtMs.isSmallerOrEqualValue(cutoffMs),
          ))
        .go();
  }

  static domain.ScheduleDraft _toDomainDraft(persistence.ScheduleDraft row) {
    return domain.ScheduleDraft(
      id: row.id,
      source: ImportSource.values.byName(row.source),
      entries: _decodeRawEntries(row.rawJson),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }

  static domain.AlarmPlan _toDomainPlan(
    persistence.AlarmPlan row,
    List<domain.AlarmEvent> events,
  ) {
    return domain.AlarmPlan(
      id: row.id,
      scheduleId: row.scheduleId,
      alarms: events,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }

  static persistence.AlarmEventsCompanion _toEventCompanion(
    domain.AlarmEvent alarm,
  ) {
    return persistence.AlarmEventsCompanion(
      id: Value(alarm.id),
      planId: Value(alarm.planId),
      scheduledMs: Value(alarm.scheduledTime.millisecondsSinceEpoch),
      type: Value(alarm.type.name),
      toneProfile: Value(alarm.toneProfile.name),
      purpose: Value(alarm.purpose.name),
      sourceFieldKey: Value(alarm.sourceFieldKey),
      enabled: Value(alarm.enabled),
      androidAlarmId: Value(alarm.androidAlarmId),
      status: Value(alarm.status.name),
      statusChangedAtMs: Value(alarm.statusChangedAt?.millisecondsSinceEpoch),
    );
  }

  static domain.AlarmEvent _toDomainEvent(persistence.AlarmEvent row) {
    return domain.AlarmEvent(
      id: row.id,
      planId: row.planId,
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(row.scheduledMs),
      type: domain.AlarmEventType.values.byName(row.type),
      toneProfile: domain.ToneProfile.values.byName(row.toneProfile),
      purpose: domain.AlarmEventPurpose.values.byName(row.purpose),
      sourceFieldKey: row.sourceFieldKey,
      enabled: row.enabled,
      androidAlarmId: row.androidAlarmId,
      status: domain.AlarmEventStatus.values.byName(row.status),
      statusChangedAt: row.statusChangedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.statusChangedAtMs!),
    );
  }

  static String _encodeRawEntries(List<domain.RawEntry> entries) {
    return jsonEncode(entries.map(_rawEntryToJson).toList());
  }

  static List<domain.RawEntry> _decodeRawEntries(String rawJson) {
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded.cast<Map<String, Object?>>().map(_rawEntryFromJson).toList();
  }

  static Map<String, Object?> _rawEntryToJson(domain.RawEntry entry) {
    return {
      'id': entry.id,
      'source': entry.source.name,
      'fields': entry.fields,
      'confidence': {
        'level': entry.confidence.level.name,
        'reason': entry.confidence.reason,
        'ambiguousColumns': entry.confidence.ambiguousColumns,
      },
    };
  }

  static domain.RawEntry _rawEntryFromJson(Map<String, Object?> json) {
    final confidenceJson = json['confidence']! as Map<String, Object?>;
    final fieldsJson = json['fields']! as Map<String, Object?>;

    return domain.RawEntry(
      id: json['id']! as String,
      source: ImportSource.values.byName(json['source']! as String),
      fields: fieldsJson.map((key, value) => MapEntry(key, value as String)),
      confidence: Confidence(
        level: ConfidenceLevel.values.byName(
          confidenceJson['level']! as String,
        ),
        reason: confidenceJson['reason'] as String?,
        ambiguousColumns: (confidenceJson['ambiguousColumns']! as List<dynamic>)
            .cast<String>(),
      ),
    );
  }
}
