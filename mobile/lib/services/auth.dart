/// Connexion de l'utilisateur (compte Google ou email + mot de passe).
/// Les données d'étalonnage restent sur l'appareil : la connexion ne fait
/// qu'ouvrir l'accès à l'application.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthUser {
  const AuthUser(this.email, this.name);
  final String email, name;
}

/// Erreur de connexion : [code] est une clé de traduction « auth.* ».
class AuthError implements Exception {
  const AuthError(this.code);
  final String code;
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        'invalid-email' => 'auth.invalidEmail',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'auth.badCredentials',
        'email-already-in-use' => 'auth.emailInUse',
        'weak-password' || 'password-does-not-meet-requirements' => 'auth.weakPassword',
        'too-many-requests' => 'auth.tooMany',
        'network-request-failed' => 'auth.network',
        'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => 'auth.cancelled',
        'popup-blocked' => 'auth.popupBlocked',
        _ => 'auth.failed',
      });
    }
  }

  @override
  Future<void> signInWithGoogle() => _run(() async {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
        } else {
          await _auth.signInWithProvider(provider);
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
  Future<void> signOut() => _auth.signOut();
}
