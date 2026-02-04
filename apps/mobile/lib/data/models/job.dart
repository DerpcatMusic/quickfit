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
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.baseRate,
    required this.currentRate,
    required this.latitude,
    required this.longitude,
    required this.address,
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

  /// Job title/title of the class.
  final String title;

  /// Fitness category ID (e.g., 'yoga', 'pilates').
  final String category;

  /// When the class starts.
  final DateTime startTime;

  /// When the class ends.
  final DateTime endTime;

  /// Base pay rate in ILS (₪).
  final double baseRate;

  /// Current rate including any SOS boost.
  final double currentRate;

  /// Optional notes from the studio.
  final String? notes;

  /// Studio latitude.
  final double latitude;

  /// Studio longitude.
  final double longitude;

  /// Studio address.
  final String address;

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
      title: json['title'] as String? ?? 'Untitled Class',
      category: json['category'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int),
      baseRate: (json['baseRate'] as num).toDouble(),
      currentRate:
          (json['currentRate'] as num? ?? json['baseRate'] as num).toDouble(),
      notes: json['notes'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String? ?? 'No address',
      status: json['status'] as String,
      isSos: json['sosBoostApplied'] as bool? ?? false,
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
  String get formattedRate => '₪${currentRate.round()}';

  /// Formatted distance (meters if < 1km, km otherwise).
  String get formattedDistance => distanceKm < 1
      ? '${(distanceKm * 1000).round()}m'
      : '${distanceKm.toStringAsFixed(1)}km';

  /// Whether the rate was boosted from the base.
  bool get isBoosted => currentRate > baseRate;

  /// Duration of the class in minutes.
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Job && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
