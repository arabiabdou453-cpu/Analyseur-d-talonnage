/// Affichage des nombres — mêmes règles que la version web : 10 chiffres
/// significatifs par défaut (le calcul interne reste en double), notation
/// scientifique pour les très petites valeurs (jamais de faux zéro), virgule
/// décimale en français.
library;

import 'dart:math' as math;

String fmtNum(double v, String lang, [int digits = 10]) {
  if (!v.isFinite) return '—';
  if (v == 0) return '0';
  final abs = v.abs();
  String s;
  if (abs >= 1e9 || abs < 1e-5) {
    s = v.toStringAsExponential(math.max(2, math.min(digits, 10) - 1));
    s = s.replaceFirstMapped(RegExp(r'\.?0+e'), (_) => 'e');
  } else {
    s = v.toStringAsPrecision(digits);
    if (s.contains('e')) {
      s = v.toString();
    } else if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
  }
  return lang == 'fr' ? s.replaceAll('.', ',') : s;
}

/// « + 0,1 » / « − 0,1 » pour écrire une équation y = a·I ± b.
String fmtSigned(double v, String lang) => v < 0 ? '− ${fmtNum(-v, lang)}' : '+ ${fmtNum(v, lang)}';

String equation(String sym, double a, double b, String lang) => '$sym = ${fmtNum(a, lang)} · I ${fmtSigned(b, lang)}';

/// Valeur saisie en texte, au format de la langue (virgule en français).
String rawNum(double v, String lang) {
  final s = v.toString().replaceFirst(RegExp(r'\.0$'), '');
  return lang == 'fr' ? s.replaceAll('.', ',') : s;
}
