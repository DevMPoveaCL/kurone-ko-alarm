import 'package:flutter/material.dart';
import 'package:kurone_ko_alarm/domain/value_objects/confidence.dart';

final class ConfidenceBadge extends StatelessWidget {
  final Confidence confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (confidence.level) {
      ConfidenceLevel.high => (
        'Verificado',
        Icons.check_circle_outline,
        Colors.green,
      ),
      ConfidenceLevel.medium => (
        'Revisar leve',
        Icons.info_outline,
        Colors.blueGrey,
      ),
      ConfidenceLevel.low => (
        'Revisar',
        Icons.warning_amber_rounded,
        Colors.amber,
      ),
    };

    return Semantics(
      label: 'Confianza $label',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color.shade700OrSelf),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade700OrSelf => this;
}
