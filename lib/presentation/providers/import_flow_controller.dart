import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurone_ko_alarm/application/use_cases/import_schedule.dart';
import 'package:kurone_ko_alarm/application/use_cases/reviewed_alarm_plan_mapper.dart';
import 'package:kurone_ko_alarm/application/use_cases/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_plan.dart';
import 'package:kurone_ko_alarm/domain/entities/schedule_draft.dart';
import 'package:kurone_ko_alarm/domain/errors/domain_errors.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/import_schedule.dart';
import 'package:kurone_ko_alarm/domain/ports/inbound/review_and_confirm.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/clock.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/local_repository.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/permission_gateway.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/alarm/native_alarm_scheduler.dart';
import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/clock/system_clock.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/file_picker/flutter_file_picker_adapter.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/file_reader/excel_reader_adapter.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/ocr/ml_kit_ocr_adapter.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/permissions/android_permission_gateway.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/database.dart'
    as persistence;
import 'package:kurone_ko_alarm/infrastructure/adapters/persistence/drift_local_repository.dart';

enum ImportFlowStatus {
  idle,
  loading,
  reviewReady,
  confirmed,
  cancelled,
  error,
}

final class ImportFlowState {
  final ImportFlowStatus status;
  final String? selectedFileName;
  final ScheduleDraft? draft;
  final AlarmPlan? confirmedPlan;
  final List<AlarmEvent> activeAlarms;
  final List<AlarmEvent> history;
  final String? errorMessage;
  final String? feedbackMessage;
  final bool feedbackSuccess;

  const ImportFlowState({
    this.status = ImportFlowStatus.idle,
    this.selectedFileName,
    this.draft,
    this.confirmedPlan,
    this.activeAlarms = const [],
    this.history = const [],
    this.errorMessage,
    this.feedbackMessage,
    this.feedbackSuccess = true,
  });

  int get lowConfidenceCount => draft?.lowConfidenceEntries.length ?? 0;

  bool get canConfirm =>
      status == ImportFlowStatus.reviewReady &&
      draft != null &&
      !ReviewedAlarmPlanMapper.hasMissingRequiredDates(draft!) &&
      !ReviewedAlarmPlanMapper.hasInvalidAlarmTimes(draft!);

  ImportFlowState copyWith({
    ImportFlowStatus? status,
    String? selectedFileName,
    ScheduleDraft? draft,
    AlarmPlan? confirmedPlan,
    List<AlarmEvent>? activeAlarms,
    List<AlarmEvent>? history,
    String? errorMessage,
    String? feedbackMessage,
    bool? feedbackSuccess,
    bool clearDraft = false,
    bool clearPlan = false,
    bool clearError = false,
    bool clearFeedback = false,
  }) {
    return ImportFlowState(
      status: status ?? this.status,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      draft: clearDraft ? null : draft ?? this.draft,
      confirmedPlan: clearPlan ? null : confirmedPlan ?? this.confirmedPlan,
      activeAlarms: activeAlarms ?? this.activeAlarms,
      history: history ?? this.history,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      feedbackMessage: clearFeedback ? null : feedbackMessage ?? this.feedbackMessage,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}

final appDatabaseProvider = Provider<persistence.AppDatabase>((ref) {
  final database = persistence.AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return DriftLocalRepository(ref.watch(appDatabaseProvider));
});

final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  return const NativeAlarmScheduler();
});

final clockProvider = Provider<Clock>((ref) {
  return const SystemClock();
});

typedef ActiveAlarmRefreshTimerFactory =
    Timer Function(Duration interval, void Function() onTick);

final activeAlarmRefreshTimerFactoryProvider =
    Provider<ActiveAlarmRefreshTimerFactory>((ref) {
      return (interval, onTick) {
        return Timer.periodic(interval, (_) => onTick());
      };
    });

final permissionGatewayProvider = Provider<PermissionGateway>((ref) {
  return const AndroidPermissionGateway();
});

final filePickerProvider = Provider<FilePicker>(
  (ref) => FlutterFilePickerAdapter(),
);

