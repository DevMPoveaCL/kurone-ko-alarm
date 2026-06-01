import 'package:flutter/material.dart';
import 'package:kurone_ko_alarm/domain/entities/alarm_event.dart';
import 'package:kurone_ko_alarm/domain/services/alarm_event_label.dart';

final class AlarmTimeline extends StatefulWidget {
  final List<AlarmEvent> alarms;
  final List<AlarmEvent> history;
  final void Function(AlarmEvent alarm)? onEditAlarm;

  const AlarmTimeline({
    super.key,
    required this.alarms,
    this.history = const [],
    this.onEditAlarm,
  });

  @override
  State<AlarmTimeline> createState() => _AlarmTimelineState();
}

final class _AlarmTimelineState extends State<AlarmTimeline> {
  final Set<String> _expandedUpcomingDates = <String>{};

  @override
  void initState() {
    super.initState();
    _ensureNearestDayExpanded(widget.alarms);
  }

  @override
  void didUpdateWidget(covariant AlarmTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarms.isEmpty && widget.alarms.isNotEmpty) {
      _ensureNearestDayExpanded(widget.alarms);
    }
  }

  void _ensureNearestDayExpanded(List<AlarmEvent> alarms) {
    final sorted = [...alarms]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (sorted.isNotEmpty) {
      final key = _dateKey(sorted.first.scheduledTime);
      if (!_expandedUpcomingDates.contains(key)) {
        setState(() {
          _expandedUpcomingDates.add(key);
        });
      }
    }
  }

  static String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Map<String, List<AlarmEvent>> _groupByDate(List<AlarmEvent> events) {
    final groups = <String, List<AlarmEvent>>{};
    for (final event in events) {
      final key = _dateKey(event.scheduledTime);
      groups.putIfAbsent(key, () => []).add(event);
    }
    // Sort each group's alarms by time
    for (final entry in groups.entries) {
      entry.value.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    }
    // Sort keys chronologically
    final sortedKeys = groups.keys.toList()..sort();
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final sortedAlarms = [...widget.alarms]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final sortedHistory = [...widget.history]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final allEvents = [...widget.alarms, ...widget.history];
    final upcomingByDate = _groupByDate(sortedAlarms);
    final historyByDate = _groupByDate(sortedHistory);
    final onEdit = widget.onEditAlarm;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Historial ──
            Text(
              'Historial',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Alarmas sonadas o descartadas en las últimas 24 horas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (sortedHistory.isEmpty)
              const Text('No hay alarmas en el historial.')
            else
              for (final entry in historyByDate.entries)
                _DayGroup(
                  dateKey: entry.key,
                  date: entry.value.first.scheduledTime,
                  alarms: entry.value,
                  allEvents: allEvents,
                  isHistory: true,
                  onEditAlarm: onEdit,
                ),

            const SizedBox(height: 20),

            // ── Próximas alarmas ──
            Text(
              'Próximas alarmas programadas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo se muestran las alarmas futuras activas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (sortedAlarms.isEmpty)
              const Text('Sin alarmas programadas todavía')
            else
              for (final entry in upcomingByDate.entries)
                _DayGroup(
                  dateKey: entry.key,
                  date: entry.value.first.scheduledTime,
                  alarms: entry.value,
                  allEvents: allEvents,
                  initiallyExpanded: _expandedUpcomingDates.contains(entry.key),
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedUpcomingDates.add(entry.key);
                      } else {
                        _expandedUpcomingDates.remove(entry.key);
                      }
                    });
                  },
                  onEditAlarm: onEdit,
                ),
          ],
        ),
      ),
    );
  }
}

final class BreakPreviewTimeline extends StatelessWidget {
  final List<String> alarmTimes;

  const BreakPreviewTimeline({super.key, required this.alarmTimes});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verificación visual',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (alarmTimes.isEmpty)
              const Text('Agrega una fecha y al menos un horario de descanso.'),
            for (final alarmTime in alarmTimes) ...[
              _PreviewStep(
                label: 'Preaviso ${_minusOneMinute(alarmTime)}',
                icon: Icons.notifications_none,
              ),
              _PreviewStep(label: 'Alarma $alarmTime', icon: Icons.alarm),
            ],
          ],
        ),
      ),
    );
  }

  String _minusOneMinute(String time) {
    final parts = time.split(':');
    if (parts.length != 2 && parts.length != 3) {
      return '--:--';
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return '--:--';
    }
    final total = (hour * 60 + minute - 1) % (24 * 60);
    final normalized = total < 0 ? total + 24 * 60 : total;
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

final class _PreviewStep extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PreviewStep({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

final class _DayGroup extends StatelessWidget {
  final String dateKey;
  final DateTime date;
  final List<AlarmEvent> alarms;
  final List<AlarmEvent> allEvents;
  final bool isHistory;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final void Function(AlarmEvent alarm)? onEditAlarm;

  const _DayGroup({
    required this.dateKey,
    required this.date,
    required this.alarms,
    required this.allEvents,
    this.isHistory = false,
    this.initiallyExpanded = true,
    this.onExpansionChanged,
    this.onEditAlarm,
  });

  String get _header {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        title: Text(
          _header,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final alarm in alarms)
            _TimelineRow(
              alarm: alarm,
              allEvents: allEvents,
              isHistory: isHistory,
              onEditAlarm: onEditAlarm,
            ),
        ],
      ),
    );
  }
}

final class _TimelineRow extends StatelessWidget {
  final AlarmEvent alarm;
  final List<AlarmEvent> allEvents;
  final bool isHistory;
  final void Function(AlarmEvent alarm)? onEditAlarm;

  const _TimelineRow({
    required this.alarm,
    required this.allEvents,
    this.isHistory = false,
    this.onEditAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final label = AlarmEventLabel.title(alarm);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isHistory
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  alarm.type == AlarmEventType.preWarning
                      ? Icons.notifications_none
                      : Icons.alarm,
                  color: isHistory
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(_formatDate(alarm.scheduledTime)),
                        Text(
                          _formatTime(alarm.scheduledTime),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (isHistory) _StatusChip(status: alarm.status),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isHistory) _StatusPill(enabled: alarm.enabled),
              if (!isHistory && onEditAlarm != null)
                TextButton(
                  onPressed: () => onEditAlarm!(alarm),
                  child: const Text('Editar'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

final class _StatusPill extends StatelessWidget {
  final bool enabled;

  const _StatusPill({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context).colorScheme.tertiaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          enabled ? 'Activa' : 'Inactiva',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: enabled
                ? Theme.of(context).colorScheme.onTertiaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  final AlarmEventStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      AlarmEventStatus.fired => 'Sonada',
      AlarmEventStatus.dismissed => 'Descartada',
      AlarmEventStatus.missed => 'Perdida',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
