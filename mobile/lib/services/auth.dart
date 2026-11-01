/// Connexion de l'utilisateur (compte Google ou email + mot de passe).
/// Les données d'étalonnage restent sur l'appareil : la connexion ne fait
/// qu'ouvrir l'accès à l'application.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser(this.email, this.name);
  final String email, name;
}

/// Erreur de connexion : [code] est une clé de traduction « auth.* ».
class AuthError implements Exception {
  const AuthError(this.code, [this.detail = '']);
  final String code;

  /// Code technique affiché avec l'échec générique, pour pouvoir diagnostiquer.
  final String detail;
}

abstract class AuthService {
  Stream<AuthUser?> get userChanges;
  AuthUser? get current;
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  static const _webClientId = '417632828391-o4hjpl6pj4rsann9vk8u3cekkt0f0sit.apps.googleusercontent.com';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleReady = false;

  static AuthUser? _user(User? u) => u == null ? null : AuthUser(u.email ?? '', u.displayName ?? '');

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_user);

  @override
  AuthUser? get current => _user(_auth.currentUser);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthError(switch (e.code) {
        'missing-password' => 'auth.missingPassword',
        'invalid-email' => 'auth.invalidEmail',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'auth.badCredentials',
        'email-already-in-use' => 'auth.emailInUse',
        'weak-password' || 'password-does-not-meet-requirements' => 'auth.weakPassword',
        'too-many-requests' => 'auth.tooMany',
        'network-request-failed' => 'auth.network',
        'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => 'auth.cancelled',
        'popup-blocked' => 'auth.popupBlocked',
        _ => 'auth.failed',
      }, e.code);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const AuthError('auth.cancelled');
      throw AuthError('auth.failed', 'google:${e.code.name}');
    }
  }

  @override
  Future<void> signInWithGoogle() => _run(() async {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
        } else {
          // Dialogue natif : la clé Android reste limitée à l'application signée.
          final g = GoogleSignIn.instance;
          if (!_googleReady) {
            await g.initialize(clientId: _auth.app.options.iosClientId, serverClientId: _webClientId);
            _googleReady = true;
          }
          final account = await g.authenticate();
          await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: account.authentication.idToken));
        }
      });

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> register(String email, String password) =>
      _run(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> resetPassword(String email) => _run(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
