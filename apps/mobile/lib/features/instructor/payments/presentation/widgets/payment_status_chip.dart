import 'package:flutter/material.dart';

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({
    super.key,
    required this.label,
  });

  final String label;

  Color _colorFor(String value, BuildContext context) {
    final normalized = value.toLowerCase();
    if (normalized.contains('completed') || normalized.contains('captured')) {
      return Colors.green;
    }
    if (normalized.contains('failed') || normalized.contains('cancelled')) {
      return Theme.of(context).colorScheme.error;
    }
    if (normalized.contains('transit') || normalized.contains('processing')) {
      return Colors.orange;
    }
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
