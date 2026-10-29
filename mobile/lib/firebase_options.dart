/// Configuration Firebase (console Firebase → Paramètres du projet → Vos applications).
/// Ce sont des identifiants publics de l'application, pas des secrets :
/// l'accès est protégé par les domaines autorisés et l'empreinte SHA de l'application Android.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const FirebaseOptions _web = FirebaseOptions(
  apiKey: 'AIzaSyAcpd4pD6Vjn0Uw__enH_-J_bmxbJS8BRA',
  authDomain: 'analyseur-etalonnage.firebaseapp.com',
  projectId: 'analyseur-etalonnage',
  storageBucket: 'analyseur-etalonnage.firebasestorage.app',
  messagingSenderId: '417632828391',
  appId: '1:417632828391:web:2187fa40759a64e75a5b42',
);

const FirebaseOptions _android = FirebaseOptions(
  apiKey: 'AIzaSyBigDMoCMmhro812Q13J0KEnW39MTEfxl4',
  projectId: 'analyseur-etalonnage',
  storageBucket: 'analyseur-etalonnage.firebasestorage.app',
  messagingSenderId: '417632828391',
  appId: '1:417632828391:android:56d55379c88c61895a5b42',
);

/// Options de la plateforme courante, ou null si elle n'est pas encore configurée.
FirebaseOptions? get firebaseOptions {
  final o = kIsWeb ? _web : (defaultTargetPlatform == TargetPlatform.android ? _android : null);
  return o != null && o.apiKey.isNotEmpty && o.appId.isNotEmpty ? o : null;
}
