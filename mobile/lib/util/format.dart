/// Affichage des nombres — RÈGLES COMMUNES au site et à l'application
/// (miroir exact de formatNombre / afficherResultat dans webapp/core.js,
/// vérifié par test/parity_test.dart sur les mêmes cas que webapp/tests.js).
///
/// - 10 chiffres significatifs par défaut (le calcul interne reste en double) ;
/// - notation scientifique hors de [1e-5 ; 1e9[ : jamais de faux zéro ;
/// - pas de séparateur de milliers ; virgule décimale en français.
library;

import 'dart:math' as math;

import '../core/engine.dart';

/// Chiffres significatifs affichés pour R² (identique sur le site).
const int r2Digits = 6;

String fmtNum(double v, String lang, [int digits = 10]) {
  if (!v.isFinite) return '—';
  if (v == 0) return '0';
  final abs = v.abs();
  String s;
  if (abs >= 1e9 || abs < 1e-5) {
    s = v.toStringAsExponential(math.max(2, math.min(digits, 10) - 1)).replaceFirst(RegExp(r'\.?0+e'), 'e');
  } else {
    // Arrondi à `digits` chiffres significatifs, puis écriture décimale la plus courte.
    s = double.parse(v.toStringAsPrecision(digits)).toString();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  }
  return lang == 'fr' ? s.replaceFirst('.', ',') : s;
}

/// « + 0,1 » / « − 0,1 » pour écrire une équation y = a·I ± b.
String fmtSigned(double v, String lang) => v < 0 ? '− ${fmtNum(-v, lang)}' : '+ ${fmtNum(v, lang)}';

String equation(String sym, double a, double b, String lang) => '$sym = ${fmtNum(a, lang)} · I ${fmtSigned(b, lang)}';

/// Valeur saisie en texte, au format de la langue (virgule en français).
String rawNum(double v, String lang) {
  final s = v.toString().replaceFirst(RegExp(r'\.0$'), '');
  return lang == 'fr' ? s.replaceAll('.', ',') : s;
}

/// Affichage métrologique d'un résultat du calculateur :
/// U(I) à 2 chiffres significatifs arrondie VERS LE HAUT ; C et I + C avec le
/// même nombre de décimales que U(I).
class Affichage {
  const Affichage(this.c, this.corrected, this.u);
  final String c, corrected, u;
}

String _fixed(double v, int d, String lang) {
  var s = v.toStringAsFixed(d);
  if (double.parse(s) == 0) s = (0.0).toStringAsFixed(d); // jamais « -0,000 »
  return lang == 'fr' ? s.replaceFirst('.', ',') : s;
}

Affichage afficherResultat(CalcResult r, String lang) {
  final ru = arrondirIncertitude(r.uFit);
  final dec = ru.decimals;
  final c = _fixed(r.c, dec, lang);
  return Affichage(
    double.parse(c.replaceFirst(',', '.')) > 0 ? '+$c' : c,
    _fixed(r.corrected, dec, lang),
    _fixed(ru.value, ru.decimals, lang),
  );
}
