library;

import 'package:flutter/foundation.dart';

@immutable
class ScheduleEvent {
  const ScheduleEvent({
    required this.claimId,
    required this.jobId,
    required this.title,
    required this.studioName,
    required this.startTime,
    required this.endTime,
    required this.claimStatus,
    required this.jobStatus,
    required this.address,
    required this.currentRate,
    this.category,
  });

  final String claimId;
  final String jobId;
  final String title;
  final String studioName;
  final DateTime startTime;
  final DateTime endTime;
  final String claimStatus;
  final String jobStatus;
  final String address;
  final double currentRate;
  final String? category;

  int get durationMinutes {
    final minutes = endTime.difference(startTime).inMinutes;
    if (minutes <= 0) return 0;
    return minutes;
  }

  double get durationHours => durationMinutes / 60.0;

  bool get isPendingClaim => claimStatus == 'pending';

  bool get isAcceptedClaim => claimStatus == 'accepted';

  bool get isCancelledLike =>
      jobStatus == 'cancelled' || jobStatus == 'expired';

  bool get countsTowardBookedHours => isAcceptedClaim && !isCancelledLike;

  DateTime get day => DateTime(startTime.year, startTime.month, startTime.day);

  factory ScheduleEvent.fromClaimJson(Map<String, dynamic> json) {
    final claimId = json['_id']?.toString();
    final claimStatus = json['status']?.toString() ?? 'unknown';

    final rawJob = json['job'];
    if (rawJob is! Map) {
      throw const FormatException('Claim payload missing job object');
    }
    final job = Map<String, dynamic>.from(rawJob);

    final jobId = job['_id']?.toString();
    final startTimeMs = job['startTime'] as num?;
    final endTimeMs = job['endTime'] as num?;

    if (claimId == null ||
        claimId.isEmpty ||
        jobId == null ||
        jobId.isEmpty ||
        startTimeMs == null ||
        endTimeMs == null) {
      throw const FormatException('Claim/job payload missing required fields');
    }

    return ScheduleEvent(
      claimId: claimId,
      jobId: jobId,
      title: (job['title'] as String?)?.trim().isNotEmpty == true
          ? (job['title'] as String).trim()
          : 'Class',
      studioName: (job['studioName'] as String?)?.trim().isNotEmpty == true
          ? (job['studioName'] as String).trim()
          : 'Studio',
      startTime: DateTime.fromMillisecondsSinceEpoch(startTimeMs.toInt()),
      endTime: DateTime.fromMillisecondsSinceEpoch(endTimeMs.toInt()),
      claimStatus: claimStatus,
      jobStatus: job['status']?.toString() ?? 'unknown',
      address: (job['address'] as String?)?.trim() ?? '',
      currentRate: (job['currentRate'] as num? ?? job['baseRate'] as num? ?? 0)
          .toDouble(),
      category: job['category'] as String?,
    );
  }

  factory ScheduleEvent.fromCacheJson(Map<String, dynamic> json) {
    final claimId = json['claimId']?.toString() ?? '';
    final jobId = json['jobId']?.toString() ?? '';
    final startMs = json['startTime'] as num?;
    final endMs = json['endTime'] as num?;

    if (claimId.isEmpty || jobId.isEmpty || startMs == null || endMs == null) {
      throw const FormatException('Invalid cached schedule event');
    }

    return ScheduleEvent(
      claimId: claimId,
      jobId: jobId,
      title: json['title']?.toString() ?? 'Class',
      studioName: json['studioName']?.toString() ?? 'Studio',
      startTime: DateTime.fromMillisecondsSinceEpoch(startMs.toInt()),
      endTime: DateTime.fromMillisecondsSinceEpoch(endMs.toInt()),
      claimStatus: json['claimStatus']?.toString() ?? 'unknown',
      jobStatus: json['jobStatus']?.toString() ?? 'unknown',
      address: json['address']?.toString() ?? '',
      currentRate: (json['currentRate'] as num?)?.toDouble() ?? 0,
      category: json['category']?.toString(),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'claimId': claimId,
      'jobId': jobId,
      'title': title,
      'studioName': studioName,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'claimStatus': claimStatus,
      'jobStatus': jobStatus,
      'address': address,
      'currentRate': currentRate,
      'category': category,
    };
  }
}
