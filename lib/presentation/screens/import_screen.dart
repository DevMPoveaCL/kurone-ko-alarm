import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurone_ko_alarm/application/use_cases/reviewed_alarm_plan_mapper.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/entities/raw_entry.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';
import 'package:kurone_ko_alarm/presentation/providers/import_flow_controller.dart';
import 'package:kurone_ko_alarm/presentation/widgets/alarm_timeline.dart';
import 'package:kurone_ko_alarm/presentation/widgets/confidence_badge.dart';

const _reviewPreviewLimit = 24;

/// Settable alarm fields are defined once in [ReviewedAlarmPlanMapper]
/// so the review UI and the scheduler share a single source of truth.
final _reviewTimeFields = ReviewedAlarmPlanMapper.settableAlarmFieldLabels;

final class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importFlowControllerProvider);
    final controller = ref.read(importFlowControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            _ImportSourceCard(
              controller: controller,
              isLoading: state.status == ImportFlowStatus.loading,
            ),
            const SizedBox(height: 16),
            if (state.status == ImportFlowStatus.loading) const _LoadingCard(),
            if (state.status == ImportFlowStatus.error)
              _ErrorCard(message: state.errorMessage ?? 'Error desconocido'),
            if (state.status == ImportFlowStatus.reviewReady &&
                state.draft != null)
              _ReviewCard(state: state, controller: controller),
            if (state.status == ImportFlowStatus.cancelled)
              const _CancelledCard(),
            const SizedBox(height: 16),
            _AlarmListCard(state: state, controller: controller),
          ],
        ),
      ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kurone-ko Alarm',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Importa tus descansos, revisa cada fila y confirma solo cuando el horario esté claro.',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

final class _ImportSourceCard extends StatelessWidget {
  final ImportFlowController controller;
  final bool isLoading;

  const _ImportSourceCard({required this.controller, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Origen del horario',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Elige la fuente que tienes a mano. Todo se procesa localmente en el dispositivo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => controller.importFrom(FilePickType.excel),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Importar Excel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => controller.importFrom(FilePickType.image),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Importar imagen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Leyendo el horario y preparando la revisión…')),
        ],
      ),
    );
  }
}

final class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'No pudimos importar el horario',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Cargar manualmente'),
          ),
        ],
      ),
    );
  }
}

final class _ReviewCard extends StatelessWidget {
  final ImportFlowState state;
  final ImportFlowController controller;

  const _ReviewCard({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final draft = state.draft!;
    final visibleEntries = draft.entries.take(_reviewPreviewLimit).toList();
    final hiddenCount = draft.entries.length - visibleEntries.length;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisión lista', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            state.selectedFileName ?? draft.id,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state.lowConfidenceCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${state.lowConfidenceCount} fila requiere atención antes de confirmar.',
            ),
          ],
          if (hiddenCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Mostrando ${visibleEntries.length} de ${draft.entries.length} filas detectadas.',
            ),
          ],
          const SizedBox(height: 16),
          for (final entry in visibleEntries)
            _EditableEntryCard(entry: entry, controller: controller),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.canConfirm ? controller.confirm : null,
                  icon: const Icon(Icons.alarm_on_outlined),
                  label: const Text('Confirmar alarmas'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: controller.cancel,
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _EditableEntryCard extends StatelessWidget {
  final RawEntry entry;
  final ImportFlowController controller;

  const _EditableEntryCard({required this.entry, required this.controller});

  @override
  Widget build(BuildContext context) {
    final name = entry.fields['name'] ?? 'Sin nombre';
    final visibleTimeFields = _reviewTimeFields.entries
        .where((field) => entry.fields.containsKey(field.key))
        .toList();
    final previewTimes = visibleTimeFields
        .map((field) => entry.fields[field.key]?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ConfidenceBadge(confidence: entry.confidence),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('${entry.id}-date'),
                initialValue: entry.fields['date'] ?? '',
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => controller.editEntry(
                  entryId: entry.id,
                  fields: {'date': value},
                ),
              ),
              for (final field in visibleTimeFields) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('${entry.id}-${field.key}'),
                  initialValue: entry.fields[field.key] ?? '',
                  decoration: InputDecoration(
                    labelText: '${field.value} · 24 horas, hora local',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => controller.editEntry(
                    entryId: entry.id,
                    fields: {field.key: value},
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BreakPreviewTimeline(alarmTimes: previewTimes),
            ],
          ),
        ),
      ),
    );
  }
}

final class _CancelledCard extends StatelessWidget {
  const _CancelledCard();

  @override
  Widget build(BuildContext context) {
    return const _SurfaceCard(
      child: Text('Importación cancelada. No se programó ninguna alarma.'),
    );
  }
}

final class _AlarmListCard extends StatelessWidget {
  final ImportFlowState state;
  final ImportFlowController controller;

  const _AlarmListCard({required this.state, required this.controller});

  Future<void> _showEditAlarmDialog(BuildContext context, AlarmEvent alarm) async {
    final initialTime = TimeOfDay.fromDateTime(alarm.scheduledTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Cambiar hora',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );
    if (picked == null) return;
    final newTime = DateTime(
      alarm.scheduledTime.year,
      alarm.scheduledTime.month,
      alarm.scheduledTime.day,
      picked.hour,
      picked.minute,
    );
    await controller.editAlarmTime(alarm.id, newTime);
  }

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alarmas activas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: controller.loadActiveAlarms,
                child: const Text('Actualizar'),
              ),
            ],
          ),
          if (state.feedbackMessage != null) ...[
            const SizedBox(height: 8),
            _FeedbackBanner(
              message: state.feedbackMessage!,
              success: state.feedbackSuccess,
            ),
          ],
          const SizedBox(height: 8),
          AlarmTimeline(
            alarms: state.activeAlarms,
            history: state.history,
            onEditAlarm: (alarm) => _showEditAlarmDialog(context, alarm),
          ),
        ],
      ),
    );
  }
}

final class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool success;

  const _FeedbackBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: success ? colorScheme.primary : colorScheme.error,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: success ? colorScheme.primary : colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: success
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
