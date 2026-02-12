import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart' as auth_gsi;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_service.g.dart';

/// Service responsible for handle low-level authentication interactions.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
}

class AuthService {
  firebase_auth.FirebaseAuth get _auth => firebase_auth.FirebaseAuth.instance;

  // 2026: google_sign_in 7.x uses a singleton pattern.
  final auth_gsi.GoogleSignIn _googleSignIn = auth_gsi.GoogleSignIn.instance;
  StreamSubscription<auth_gsi.GoogleSignInAuthenticationEvent>? _googleUserSub;

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();
  firebase_auth.User? get currentUser => _auth.currentUser;

  bool _isSupportedAuthActionMode(String mode) {
    return mode == 'verifyEmail' ||
        mode == 'verifyAndChangeEmail' ||
        mode == 'recoverEmail';
  }

  Future<void> initialize() async {
    try {
      await _googleSignIn.initialize();
      if (kIsWeb) {
        _googleUserSub ??= _googleSignIn.authenticationEvents.listen(
          (event) async {
            if (event is auth_gsi.GoogleSignInAuthenticationEventSignIn) {
              try {
                await _processGoogleAccount(event.user);
              } catch (e) {
                developer.log('Google web sign-in bridge failed',
                    name: 'auth_service', error: e);
              }
            }
          },
          onError: (error) {
            developer.log('Google auth event error',
                name: 'auth_service', error: error);
          },
        );
        // Restore previous web session if available.
        _googleSignIn.attemptLightweightAuthentication();
      }
    } catch (e) {
      // Ignore errors if already initialized or not needed
    }
  }

  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
    try {
      // 2026: initialize() before authenticate()
      await _googleSignIn.initialize();
      final googleUser = await _googleSignIn.authenticate();
      return await _processGoogleAccount(googleUser);
    } catch (e) {
      if (_isUserCancelledGoogleSignIn(e)) {
        developer.log(
          'Google Sign-In canceled by user',
          name: 'auth_service',
        );
        return null;
      }
      developer.log('Google Sign-In Error', name: 'auth_service', error: e);
      rethrow;
    }
  }

  bool _isUserCancelledGoogleSignIn(Object error) {
    if (error is auth_gsi.GoogleSignInException) {
      return error.code == auth_gsi.GoogleSignInExceptionCode.canceled;
    }
    final message = error.toString().toLowerCase();
    return message.contains('googlesigninexceptioncode.canceled') ||
        message.contains('sign in canceled') ||
        message.contains('signin canceled');
  }

  Future<firebase_auth.UserCredential> _processGoogleAccount(
    auth_gsi.GoogleSignInAccount googleAccount,
  ) async {
    // Authentication (ID Token)
    final googleAuth = googleAccount.authentication;

    if (googleAuth.idToken == null) {
      throw StateError(
        'Google Sign-In did not return an ID token. '
        'Check your web client ID and OAuth consent screen configuration.',
      );
    }

    // Authorization (Access Token) - separated in v7.x
    final authorization =
        await googleAccount.authorizationClient.authorizeScopes([
      'openid',
      'email',
      'profile',
    ]);

    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<firebase_auth.UserCredential> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthProvider = firebase_auth.OAuthProvider('apple.com');
      final credential = oauthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  Future<firebase_auth.UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<firebase_auth.UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (displayName != null && credential.user != null) {
      await credential.user!.updateDisplayName(displayName);
      await credential.user!.reload();
    }

    return credential;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore
    }
    await _auth.signOut();
  }

  void dispose() {
    _googleUserSub?.cancel();
    _googleUserSub = null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<firebase_auth.UserCredential> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    return await user.linkWithCredential(credential);
  }

  Future<void> requestEmailChangeVerification({
    required String newEmail,
    String? currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final trimmedEmail = newEmail.trim();
    if (trimmedEmail.isEmpty) {
      throw firebase_auth.FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email cannot be empty.',
      );
    }

    final linkedProviders =
        user.providerData.map((p) => p.providerId).whereType<String>().toSet();

    if (linkedProviders.contains('password') &&
        currentPassword != null &&
        currentPassword.trim().isNotEmpty) {
      final currentEmail = user.email;
      if (currentEmail == null || currentEmail.trim().isEmpty) {
        throw Exception('Current email is unavailable.');
      }
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: currentEmail.trim(),
        password: currentPassword.trim(),
      );
      await user.reauthenticateWithCredential(credential);
    } else if (linkedProviders.contains('google.com')) {
      await _googleSignIn.initialize();
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final authorization =
          await googleUser.authorizationClient.authorizeScopes([
        'openid',
        'email',
        'profile',
      ]);
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }

    await user.verifyBeforeUpdateEmail(trimmedEmail);
  }

  Future<bool> applyAuthActionFromUri(Uri uri) async {
    final mode = uri.queryParameters['mode']?.trim() ?? '';
    final oobCode = uri.queryParameters['oobCode']?.trim() ?? '';
    if (mode.isEmpty || oobCode.isEmpty) {
      return false;
    }
    if (!_isSupportedAuthActionMode(mode)) {
      return false;
    }

    await _auth.applyActionCode(oobCode);

    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      await user.getIdToken(true);
    }
    return true;
  }
}
