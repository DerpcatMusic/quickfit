import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/features/instructor/payments/providers/instructor_payment_providers.dart';
import 'package:quickfit/features/instructor/payments/presentation/widgets/payment_history_list_tile.dart';
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';

class InstructorPaymentHistoryScreen extends ConsumerWidget {
  const InstructorPaymentHistoryScreen({super.key});

  Future<void> _showPreflight(BuildContext context) async {
    final preflight = await ConvexService.instance.getPaymentsPreflight();
    if (!context.mounted) return;
    if (preflight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments preflight unavailable')),
      );
      return;
    }
    final ready = preflight['ready'] == true;
    final missing = (preflight['missingRequired'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ready
              ? 'Payments preflight: READY'
              : 'Payments preflight missing: ${missing.join(', ')}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(instructorPaymentsProvider);
    return Scaffold(
      appBar: adaptiveAppBar(
        context,
        title: 'My Payments',
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Payout destinations',
            onPressed: () => context.push('/instructor/payout-destinations'),
          ),
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Payments preflight',
            onPressed: () => _showPreflight(context),
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load payments: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(instructorPaymentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No payments yet. Completed jobs will appear here.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(instructorPaymentsProvider);
              await ref.read(instructorPaymentsProvider.future);
            },
            child: ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return PaymentHistoryListTile(
                  payment: payment,
                  onTap: () => context.push('/instructor/payments/${payment.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
