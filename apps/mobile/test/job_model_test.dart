import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/data/models/job.dart';

void main() {
  test('Job.fromJson parses core fields and description fallback', () {
    final json = <String, dynamic>{
      '_id': 'job_1',
      'studioId': 'studio_1',
      'studioName': 'Studio A',
      'title': 'Pilates Class',
      'category': 'pilates',
      'startTime': 1700000000000,
      'endTime': 1700000360000,
      'baseRate': 180,
      'currentRate': 200,
      'latitude': 32.0853,
      'longitude': 34.7818,
      'address': 'Tel Aviv',
      'status': 'open',
      'sosBoostApplied': true,
      'distanceKm': 2.5,
      'description': 'Bring a mat',
      '_creationTime': 1700000000000,
    };

    final job = Job.fromJson(json);

    expect(job.id, 'job_1');
    expect(job.studioName, 'Studio A');
    expect(job.isSos, true);
    expect(job.notes, 'Bring a mat');
    expect(job.formattedDistance, '2.5km');
    expect(job.formattedRate.endsWith('200'), true);
  });
}
