class InstructorPayment {
  InstructorPayment({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.currency,
    required this.grossAmountAgorot,
    required this.feeAmountAgorot,
    required this.netAmountAgorot,
    required this.paymentStatus,
    this.payoutStatus,
    this.invoiceStatus,
    this.invoiceUrl,
    this.createdAt,
    this.capturedAt,
    this.settledAt,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final String currency;
  final int grossAmountAgorot;
  final int feeAmountAgorot;
  final int netAmountAgorot;
  final String paymentStatus;
  final String? payoutStatus;
  final String? invoiceStatus;
  final String? invoiceUrl;
  final int? createdAt;
  final int? capturedAt;
  final int? settledAt;

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _toStringSafe(dynamic value, {String fallback = ''}) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return fallback;
    return raw;
  }

  factory InstructorPayment.fromMap(Map<String, dynamic> json) {
    final job = (json['job'] is Map)
        ? Map<String, dynamic>.from(json['job'] as Map)
        : <String, dynamic>{};
    final payout = (json['payout'] is Map)
        ? Map<String, dynamic>.from(json['payout'] as Map)
        : <String, dynamic>{};
    final invoice = (json['invoice'] is Map)
        ? Map<String, dynamic>.from(json['invoice'] as Map)
        : <String, dynamic>{};

    return InstructorPayment(
      id: _toStringSafe(json['_id']),
      jobId: _toStringSafe(json['jobId']),
      jobTitle: _toStringSafe(job['title'], fallback: 'Job payment'),
      currency: _toStringSafe(json['currency'], fallback: 'ILS'),
      grossAmountAgorot: _toInt(json['grossAmountAgorot']),
      feeAmountAgorot: _toInt(json['feeAmountAgorot']),
      netAmountAgorot: _toInt(json['netAmountAgorot']),
      paymentStatus: _toStringSafe(json['status'], fallback: 'pending'),
      payoutStatus: _toStringSafe(payout['status']),
      invoiceStatus: _toStringSafe(invoice['status']),
      invoiceUrl: _toStringSafe(invoice['externalInvoiceUrl']),
      createdAt: json['createdAt'] is num ? (json['createdAt'] as num).toInt() : null,
      capturedAt: json['capturedAt'] is num ? (json['capturedAt'] as num).toInt() : null,
      settledAt: payout['settledAt'] is num ? (payout['settledAt'] as num).toInt() : null,
    );
  }
}
