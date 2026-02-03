/// Job model for QuickFit.
///
/// Represents a substitute teaching job posted by a studio.
library;

import 'package:flutter/foundation.dart';

/// A job posting from a studio looking for a substitute instructor.
@immutable
class Job {
  const Job({
    required this.id,
    required this.studioId,
    required this.studioName,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.rateIls,
    required this.boostedRateIls,
    required this.lat,
    required this.lng,
    required this.status,
    required this.isSos,
    required this.distanceKm,
    required this.createdAt,
    this.notes,
  });

  /// Unique job ID from Convex.
  final String id;

  /// ID of the studio that posted this job.
  final String studioId;

  /// Display name of the studio.
  final String studioName;

  /// Fitness category ID (e.g., 'yoga', 'pilates').
  final String category;

  /// When the class starts.
  final DateTime startTime;

  /// When the class ends.
  final DateTime endTime;

  /// Base pay rate in ILS (₪).
  final int rateIls;

  /// Current rate including any SOS boost.
  final int boostedRateIls;

  /// Optional notes from the studio.
  final String? notes;

  /// Studio latitude.
  final double lat;

  /// Studio longitude.
  final double lng;

  /// Job status: 'open', 'claimed', 'confirmed', 'completed', 'cancelled', 'expired'.
  final String status;

  /// Whether this is an urgent/SOS job (< 3 hours until start).
  final bool isSos;

  /// Distance from instructor's location in km.
  final double distanceKm;

  /// When the job was created.
  final DateTime createdAt;

  /// Parses a Job from Convex JSON.
  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['_id'] as String,
      studioId: json['studioId'] as String,
      studioName: json['studioName'] as String? ?? 'Unknown Studio',
      category: json['category'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
      rateIls: json['rateIls'] as int,
      boostedRateIls: json['boostedRateIls'] as int? ?? json['rateIls'] as int,
      notes: json['notes'] as String?,
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      isSos: json['isSos'] as bool? ?? false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['_creationTime'] as int),
    );
  }

  /// Whether the job has already started.
  bool get isExpired => startTime.isBefore(DateTime.now());

  /// Time remaining until the job starts.
  Duration get timeUntilStart => startTime.difference(DateTime.now());

  /// Formatted rate with currency symbol.
  String get formattedRate => '₪$boostedRateIls';

  /// Formatted distance (meters if < 1km, km otherwise).
  String get formattedDistance => distanceKm < 1
      ? '${(distanceKm * 1000).round()}m'
      : '${distanceKm.toStringAsFixed(1)}km';

  /// Whether the rate was boosted from the base.
  bool get isBoosted => boostedRateIls > rateIls;

  /// Duration of the class in minutes.
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Job && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
