import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickfit/features/instructor/payments/models/instructor_payment.dart';
import 'package:quickfit/features/instructor/payments/presentation/widgets/payment_status_chip.dart';

class PaymentHistoryListTile extends StatelessWidget {
  const PaymentHistoryListTile({
    super.key,
    required this.payment,
    required this.onTap,
  });

  final InstructorPayment payment;
  final VoidCallback onTap;

  String _formatCurrency(InstructorPayment value) {
    final amount = value.netAmountAgorot / 100;
    return '${value.currency} ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = payment.createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(payment.createdAt!)
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          payment.jobTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_formatCurrency(payment)),
            if (createdAt != null)
              Text(
                DateFormat('MMM d, yyyy • HH:mm').format(createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PaymentStatusChip(label: payment.paymentStatus),
                if (payment.payoutStatus != null && payment.payoutStatus!.isNotEmpty)
                  PaymentStatusChip(label: payment.payoutStatus!),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
