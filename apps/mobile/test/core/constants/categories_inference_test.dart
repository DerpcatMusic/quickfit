import 'package:flutter_test/flutter_test.dart';
import 'package:quickfit/core/constants/categories.dart';

void main() {
  group('FitnessCategory.inferFromFreeText', () {
    test('detects English lesson descriptors', () {
      expect(
        FitnessCategory.inferFromFreeText('Morning Vinyasa flow'),
        FitnessCategory.yoga,
      );
      expect(
        FitnessCategory.inferFromFreeText('Reformer Pilates for core'),
        FitnessCategory.reformerPilates,
      );
      expect(
        FitnessCategory.inferFromFreeText('1:1 PT strength session'),
        FitnessCategory.personalTraining,
      );
    });

    test('detects Hebrew descriptors', () {
      expect(
        FitnessCategory.inferFromFreeText('שיעור יוגה בבוקר'),
        FitnessCategory.yoga,
      );
      expect(
        FitnessCategory.inferFromFreeText('פילאטיס רפורמר למתחילים'),
        FitnessCategory.reformerPilates,
      );
      expect(
        FitnessCategory.inferFromFreeText('אימון פונקציונלי עם trx'),
        FitnessCategory.functional,
      );
    });

    test('prefers more specific keyword matches', () {
      expect(
        FitnessCategory.inferFromFreeText('Pilates Reformer advanced'),
        FitnessCategory.reformerPilates,
      );
      expect(
        FitnessCategory.inferFromFreeText('Mat Pilates fundamentals'),
        FitnessCategory.matPilates,
      );
    });

    test('returns null when no category signal exists', () {
      expect(
        FitnessCategory.inferFromFreeText('Studio meeting and scheduling'),
        isNull,
      );
    });
  });
}
