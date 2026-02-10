import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool isCupertinoPlatform(BuildContext context) {
  if (kIsWeb) return false;
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