final importScheduleUseCaseProvider = Provider<ImportScheduleUseCase>((ref) {
  return ImportScheduleUseCaseImpl(
    ocrReader: MlKitOcrAdapter(),
    structuredFileReader: ExcelReaderAdapter(),
    clock: const SystemClock(),
  );
});

final reviewAndConfirmUseCaseProvider = Provider<ReviewAndConfirmUseCase>((
  ref,
) {
  return ReviewAndConfirmUseCaseImpl(
    repository: ref.watch(localRepositoryProvider),
    clock: ref.watch(clockProvider),
    scheduler: ref.watch(alarmSchedulerProvider),
    permissionGateway: ref.watch(permissionGatewayProvider),
  );
});

final importFlowControllerProvider =
    StateNotifierProvider<ImportFlowController, ImportFlowState>((ref) {
      return ImportFlowController(
        filePicker: ref.watch(filePickerProvider),
        importUseCase: ref.watch(importScheduleUseCaseProvider),
        reviewUseCase: ref.watch(reviewAndConfirmUseCaseProvider),
        repository: ref.watch(localRepositoryProvider),
        clock: ref.watch(clockProvider),
        scheduler: ref.watch(alarmSchedulerProvider),
        activeAlarmRefreshTimerFactory: ref.watch(
          activeAlarmRefreshTimerFactoryProvider,
        ),
      );
    });

final class ImportFlowController extends StateNotifier<ImportFlowState> {
  final FilePicker _filePicker;
  final ImportScheduleUseCase _importUseCase;
  final ReviewAndConfirmUseCase _reviewUseCase;
  final LocalRepository _repository;
  final Clock _clock;
  final AlarmScheduler _scheduler;
  final ActiveAlarmRefreshTimerFactory _activeAlarmRefreshTimerFactory;
  final Duration _activeAlarmRefreshInterval;
  Timer? _activeAlarmRefreshTimer;
  Timer? _feedbackClearTimer;
  bool _isRefreshingActiveAlarms = false;

  ImportFlowController({
    required FilePicker filePicker,
    required ImportScheduleUseCase importUseCase,
    required ReviewAndConfirmUseCase reviewUseCase,
    required LocalRepository repository,
    required Clock clock,
    required AlarmScheduler scheduler,
    ActiveAlarmRefreshTimerFactory? activeAlarmRefreshTimerFactory,
    Duration activeAlarmRefreshInterval = const Duration(seconds: 5),
    bool skipAutoLoad = false,
  }) : _filePicker = filePicker,
       _importUseCase = importUseCase,
       _reviewUseCase = reviewUseCase,
       _repository = repository,
       _clock = clock,
       _scheduler = scheduler,
       _activeAlarmRefreshTimerFactory =
           activeAlarmRefreshTimerFactory ??
           ((interval, onTick) => Timer.periodic(interval, (_) => onTick())),
       _activeAlarmRefreshInterval = activeAlarmRefreshInterval,
       super(const ImportFlowState()) {
    _activeAlarmRefreshTimer = _activeAlarmRefreshTimerFactory(
      _activeAlarmRefreshInterval,
      _refreshActiveAlarmsFromTimer,
    );
    if (!skipAutoLoad) {
      unawaited(loadActiveAlarms());
    }
  }

  @override
  void dispose() {
    _activeAlarmRefreshTimer?.cancel();
    _feedbackClearTimer?.cancel();
    super.dispose();
  }

