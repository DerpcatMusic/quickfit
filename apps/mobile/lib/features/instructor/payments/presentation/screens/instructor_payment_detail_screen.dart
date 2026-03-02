import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quickfit/features/instructor/payments/presentation/widgets/payment_status_chip.dart';
import 'package:quickfit/features/instructor/payments/providers/instructor_payment_providers.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class InstructorPaymentDetailScreen extends ConsumerWidget {
  const InstructorPaymentDetailScreen({
    super.key,
    required this.paymentId,
  });

  final String paymentId;

  String _formatAgorot(dynamic amount, String currency) {
    final num safe = amount is num ? amount : 0;
    return '$currency ${(safe / 100).toStringAsFixed(2)}';
  }

  Future<void> _openInvoiceUrl(BuildContext context, String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice link is invalid')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open invoice link')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(instructorPaymentDetailProvider(paymentId));
    return Scaffold(
      appBar: adaptiveAppBar(context, title: 'Payment Details'),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load detail: $error')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Payment not found.'));
          }
          final payment = (detail['payment'] is Map)
              ? Map<String, dynamic>.from(detail['payment'] as Map)
              : <String, dynamic>{};
          final job = (detail['job'] is Map)
              ? Map<String, dynamic>.from(detail['job'] as Map)
              : <String, dynamic>{};
          final payout = (detail['payout'] is Map)
              ? Map<String, dynamic>.from(detail['payout'] as Map)
              : <String, dynamic>{};
          final invoice = (detail['invoice'] is Map)
              ? Map<String, dynamic>.from(detail['invoice'] as Map)
              : <String, dynamic>{};
          final timeline = (detail['timeline'] is List)
              ? List<Map<String, dynamic>>.from(
                  (detail['timeline'] as List).whereType<Map>().map(
                        (e) => Map<String, dynamic>.from(e),
                      ),
                )
              : <Map<String, dynamic>>[];

          final currency = payment['currency']?.toString() ?? 'ILS';
          final capturedAt = payment['capturedAt'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (payment['capturedAt'] as num).toInt(),
                )
              : null;
          final invoiceRef =
              (invoice['externalInvoiceUrl'] ?? invoice['externalInvoiceId'])
                  ?.toString()
                  .trim();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title']?.toString() ?? 'Job payment',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          PaymentStatusChip(
                            label: payment['status']?.toString() ?? 'pending',
                          ),
                          if (payout['status'] != null)
                            PaymentStatusChip(label: payout['status'].toString()),
                          if (invoice['status'] != null)
                            PaymentStatusChip(label: invoice['status'].toString()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Gross: ${_formatAgorot(payment['grossAmountAgorot'], currency)}'),
                      Text('Platform fee: ${_formatAgorot(payment['feeAmountAgorot'], currency)}'),
                      Text(
                        'You receive: ${_formatAgorot(payment['netAmountAgorot'], currency)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (capturedAt != null) ...[
                        const SizedBox(height: 8),
                        Text('Captured: ${DateFormat('MMM d, yyyy - HH:mm').format(capturedAt)}'),
                      ],
                      if (invoiceRef != null && invoiceRef.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _openInvoiceUrl(context, invoiceRef),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open invoice'),
                        ),
                        SelectableText(
                          'Invoice Ref: $invoiceRef',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (timeline.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No timeline events yet.'),
                  ),
                ),
              ...timeline.map((event) {
                final createdAt = event['createdAt'] is num
                    ? DateTime.fromMillisecondsSinceEpoch(
                        (event['createdAt'] as num).toInt(),
                      )
                    : null;
                return Card(
                  child: ListTile(
                    title: Text(event['title']?.toString() ?? 'Event'),
                    subtitle: Text(
                      '${event['description']?.toString() ?? ''}'
                      '${createdAt != null ? '\n${DateFormat('MMM d, HH:mm').format(createdAt)}' : ''}',
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
