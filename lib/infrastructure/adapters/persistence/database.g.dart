// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ScheduleDraftsTable extends ScheduleDrafts
    with TableInfo<$ScheduleDraftsTable, ScheduleDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduleDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, source, rawJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schedule_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduleDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduleDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduleDraft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScheduleDraftsTable createAlias(String alias) {
    return $ScheduleDraftsTable(attachedDatabase, alias);
  }
}

class ScheduleDraft extends DataClass implements Insertable<ScheduleDraft> {
  final String id;
  final String source;
  final String rawJson;
  final int createdAt;
  const ScheduleDraft({
    required this.id,
    required this.source,
    required this.rawJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source'] = Variable<String>(source);
    map['raw_json'] = Variable<String>(rawJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ScheduleDraftsCompanion toCompanion(bool nullToAbsent) {
    return ScheduleDraftsCompanion(
      id: Value(id),
      source: Value(source),
      rawJson: Value(rawJson),
      createdAt: Value(createdAt),
    );
  }

  factory ScheduleDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduleDraft(
      id: serializer.fromJson<String>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'source': serializer.toJson<String>(source),
      'rawJson': serializer.toJson<String>(rawJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ScheduleDraft copyWith({
    String? id,
    String? source,
    String? rawJson,
    int? createdAt,
  }) => ScheduleDraft(
    id: id ?? this.id,
    source: source ?? this.source,
    rawJson: rawJson ?? this.rawJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ScheduleDraft copyWithCompanion(ScheduleDraftsCompanion data) {
    return ScheduleDraft(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleDraft(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, rawJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduleDraft &&
          other.id == this.id &&
          other.source == this.source &&
          other.rawJson == this.rawJson &&
          other.createdAt == this.createdAt);
}

class ScheduleDraftsCompanion extends UpdateCompanion<ScheduleDraft> {
  final Value<String> id;
  final Value<String> source;
  final Value<String> rawJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ScheduleDraftsCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScheduleDraftsCompanion.insert({
    required String id,
    required String source,
    required String rawJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       source = Value(source),
       rawJson = Value(rawJson),
       createdAt = Value(createdAt);
  static Insertable<ScheduleDraft> custom({
    Expression<String>? id,
    Expression<String>? source,
    Expression<String>? rawJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (rawJson != null) 'raw_json': rawJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScheduleDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? source,
    Value<String>? rawJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ScheduleDraftsCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      rawJson: rawJson ?? this.rawJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduleDraftsCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('rawJson: $rawJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlarmPlansTable extends AlarmPlans
    with TableInfo<$AlarmPlansTable, AlarmPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, scheduleId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmPlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmPlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AlarmPlansTable createAlias(String alias) {
    return $AlarmPlansTable(attachedDatabase, alias);
  }
}

class AlarmPlan extends DataClass implements Insertable<AlarmPlan> {
  final String id;
  final String scheduleId;
  final int createdAt;
  const AlarmPlan({
    required this.id,
    required this.scheduleId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schedule_id'] = Variable<String>(scheduleId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AlarmPlansCompanion toCompanion(bool nullToAbsent) {
    return AlarmPlansCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      createdAt: Value(createdAt),
    );
  }

  factory AlarmPlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmPlan(
      id: serializer.fromJson<String>(json['id']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  AlarmPlan copyWith({String? id, String? scheduleId, int? createdAt}) =>
      AlarmPlan(
        id: id ?? this.id,
        scheduleId: scheduleId ?? this.scheduleId,
        createdAt: createdAt ?? this.createdAt,
      );
  AlarmPlan copyWithCompanion(AlarmPlansCompanion data) {
    return AlarmPlan(
      id: data.id.present ? data.id.value : this.id,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmPlan(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scheduleId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmPlan &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.createdAt == this.createdAt);
}

class AlarmPlansCompanion extends UpdateCompanion<AlarmPlan> {
  final Value<String> id;
  final Value<String> scheduleId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AlarmPlansCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmPlansCompanion.insert({
    required String id,
    required String scheduleId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scheduleId = Value(scheduleId),
       createdAt = Value(createdAt);
  static Insertable<AlarmPlan> custom({
    Expression<String>? id,
    Expression<String>? scheduleId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmPlansCompanion copyWith({
    Value<String>? id,
    Value<String>? scheduleId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return AlarmPlansCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmPlansCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlarmEventsTable extends AlarmEvents
    with TableInfo<$AlarmEventsTable, AlarmEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledMsMeta = const VerificationMeta(
    'scheduledMs',
  );
  @override
  late final GeneratedColumn<int> scheduledMs = GeneratedColumn<int>(
    'scheduled_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toneProfileMeta = const VerificationMeta(
    'toneProfile',
  );
  @override
  late final GeneratedColumn<String> toneProfile = GeneratedColumn<String>(
    'tone_profile',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('breakStart'),
  );
  static const VerificationMeta _sourceFieldKeyMeta = const VerificationMeta(
    'sourceFieldKey',
  );
  @override
  late final GeneratedColumn<String> sourceFieldKey = GeneratedColumn<String>(
    'source_field_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _androidAlarmIdMeta = const VerificationMeta(
    'androidAlarmId',
  );
  @override
  late final GeneratedColumn<int> androidAlarmId = GeneratedColumn<int>(
    'android_alarm_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _statusChangedAtMsMeta = const VerificationMeta(
    'statusChangedAtMs',
  );
  @override
  late final GeneratedColumn<int> statusChangedAtMs = GeneratedColumn<int>(
    'status_changed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    scheduledMs,
    type,
    toneProfile,
    purpose,
    sourceFieldKey,
    enabled,
    androidAlarmId,
    status,
    statusChangedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('scheduled_ms')) {
      context.handle(
        _scheduledMsMeta,
        scheduledMs.isAcceptableOrUnknown(
          data['scheduled_ms']!,
          _scheduledMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledMsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('tone_profile')) {
      context.handle(
        _toneProfileMeta,
        toneProfile.isAcceptableOrUnknown(
          data['tone_profile']!,
          _toneProfileMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toneProfileMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    }
    if (data.containsKey('source_field_key')) {
      context.handle(
        _sourceFieldKeyMeta,
        sourceFieldKey.isAcceptableOrUnknown(
          data['source_field_key']!,
          _sourceFieldKeyMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('android_alarm_id')) {
      context.handle(
        _androidAlarmIdMeta,
        androidAlarmId.isAcceptableOrUnknown(
          data['android_alarm_id']!,
          _androidAlarmIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('status_changed_at_ms')) {
      context.handle(
        _statusChangedAtMsMeta,
        statusChangedAtMs.isAcceptableOrUnknown(
          data['status_changed_at_ms']!,
          _statusChangedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      scheduledMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_ms'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      toneProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone_profile'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      sourceFieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_field_key'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      androidAlarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}android_alarm_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      statusChangedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_changed_at_ms'],
      ),
    );
  }

  @override
  $AlarmEventsTable createAlias(String alias) {
    return $AlarmEventsTable(attachedDatabase, alias);
  }
}

class AlarmEvent extends DataClass implements Insertable<AlarmEvent> {
  final String id;
  final String planId;
  final int scheduledMs;
  final String type;
  final String toneProfile;
  final String purpose;
  final String sourceFieldKey;
  final bool enabled;
  final int? androidAlarmId;
  final String status;
  final int? statusChangedAtMs;
  const AlarmEvent({
    required this.id,
    required this.planId,
    required this.scheduledMs,
    required this.type,
    required this.toneProfile,
    required this.purpose,
    required this.sourceFieldKey,
    required this.enabled,
    this.androidAlarmId,
    required this.status,
    this.statusChangedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['scheduled_ms'] = Variable<int>(scheduledMs);
    map['type'] = Variable<String>(type);
    map['tone_profile'] = Variable<String>(toneProfile);
    map['purpose'] = Variable<String>(purpose);
    map['source_field_key'] = Variable<String>(sourceFieldKey);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || androidAlarmId != null) {
      map['android_alarm_id'] = Variable<int>(androidAlarmId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || statusChangedAtMs != null) {
      map['status_changed_at_ms'] = Variable<int>(statusChangedAtMs);
    }
    return map;
  }

  AlarmEventsCompanion toCompanion(bool nullToAbsent) {
    return AlarmEventsCompanion(
      id: Value(id),
      planId: Value(planId),
      scheduledMs: Value(scheduledMs),
      type: Value(type),
      toneProfile: Value(toneProfile),
      purpose: Value(purpose),
      sourceFieldKey: Value(sourceFieldKey),
      enabled: Value(enabled),
      androidAlarmId: androidAlarmId == null && nullToAbsent
          ? const Value.absent()
          : Value(androidAlarmId),
      status: Value(status),
      statusChangedAtMs: statusChangedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(statusChangedAtMs),
    );
  }

  factory AlarmEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmEvent(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['planId']),
      scheduledMs: serializer.fromJson<int>(json['scheduledMs']),
      type: serializer.fromJson<String>(json['type']),
      toneProfile: serializer.fromJson<String>(json['toneProfile']),
      purpose: serializer.fromJson<String>(json['purpose']),
      sourceFieldKey: serializer.fromJson<String>(json['sourceFieldKey']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      androidAlarmId: serializer.fromJson<int?>(json['androidAlarmId']),
      status: serializer.fromJson<String>(json['status']),
      statusChangedAtMs: serializer.fromJson<int?>(json['statusChangedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String>(planId),
      'scheduledMs': serializer.toJson<int>(scheduledMs),
      'type': serializer.toJson<String>(type),
      'toneProfile': serializer.toJson<String>(toneProfile),
      'purpose': serializer.toJson<String>(purpose),
      'sourceFieldKey': serializer.toJson<String>(sourceFieldKey),
      'enabled': serializer.toJson<bool>(enabled),
      'androidAlarmId': serializer.toJson<int?>(androidAlarmId),
      'status': serializer.toJson<String>(status),
      'statusChangedAtMs': serializer.toJson<int?>(statusChangedAtMs),
    };
  }

  AlarmEvent copyWith({
    String? id,
    String? planId,
    int? scheduledMs,
    String? type,
    String? toneProfile,
    String? purpose,
    String? sourceFieldKey,
    bool? enabled,
    Value<int?> androidAlarmId = const Value.absent(),
    String? status,
    Value<int?> statusChangedAtMs = const Value.absent(),
  }) => AlarmEvent(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    scheduledMs: scheduledMs ?? this.scheduledMs,
    type: type ?? this.type,
    toneProfile: toneProfile ?? this.toneProfile,
    purpose: purpose ?? this.purpose,
    sourceFieldKey: sourceFieldKey ?? this.sourceFieldKey,
    enabled: enabled ?? this.enabled,
    androidAlarmId: androidAlarmId.present
        ? androidAlarmId.value
        : this.androidAlarmId,
    status: status ?? this.status,
    statusChangedAtMs: statusChangedAtMs.present
        ? statusChangedAtMs.value
        : this.statusChangedAtMs,
  );
  AlarmEvent copyWithCompanion(AlarmEventsCompanion data) {
    return AlarmEvent(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      scheduledMs: data.scheduledMs.present
          ? data.scheduledMs.value
          : this.scheduledMs,
      type: data.type.present ? data.type.value : this.type,
      toneProfile: data.toneProfile.present
          ? data.toneProfile.value
          : this.toneProfile,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      sourceFieldKey: data.sourceFieldKey.present
          ? data.sourceFieldKey.value
          : this.sourceFieldKey,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      androidAlarmId: data.androidAlarmId.present
          ? data.androidAlarmId.value
          : this.androidAlarmId,
      status: data.status.present ? data.status.value : this.status,
      statusChangedAtMs: data.statusChangedAtMs.present
          ? data.statusChangedAtMs.value
          : this.statusChangedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmEvent(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('scheduledMs: $scheduledMs, ')
          ..write('type: $type, ')
          ..write('toneProfile: $toneProfile, ')
          ..write('purpose: $purpose, ')
          ..write('sourceFieldKey: $sourceFieldKey, ')
          ..write('enabled: $enabled, ')
          ..write('androidAlarmId: $androidAlarmId, ')
          ..write('status: $status, ')
          ..write('statusChangedAtMs: $statusChangedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    scheduledMs,
    type,
    toneProfile,
    purpose,
    sourceFieldKey,
    enabled,
    androidAlarmId,
    status,
    statusChangedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmEvent &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.scheduledMs == this.scheduledMs &&
          other.type == this.type &&
          other.toneProfile == this.toneProfile &&
          other.purpose == this.purpose &&
          other.sourceFieldKey == this.sourceFieldKey &&
          other.enabled == this.enabled &&
          other.androidAlarmId == this.androidAlarmId &&
          other.status == this.status &&
          other.statusChangedAtMs == this.statusChangedAtMs);
}

class AlarmEventsCompanion extends UpdateCompanion<AlarmEvent> {
  final Value<String> id;
  final Value<String> planId;
  final Value<int> scheduledMs;
  final Value<String> type;
  final Value<String> toneProfile;
  final Value<String> purpose;
  final Value<String> sourceFieldKey;
  final Value<bool> enabled;
  final Value<int?> androidAlarmId;
  final Value<String> status;
  final Value<int?> statusChangedAtMs;
  final Value<int> rowid;
  const AlarmEventsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.scheduledMs = const Value.absent(),
    this.type = const Value.absent(),
    this.toneProfile = const Value.absent(),
    this.purpose = const Value.absent(),
    this.sourceFieldKey = const Value.absent(),
    this.enabled = const Value.absent(),
    this.androidAlarmId = const Value.absent(),
    this.status = const Value.absent(),
    this.statusChangedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmEventsCompanion.insert({
    required String id,
    required String planId,
    required int scheduledMs,
    required String type,
    required String toneProfile,
    this.purpose = const Value.absent(),
    this.sourceFieldKey = const Value.absent(),
    this.enabled = const Value.absent(),
    this.androidAlarmId = const Value.absent(),
    this.status = const Value.absent(),
    this.statusChangedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       scheduledMs = Value(scheduledMs),
       type = Value(type),
       toneProfile = Value(toneProfile);
  static Insertable<AlarmEvent> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<int>? scheduledMs,
    Expression<String>? type,
    Expression<String>? toneProfile,
    Expression<String>? purpose,
    Expression<String>? sourceFieldKey,
    Expression<bool>? enabled,
    Expression<int>? androidAlarmId,
    Expression<String>? status,
    Expression<int>? statusChangedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (scheduledMs != null) 'scheduled_ms': scheduledMs,
      if (type != null) 'type': type,
      if (toneProfile != null) 'tone_profile': toneProfile,
      if (purpose != null) 'purpose': purpose,
      if (sourceFieldKey != null) 'source_field_key': sourceFieldKey,
      if (enabled != null) 'enabled': enabled,
      if (androidAlarmId != null) 'android_alarm_id': androidAlarmId,
      if (status != null) 'status': status,
      if (statusChangedAtMs != null) 'status_changed_at_ms': statusChangedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<int>? scheduledMs,
    Value<String>? type,
    Value<String>? toneProfile,
    Value<String>? purpose,
    Value<String>? sourceFieldKey,
    Value<bool>? enabled,
    Value<int?>? androidAlarmId,
    Value<String>? status,
    Value<int?>? statusChangedAtMs,
    Value<int>? rowid,
  }) {
    return AlarmEventsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      scheduledMs: scheduledMs ?? this.scheduledMs,
      type: type ?? this.type,
      toneProfile: toneProfile ?? this.toneProfile,
      purpose: purpose ?? this.purpose,
      sourceFieldKey: sourceFieldKey ?? this.sourceFieldKey,
      enabled: enabled ?? this.enabled,
      androidAlarmId: androidAlarmId ?? this.androidAlarmId,
      status: status ?? this.status,
      statusChangedAtMs: statusChangedAtMs ?? this.statusChangedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (scheduledMs.present) {
      map['scheduled_ms'] = Variable<int>(scheduledMs.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (toneProfile.present) {
      map['tone_profile'] = Variable<String>(toneProfile.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (sourceFieldKey.present) {
      map['source_field_key'] = Variable<String>(sourceFieldKey.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (androidAlarmId.present) {
      map['android_alarm_id'] = Variable<int>(androidAlarmId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (statusChangedAtMs.present) {
      map['status_changed_at_ms'] = Variable<int>(statusChangedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmEventsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('scheduledMs: $scheduledMs, ')
          ..write('type: $type, ')
          ..write('toneProfile: $toneProfile, ')
          ..write('purpose: $purpose, ')
          ..write('sourceFieldKey: $sourceFieldKey, ')
          ..write('enabled: $enabled, ')
          ..write('androidAlarmId: $androidAlarmId, ')
          ..write('status: $status, ')
          ..write('statusChangedAtMs: $statusChangedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScheduleDraftsTable scheduleDrafts = $ScheduleDraftsTable(this);
  late final $AlarmPlansTable alarmPlans = $AlarmPlansTable(this);
  late final $AlarmEventsTable alarmEvents = $AlarmEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    scheduleDrafts,
    alarmPlans,
    alarmEvents,
  ];
}

typedef $$ScheduleDraftsTableCreateCompanionBuilder =
    ScheduleDraftsCompanion Function({
      required String id,
      required String source,
      required String rawJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ScheduleDraftsTableUpdateCompanionBuilder =
    ScheduleDraftsCompanion Function({
      Value<String> id,
      Value<String> source,
      Value<String> rawJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ScheduleDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduleDraftsTable> {
  $$ScheduleDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScheduleDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduleDraftsTable> {
  $$ScheduleDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScheduleDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduleDraftsTable> {
  $$ScheduleDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ScheduleDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduleDraftsTable,
          ScheduleDraft,
          $$ScheduleDraftsTableFilterComposer,
          $$ScheduleDraftsTableOrderingComposer,
          $$ScheduleDraftsTableAnnotationComposer,
          $$ScheduleDraftsTableCreateCompanionBuilder,
          $$ScheduleDraftsTableUpdateCompanionBuilder,
          (
            ScheduleDraft,
            BaseReferences<_$AppDatabase, $ScheduleDraftsTable, ScheduleDraft>,
          ),
          ScheduleDraft,
          PrefetchHooks Function()
        > {
  $$ScheduleDraftsTableTableManager(
    _$AppDatabase db,
    $ScheduleDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduleDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduleDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScheduleDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScheduleDraftsCompanion(
                id: id,
                source: source,
                rawJson: rawJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String source,
                required String rawJson,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ScheduleDraftsCompanion.insert(
                id: id,
                source: source,
                rawJson: rawJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScheduleDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduleDraftsTable,
      ScheduleDraft,
      $$ScheduleDraftsTableFilterComposer,
      $$ScheduleDraftsTableOrderingComposer,
      $$ScheduleDraftsTableAnnotationComposer,
      $$ScheduleDraftsTableCreateCompanionBuilder,
      $$ScheduleDraftsTableUpdateCompanionBuilder,
      (
        ScheduleDraft,
        BaseReferences<_$AppDatabase, $ScheduleDraftsTable, ScheduleDraft>,
      ),
      ScheduleDraft,
      PrefetchHooks Function()
    >;
typedef $$AlarmPlansTableCreateCompanionBuilder =
    AlarmPlansCompanion Function({
      required String id,
      required String scheduleId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$AlarmPlansTableUpdateCompanionBuilder =
    AlarmPlansCompanion Function({
      Value<String> id,
      Value<String> scheduleId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$AlarmPlansTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmPlansTable> {
  $$AlarmPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmPlansTable> {
  $$AlarmPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmPlansTable> {
  $$AlarmPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scheduleId => $composableBuilder(
    column: $table.scheduleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AlarmPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmPlansTable,
          AlarmPlan,
          $$AlarmPlansTableFilterComposer,
          $$AlarmPlansTableOrderingComposer,
          $$AlarmPlansTableAnnotationComposer,
          $$AlarmPlansTableCreateCompanionBuilder,
          $$AlarmPlansTableUpdateCompanionBuilder,
          (
            AlarmPlan,
            BaseReferences<_$AppDatabase, $AlarmPlansTable, AlarmPlan>,
          ),
          AlarmPlan,
          PrefetchHooks Function()
        > {
  $$AlarmPlansTableTableManager(_$AppDatabase db, $AlarmPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scheduleId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmPlansCompanion(
                id: id,
                scheduleId: scheduleId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scheduleId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AlarmPlansCompanion.insert(
                id: id,
                scheduleId: scheduleId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmPlansTable,
      AlarmPlan,
      $$AlarmPlansTableFilterComposer,
      $$AlarmPlansTableOrderingComposer,
      $$AlarmPlansTableAnnotationComposer,
      $$AlarmPlansTableCreateCompanionBuilder,
      $$AlarmPlansTableUpdateCompanionBuilder,
      (AlarmPlan, BaseReferences<_$AppDatabase, $AlarmPlansTable, AlarmPlan>),
      AlarmPlan,
      PrefetchHooks Function()
    >;
typedef $$AlarmEventsTableCreateCompanionBuilder =
    AlarmEventsCompanion Function({
      required String id,
      required String planId,
      required int scheduledMs,
      required String type,
      required String toneProfile,
      Value<String> purpose,
      Value<String> sourceFieldKey,
      Value<bool> enabled,
      Value<int?> androidAlarmId,
      Value<String> status,
      Value<int?> statusChangedAtMs,
      Value<int> rowid,
    });
typedef $$AlarmEventsTableUpdateCompanionBuilder =
    AlarmEventsCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<int> scheduledMs,
      Value<String> type,
      Value<String> toneProfile,
      Value<String> purpose,
      Value<String> sourceFieldKey,
      Value<bool> enabled,
      Value<int?> androidAlarmId,
      Value<String> status,
      Value<int?> statusChangedAtMs,
      Value<int> rowid,
    });

class $$AlarmEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmEventsTable> {
  $$AlarmEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toneProfile => $composableBuilder(
    column: $table.toneProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFieldKey => $composableBuilder(
    column: $table.sourceFieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get androidAlarmId => $composableBuilder(
    column: $table.androidAlarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusChangedAtMs => $composableBuilder(
    column: $table.statusChangedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmEventsTable> {
  $$AlarmEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toneProfile => $composableBuilder(
    column: $table.toneProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFieldKey => $composableBuilder(
    column: $table.sourceFieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get androidAlarmId => $composableBuilder(
    column: $table.androidAlarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusChangedAtMs => $composableBuilder(
    column: $table.statusChangedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmEventsTable> {
  $$AlarmEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get toneProfile => $composableBuilder(
    column: $table.toneProfile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get sourceFieldKey => $composableBuilder(
    column: $table.sourceFieldKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get androidAlarmId => $composableBuilder(
    column: $table.androidAlarmId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get statusChangedAtMs => $composableBuilder(
    column: $table.statusChangedAtMs,
    builder: (column) => column,
  );
}

class $$AlarmEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmEventsTable,
          AlarmEvent,
          $$AlarmEventsTableFilterComposer,
          $$AlarmEventsTableOrderingComposer,
          $$AlarmEventsTableAnnotationComposer,
          $$AlarmEventsTableCreateCompanionBuilder,
          $$AlarmEventsTableUpdateCompanionBuilder,
          (
            AlarmEvent,
            BaseReferences<_$AppDatabase, $AlarmEventsTable, AlarmEvent>,
          ),
          AlarmEvent,
          PrefetchHooks Function()
        > {
  $$AlarmEventsTableTableManager(_$AppDatabase db, $AlarmEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<int> scheduledMs = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> toneProfile = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> sourceFieldKey = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> androidAlarmId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> statusChangedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmEventsCompanion(
                id: id,
                planId: planId,
                scheduledMs: scheduledMs,
                type: type,
                toneProfile: toneProfile,
                purpose: purpose,
                sourceFieldKey: sourceFieldKey,
                enabled: enabled,
                androidAlarmId: androidAlarmId,
                status: status,
                statusChangedAtMs: statusChangedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required int scheduledMs,
                required String type,
                required String toneProfile,
                Value<String> purpose = const Value.absent(),
                Value<String> sourceFieldKey = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> androidAlarmId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> statusChangedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmEventsCompanion.insert(
                id: id,
                planId: planId,
                scheduledMs: scheduledMs,
                type: type,
                toneProfile: toneProfile,
                purpose: purpose,
                sourceFieldKey: sourceFieldKey,
                enabled: enabled,
                androidAlarmId: androidAlarmId,
                status: status,
                statusChangedAtMs: statusChangedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmEventsTable,
      AlarmEvent,
      $$AlarmEventsTableFilterComposer,
      $$AlarmEventsTableOrderingComposer,
      $$AlarmEventsTableAnnotationComposer,
      $$AlarmEventsTableCreateCompanionBuilder,
      $$AlarmEventsTableUpdateCompanionBuilder,
      (
        AlarmEvent,
        BaseReferences<_$AppDatabase, $AlarmEventsTable, AlarmEvent>,
      ),
      AlarmEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScheduleDraftsTableTableManager get scheduleDrafts =>
      $$ScheduleDraftsTableTableManager(_db, _db.scheduleDrafts);
  $$AlarmPlansTableTableManager get alarmPlans =>
      $$AlarmPlansTableTableManager(_db, _db.alarmPlans);
  $$AlarmEventsTableTableManager get alarmEvents =>
      $$AlarmEventsTableTableManager(_db, _db.alarmEvents);
}
