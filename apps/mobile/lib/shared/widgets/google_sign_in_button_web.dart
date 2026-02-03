import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Returns the native Google Sign-In button for web platform.
Widget getGoogleSignInButton() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: web.renderButton(),
  );
}