  void _setFeedback(String message, {bool success = true}) {
    _feedbackClearTimer?.cancel();
    state = state.copyWith(
      feedbackMessage: message,
      feedbackSuccess: success,
    );
    _feedbackClearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      state = state.copyWith(clearFeedback: true);
    });
  }

  Future<void> importFrom(FilePickType type) async {
    final selected = await _filePicker.pick(type: type);
    if (selected == null) {
      state = state.copyWith(status: ImportFlowStatus.idle, clearError: true);
      return;
    }

    state = ImportFlowState(
      status: ImportFlowStatus.loading,
      selectedFileName: selected.fileName,
    );

    try {
      final draft = await _importUseCase.import(
        filePath: selected.path,
        source: _sourceFor(type),
      );
      state = state.copyWith(
        status: ImportFlowStatus.reviewReady,
        draft: draft,
        clearError: true,
      );
    } catch (error) {
      state = ImportFlowState(
        status: ImportFlowStatus.error,
        selectedFileName: selected.fileName,
        errorMessage: error.toString(),
      );
    }
  }

  void editEntry({
    required String entryId,
    required Map<String, String> fields,
  }) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(
      draft: _reviewUseCase.updateEntry(
        draft,
        entryId: entryId,
        fields: fields,
      ),
    );
  }

  Future<void> confirm() async {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(
      status: ImportFlowStatus.loading,
      clearError: true,
      clearFeedback: true,
    );
    try {
      final plan = await _reviewUseCase.confirm(draft);
      final visibleAlarms = plan.alarms.isEmpty
          ? ReviewedAlarmPlanMapper.buildAlarms(
              draft,
              planId: 'preview_${draft.id}',
            )
          : plan.alarms;
      state = state.copyWith(
        status: ImportFlowStatus.confirmed,
        draft: draft,
        confirmedPlan: plan,
        activeAlarms: visibleAlarms,
      );
      _setFeedback('Cargado con éxito en alarmas activas', success: true);
    } catch (error) {
      state = state.copyWith(
        status: ImportFlowStatus.error,
        draft: draft,
        errorMessage: _messageForConfirmError(error),
      );
      _setFeedback(_messageForConfirmError(error), success: false);
    }
  }

  Future<void> cancel() async {
    final draft = state.draft;
    if (draft != null) {
      await _reviewUseCase.cancel(draft);
    }
    state = state.copyWith(status: ImportFlowStatus.cancelled, clearPlan: true);
  }

  Future<void> loadActiveAlarms() async {
    if (_isRefreshingActiveAlarms) {
      return;
    }
    _isRefreshingActiveAlarms = true;
    try {
      // Best-effort cleanup of native persisted alarms before we sync.
      try {
        await _scheduler.pruneNativeStaleAlarms(_clock.now());
      } catch (_) {
        // Native cleanup is best-effort; DB cleanup still runs when alarms load.
      }

      // Synchronize alarm outcomes from native side first, so dismissed
      // alarms are recorded before any pruning can mark them missed.
      List<Map<String, Object?>> outcomes = [];
      try {
        outcomes = await _scheduler.syncAlarmOutcomes();
      } catch (_) {
        // Sync is best-effort.
      }
      if (outcomes.isNotEmpty) {
        final allPlans = await _repository.getAllPlans();
        final allEvents = allPlans.expand((plan) => plan.alarms).toList();
        for (final outcome in outcomes) {
          final nativeId = outcome['id'] as int?;
          final statusName = outcome['status'] as String?;
          if (nativeId == null || statusName == null) continue;
          final event = allEvents.cast<AlarmEvent?>().firstWhere(
            (e) {
              if (e == null) return false;
              final expectedId = e.androidAlarmId ?? _scheduler.nativeIdFor(e);
              return expectedId == nativeId;
            },
            orElse: () => null,
          );
          if (event != null) {
            final status = AlarmEventStatus.values.byName(statusName);
            await _repository.updateAlarmStatus(event.id, status);
          }
        }
      }

      // Clean up stale alarms that are still scheduled: disable expired
      // ones in DB and cancel their native Android alarms.
      final prunedNativeIds = await _repository.pruneStaleEnabledEvents(
        _clock.now(),
      );
      for (final nativeId in prunedNativeIds) {
        try {
          await _scheduler.cancel(nativeId);
        } catch (_) {
          // Cancel is best-effort.
        }
      }

      // Purge history entries older than 24 hours.
      await _repository.purgeHistoryOlderThan(
        _clock.now().subtract(const Duration(hours: 24)),
      );

      // Load active alarms and history for display.
      final activeAlarms = await _repository.getAllEnabledEvents();
      final history = await _repository.getAlarmHistory();
      if (!mounted) return;
      state = state.copyWith(
        activeAlarms: activeAlarms,
        history: history,
      );
    } catch (_) {
      // Best-effort refresh; keep existing state on failure.
    } finally {
      _isRefreshingActiveAlarms = false;
    }
  }

  Future<void> editAlarmTime(String alarmId, DateTime newTime) async {
    final alarms = [...state.activeAlarms];
    final index = alarms.indexWhere((a) => a.id == alarmId);
    if (index == -1) return;

    final original = alarms[index];
    final updated = original.copyWith(scheduledTime: newTime);
    alarms[index] = updated;

    // If this is a main alarm, also shift its prewarning to maintain the
    // 1-minute offset.
    if (updated.type == AlarmEventType.main) {
      final prewarningId = '${updated.id}_pre';
      final preIndex = alarms.indexWhere((a) => a.id == prewarningId);
      if (preIndex != -1) {
        final updatedPre = alarms[preIndex].copyWith(
          scheduledTime: newTime.subtract(const Duration(minutes: 1)),
        );
        alarms[preIndex] = updatedPre;
        await _repository.updateAlarmEvent(updatedPre);
        final preNativeId = updatedPre.androidAlarmId ?? _scheduler.nativeIdFor(updatedPre);
        try {
          await _scheduler.cancel(preNativeId);
        } catch (_) {}
        try {
          await _scheduler.schedule(updatedPre);
        } catch (_) {}
      }
    }

    await _repository.updateAlarmEvent(updated);

    final nativeId = updated.androidAlarmId ?? _scheduler.nativeIdFor(updated);
    try {
      await _scheduler.cancel(nativeId);
    } catch (_) {}
    try {
      await _scheduler.schedule(updated);
    } catch (_) {}

    if (!mounted) return;
    state = state.copyWith(activeAlarms: alarms);
  }

  void hideAlarm(String alarmId) {
    state = state.copyWith(
      activeAlarms: state.activeAlarms
          .where((alarm) => alarm.id != alarmId)
          .toList(),
    );
  }

  void hideAllAlarms() {
    state = state.copyWith(activeAlarms: const []);
  }

  void reopenConfirmedForEditing() {
    if (state.draft == null) {
      return;
    }
    state = state.copyWith(
      status: ImportFlowStatus.reviewReady,
      clearPlan: true,
      activeAlarms: const [],
      clearError: true,
    );
  }

  Future<void> enterEditMode() async {
    final plans = await _repository.getAllPlans();
    if (!mounted) return;
    if (plans.isEmpty) {
      return;
    }
    final activePlans = plans.where((p) => p.alarms.any((a) => a.enabled)).toList();
    if (activePlans.isEmpty) {
      return;
    }
    activePlans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final plan = activePlans.first;
    final draft = await _repository.getDraft(plan.scheduleId);
    if (!mounted) return;
    if (draft == null) {
      return;
    }
    final activeAlarms = await _repository.getAllEnabledEvents();
    final history = await _repository.getAlarmHistory();
    if (!mounted) return;
    state = state.copyWith(
      status: ImportFlowStatus.reviewReady,
      draft: draft,
      confirmedPlan: plan,
      activeAlarms: activeAlarms,
      history: history,
      clearError: true,
    );
  }

  ImportSource _sourceFor(FilePickType type) {
    return switch (type) {
      FilePickType.image => ImportSource.image,
      FilePickType.excel || FilePickType.any => ImportSource.excel,
    };
  }

  String _messageForConfirmError(Object error) {
    return switch (error) {
      PermissionDenied(permission: 'exactAlarm') =>
        'Para programar las alarmas, habilita las alarmas exactas en Ajustes y confirma de nuevo.',
      PermissionDenied(permission: 'notifications') =>
        'Para recibir avisos a tiempo, habilita las notificaciones de la app en Ajustes y confirma de nuevo.',
      SchedulingFailure() =>
        'No se pudieron programar las alarmas. Revisa los permisos de alarmas exactas e intenta nuevamente.',
      ScheduleValidationFailure(message: final message) => message,
      _ => error.toString(),
    };
  }

  void _refreshActiveAlarmsFromTimer() {
    unawaited(loadActiveAlarms());
  }
}
