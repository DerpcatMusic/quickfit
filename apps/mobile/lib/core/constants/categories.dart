// Fitness categories for Israeli market
// lib/core/constants/categories.dart

import 'package:flutter/material.dart';

enum FitnessCategory {
  yoga('yoga', 'Yoga', 'Yoga', '', Color(0xFF9C27B0)),
  pilates('pilates', 'Pilates', 'Pilates', '', Color(0xFFE91E63)),
  reformerPilates(
      'reformer_pilates', 'Reformer Pilates', 'Reformer Pilates', '', Color(0xFFEC4899)),
  matPilates('mat_pilates', 'Mat Pilates', 'Mat Pilates', '', Color(0xFFDB2777)),
  functional('functional', 'Functional Training', 'Functional Training', '', Color(0xFFFF5722)),
  hiit('hiit', 'HIIT', 'HIIT', '', Color(0xFFF44336)),
  strength('strength', 'Strength', 'Strength', '', Color(0xFF7C3AED)),
  mobility('mobility', 'Mobility', 'Mobility', '', Color(0xFF14B8A6)),
  barre('barre', 'Barre', 'Barre', '', Color(0xFFF59E0B)),
  spinning('spinning', 'Spinning', 'Spinning', '', Color(0xFF2196F3)),
  dance('dance', 'Dance', 'Dance', '', Color(0xFF00BCD4)),
  personalTraining(
      'personal_training', 'Personal Training', 'Personal Training', '', Color(0xFF4CAF50));

  const FitnessCategory(this.id, this.nameEn, this.nameHe, this.emoji, this.color);

  final String id;
  final String nameEn;
  final String nameHe;
  final String emoji;
  final Color color;

  String displayName(String locale) {
    return locale.startsWith('he') ? nameHe : nameEn;
  }

  String displayNameWithEmoji(String locale) {
    return displayName(locale);
  }

  static FitnessCategory? fromId(String id) {
    try {
      return FitnessCategory.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<FitnessCategory> get all => FitnessCategory.values;

  static FitnessCategory? inferFromFreeText(String rawInput) {
    final text = rawInput.trim().toLowerCase();
    if (text.isEmpty) return null;

    final rules = <FitnessCategory, List<String>>{
      FitnessCategory.reformerPilates: [
        'reformer',
        'cadillac',
        'tower pilates',
      ],
      FitnessCategory.matPilates: ['mat pilates', 'floor pilates', 'pilates mat'],
      FitnessCategory.pilates: ['pilates', 'core flow'],
      FitnessCategory.yoga: [
        'yoga',
        'vinyasa',
        'hatha',
        'yin',
        'ashtanga',
        'power yoga',
      ],
      FitnessCategory.barre: ['barre'],
      FitnessCategory.hiit: ['hiit', 'interval', 'tabata'],
      FitnessCategory.functional: ['functional', 'trx', 'cross training'],
      FitnessCategory.strength: ['strength', 'weights', 'resistance', 'barbell', 'dumbbell'],
      FitnessCategory.mobility: ['mobility', 'stretch', 'flexibility', 'recovery'],
      FitnessCategory.spinning: ['spinning', 'spin', 'indoor cycling', 'cycle'],
      FitnessCategory.dance: ['dance', 'zumba', 'hip hop', 'salsa', 'choreo'],
      FitnessCategory.personalTraining: ['personal training', 'pt session', '1 on 1'],
    };

    for (final entry in rules.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }
}

// Default hourly rates in ILS.
const Map<String, int> defaultRates = {
  'yoga': 120,
  'pilates': 150,
  'reformer_pilates': 170,
  'mat_pilates': 150,
  'functional': 130,
  'hiit': 120,
  'strength': 140,
  'mobility': 115,
  'barre': 145,
  'spinning': 100,
  'dance': 110,
  'personal_training': 200,
};
