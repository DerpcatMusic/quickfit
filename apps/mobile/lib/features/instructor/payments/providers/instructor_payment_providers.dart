import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickfit/core/services/convex_service.dart';
import 'package:quickfit/features/instructor/payments/models/instructor_payment.dart';

final instructorPaymentsProvider =
    FutureProvider.autoDispose<List<InstructorPayment>>((ref) async {
  final rows = await ConvexService.instance.listMyPayments(limit: 100);
  return rows
      .map(InstructorPayment.fromMap)
      .where((payment) => payment.id.isNotEmpty)
      .toList(growable: false);
});

final instructorPaymentDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, paymentId) async {
    return await ConvexService.instance.getMyPaymentDetail(paymentId);
  },
);
