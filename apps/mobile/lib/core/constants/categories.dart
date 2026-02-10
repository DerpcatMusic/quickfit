// Fitness categories for Israeli market
// lib/core/constants/categories.dart

import 'package:flutter/material.dart';

enum FitnessCategory {
  yoga('yoga', 'Yoga', 'יוגה', '🧘', Color(0xFF9C27B0)),
  pilates('pilates', 'Pilates', 'פילאטיס', '🤸', Color(0xFFE91E63)),
  functional('functional', 'Functional', 'פונקציונלי', '💪', Color(0xFFFF5722)),
  spinning('spinning', 'Spinning', 'ספינינג', '🚴', Color(0xFF2196F3)),
  hiit('hiit', 'HIIT', 'אינטרוולים', '🔥', Color(0xFFF44336)),
  dance('dance', 'Dance', 'ריקוד', '💃', Color(0xFF00BCD4)),
  personalTraining('personal_training', 'Personal Training', 'אימון אישי', '🏋️', Color(0xFF4CAF50));

  const FitnessCategory(
      this.id, this.nameEn, this.nameHe, this.emoji, this.color);

  final String id;
  final String nameEn;
  final String nameHe;
  final String emoji;
  final Color color;

  String displayName(String locale) {
    return locale.startsWith('he') ? nameHe : nameEn;
  }

  String displayNameWithEmoji(String locale) {
    return '$emoji ${displayName(locale)}';
  }

  static FitnessCategory? fromId(String id) {
    try {
      return FitnessCategory.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<FitnessCategory> get all => FitnessCategory.values;
}

// Default hourly rates in ILS.
const Map<String, int> defaultRates = {
  'yoga': 120,
  'pilates': 150,
  'functional': 130,
  'spinning': 100,
  'hiit': 120,
  'dance': 110,
  'personal_training': 200,
};
