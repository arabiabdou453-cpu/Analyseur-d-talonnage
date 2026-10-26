/// Moteur de calcul de l'application mobile — miroir de webapp/core.js et de
/// core/*.m (MATLAB). Fonctions pures, sans interface : les erreurs portent un
/// code ([CoreError.code]) traduit par l'interface. Testé par
/// test/engine_test.dart avec les valeurs de référence de tests/TestRegression.m.
library;

import 'dart:math' as math;

/// options.toleranceRelative (parametresParDefaut.m).
const double tol = 1e-10;

/// Number.EPSILON / eps(1) : écart entre 1 et le double suivant.
const double _eps = 2.220446049250313e-16;

class CoreError implements Exception {
  const CoreError(this.code, [this.params = const {}]);
  final String code;
  final Map<String, Object> params;

  @override
  String toString() => 'CoreError($code, $params)';
}

final RegExp _numRe = RegExp(r'^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$');

/// normaliserDonnees : virgule décimale, espaces (y compris insécables), moins
/// Unicode, ± (incertitude seulement). Renvoie NaN pour toute saisie invalide.
double parseNum(String? raw, {bool allowPlusMinus = false}) {
  var s = (raw ?? '')
      .trim()
      .replaceAll(RegExp('[  ]'), ' ')
      .replaceAll(RegExp('[−–]'), '-');
  if (allowPlusMinus && s.startsWith('±')) s = s.substring(1).trim();
  s = s.replaceAll(' ', '');
  if (s.contains(',') && !s.contains('.')) s = s.replaceFirst(',', '.');
  if (s.isEmpty || !_numRe.hasMatch(s)) return double.nan;
  // Formes acceptées par la regex mais pas par double.parse : « 5. », « .5 », « -.5 ».
  var t = s;
  final mantisse = t.split(RegExp('[eE]'));
  if (mantisse.first.endsWith('.')) {
    t = '${mantisse.first}0${mantisse.length > 1 ? 'e${mantisse[1]}' : ''}';
  }
  t = t.replaceFirstMapped(RegExp(r'^([-+]?)\.'), (m) => '${m[1]}0.');
  return double.tryParse(t) ?? double.nan;
}

class Point {
  const Point(this.x, this.c, this.u, [double? uRaw]) : uRaw = uRaw ?? u;
  final double x; // indication
  final double c; // correction
  final double u; // incertitude absolue (utilisée pour la régression)

  /// Valeur saisie d'origine (en % de la lecture si l'incertitude est relative).
  final double uRaw;
}

class LinearFit {
  const LinearFit({
    required this.a,
    required this.b,
    required this.x,
    required this.mesure,
    required this.ajuste,
    required this.residu,
    required this.residuMax,
    required this.sse,
    required this.sst,
    required this.r2,
    required this.sRes,
    required this.n,
    required this.constant,
  });
  final double a, b, residuMax, sse, sst, r2, sRes;
  final List<double> x, mesure, ajuste, residu;
  final int n;
  final bool constant;

  double at(double v) => a * v + b;
}

double _sum(Iterable<double> v) => v.fold(0.0, (s, e) => s + e);

/// ajusterDroite : moindres carrés ordinaires, formulation centrée y = a·x + b
/// (pas d'inversion de matrice).
LinearFit ajusterDroite(List<double> x, List<double> y) {
  final n = x.length;
  if (n < 3 || n != y.length || ![...x, ...y].every((v) => v.isFinite)) {
    throw const CoreError('fitInput');
  }
  final xc = _sum(x) / n, yc = _sum(y) / n;
  final dx = [for (final v in x) v - xc], dy = [for (final v in y) v - yc];
  final sxx = _sum(dx.map((v) => v * v));
  final scale = math.max(x.map((v) => v.abs()).reduce(math.max), 1.0);
  if (sxx <= math.pow(_eps * scale, 2) * n) throw const CoreError('range');
  var sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += dx[i] * dy[i];
  }
  final a = sxy / sxx, b = yc - a * xc;
  final ajuste = [for (final v in x) a * v + b];
  final residu = [for (var i = 0; i < n; i++) y[i] - ajuste[i]];
  final sse = _sum(residu.map((r) => r * r)), sst = _sum(dy.map((v) => v * v));
  final constant = sst <= tol * math.max(1.0, _sum(y.map((v) => v * v)));
  return LinearFit(
    a: a,
    b: b,
    x: List.unmodifiable(x),
    mesure: List.unmodifiable(y),
    ajuste: ajuste,
    residu: residu,
    residuMax: residu.map((r) => r.abs()).reduce(math.max),
    sse: sse,
    sst: sst,
    r2: constant ? double.nan : 1 - sse / sst,
    sRes: math.sqrt(sse / (n - 2)),
    n: n,
    constant: constant,
  );
}

class Decision {
  const Decision(this.ok, this.seuil, this.tolerance, this.r2Key);
  final bool ok;
  final double seuil, tolerance;

  /// 'r2.ok', 'r2.low' (remarque informative) ou 'r2.undef' (données constantes).
  final String r2Key;
}

/// evaluerCritere : e_max <= seuil avec tolérance numérique documentée.
Decision evaluerCritere(LinearFit model, double seuil) {
  if (!seuil.isFinite || seuil < 0) throw const CoreError('threshold');
  final t = tol * [1.0, seuil.abs(), model.residuMax].reduce(math.max);
  var r2 = 'r2.ok';
  if (model.constant) {
    r2 = 'r2.undef';
  } else if (model.r2 < 0.5) {
    r2 = 'r2.low';
  }
  return Decision(model.residuMax <= seuil + t, seuil, t, r2);
}

enum ThresholdMode { fraction, absolute }

/// Incertitude du certificat : absolue, ou relative (% de la lecture).
enum UncType { absolute, relative }

class Settings {
  const Settings({
    this.mode = ThresholdMode.fraction,
    this.alphaC = '0.25',
    this.alphaU = '0.25',
    this.limitC = '0',
    this.limitU = '0',
    this.uncType = UncType.absolute,
  });
  final ThresholdMode mode;
  final String alphaC, alphaU, limitC, limitU;
  final UncType uncType;
}

class Meta {
  const Meta({
    this.instrument = '',
    this.identifier = '',
    this.certificate = '',
    this.date = '',
    this.lab = '',
    this.unitI = '',
    this.unitC = '',
    this.unitU = '',
    this.nature = '',
    this.k = '',
    this.validUntil = '',
  });
  final String instrument, identifier, certificate, date, lab;

  /// Date de validité du certificat (AAAA-MM-JJ), facultative.
  final String validUntil;
  final String unitI, unitC, unitU;

  /// '' (inconnue), 'U' (élargie) ou 'u' (type).
  final String nature;

  /// Facteur k tel qu'imprimé ; jamais supposé.
  final String k;

  Meta copyWith({
    String? instrument,
    String? identifier,
    String? certificate,
    String? date,
    String? lab,
    String? unitI,
    String? unitC,
    String? unitU,
    String? nature,
    String? k,
    String? validUntil,
  }) =>
      Meta(
        validUntil: validUntil ?? this.validUntil,
        instrument: instrument ?? this.instrument,
        identifier: identifier ?? this.identifier,
        certificate: certificate ?? this.certificate,
        date: date ?? this.date,
        lab: lab ?? this.lab,
        unitI: unitI ?? this.unitI,
        unitC: unitC ?? this.unitC,
        unitU: unitU ?? this.unitU,
        nature: nature ?? this.nature,
        k: k ?? this.k,
      );
}

class Issue {
  const Issue(this.code, [this.params = const {}, this.cell]);
  final String code;
  final Map<String, Object> params;

  /// (ligne, colonne) de la cellule fautive, si applicable.
  final (int, int)? cell;
}

class Validation {
  const Validation(this.errors, this.warnings, this.pts, this.sC, this.sU, this.needsSort);
  final List<Issue> errors;
  final List<String> warnings;
  final List<Point> pts;
  final double sC, sU;
  final bool needsSort;
}

bool _ok(double v) => v.isFinite && v >= 0;

/// validerDonnees : rows = [[I, C, U] en texte].
/// Incertitude relative (% de la lecture) : U_abs = U% × |I| / 100, calculée
/// avant la régression ; la valeur d'origine est conservée dans [Point.uRaw].
Validation valider(List<List<String>> rows, Settings settings, [Meta meta = const Meta()]) {
  final errors = <Issue>[], warnings = <String>[];
  final pts = <Point>[];
  final relative = settings.uncType == UncType.relative;
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final v = [for (var j = 0; j < 3; j++) parseNum(j < r.length ? r[j] : '', allowPlusMinus: j == 2)];
    for (var j = 0; j < 3; j++) {
      if (!v[j].isFinite) errors.add(Issue('nan', {'row': i + 1, 'col': j}, (i, j)));
    }
    if (v[2] < 0) errors.add(Issue('negU', {'row': i + 1}, (i, 2)));
    pts.add(Point(v[0], v[1], relative ? v[2] * v[0].abs() / 100 : v[2], v[2]));
  }
  if (pts.length < 3) errors.insert(0, const Issue('minPoints'));
  if (errors.isEmpty) {
    outer:
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        if (pts[j].x == pts[i].x) {
          errors.add(Issue('dup', {'a': i + 1, 'b': j + 1}));
          break outer;
        }
      }
    }
    final xs = pts.map((p) => p.x);
    final e = xs.reduce(math.max) - xs.reduce(math.min);
    final scale = math.max(xs.map((v) => v.abs()).reduce(math.max), 1.0);
    if (e == 0 || e <= _eps * scale * math.max(1, pts.length)) errors.add(const Issue('range'));
  }
  var sC = double.nan, sU = double.nan;
  if (errors.isEmpty) {
    final meanU = _sum(pts.map((p) => p.u)) / pts.length;
    if (settings.mode == ThresholdMode.absolute) {
      sC = parseNum(settings.limitC);
      sU = parseNum(settings.limitU);
    } else {
      final aC = parseNum(settings.alphaC), aU = parseNum(settings.alphaU);
      if (!_ok(aC) || !_ok(aU)) errors.add(const Issue('threshold'));
      sC = aC * meanU;
      sU = aU * meanU;
    }
    if ((!_ok(sC) || !_ok(sU)) && !errors.any((e) => e.code == 'threshold')) {
      errors.add(const Issue('threshold'));
    }
  }
  if (errors.isEmpty) {
    if (pts.any((p) => p.u == 0)) warnings.add('warn.zeroU');
    if (pts.length == 3) warnings.add('warn.three');
    if (meta.unitI.isNotEmpty && meta.unitC.isNotEmpty && meta.unitI.trim() != meta.unitC.trim()) {
      warnings.add('warn.units');
    }
  }
  var needsSort = false;
  if (errors.isEmpty) {
    for (var i = 1; i < pts.length; i++) {
      if (pts[i].x <= pts[i - 1].x) needsSort = true;
    }
  }
  return Validation(errors, warnings, pts, sC, sU, needsSort);
}

class Majorant {
  const Majorant(this.a, this.b, this.bornes, this.usable);
  final double a, b;
  final List<double> bornes;
  final bool usable;
  double at(double v) => a * v + b;
}

class Analysis {
  const Analysis({
    required this.pts,
    required this.c,
    required this.u,
    required this.maj,
    required this.lo,
    required this.hi,
    required this.sC,
    required this.sU,
    required this.decC,
    required this.decU,
  });
  final List<Point> pts;
  final LinearFit c, u;
  final Majorant maj;
  final double lo, hi, sC, sU;
  final Decision decC, decU;
}

/// analyserEtalonnage : pts triés par indication strictement croissante.
Analysis analyser(List<Point> pts, double sC, double sU) {
  for (var i = 1; i < pts.length; i++) {
    if (pts[i].x <= pts[i - 1].x) throw const CoreError('notSorted');
  }
  final x = [for (final p in pts) p.x];
  final c = ajusterDroite(x, [for (final p in pts) p.c]);
  final u = ajusterDroite(x, [for (final p in pts) p.u]);
  final lo = x.first, hi = x.last;
  final majA = u.a, majB = u.b + u.residuMax;
  final bornes = [majA * lo + majB, majA * hi + majB];
  final seuilNeg = -tol * math.max(1.0, pts.map((p) => p.u.abs()).reduce(math.max));
  final maj = Majorant(majA, majB, bornes, bornes.every((v) => v >= seuilNeg));
  return Analysis(
    pts: List.unmodifiable(pts),
    c: c,
    u: u,
    maj: maj,
    lo: lo,
    hi: hi,
    sC: sC,
    sU: sU,
    decC: evaluerCritere(c, sC),
    decU: evaluerCritere(u, sU),
  );
}

/// interp1 linéaire de la correction, strictement dans l'étendue.
double interpolation(double x, List<Point> pts) {
  if (!(x >= pts.first.x && x <= pts.last.x)) throw const CoreError('outOfRange');
  for (var i = 1; i < pts.length; i++) {
    if (x <= pts[i].x) {
      final l = pts[i - 1], r = pts[i];
      return l.c + (x - l.x) * (r.c - l.c) / (r.x - l.x);
    }
  }
  return pts.last.c;
}

enum CorrectionMethod { regression, interpolation }

class CalcResult {
  const CalcResult({
    required this.x,
    required this.c,
    required this.corrected,
    required this.uFit,
    required this.uPrudent,
    required this.methodC,
    required this.nature,
    required this.k,
  });

  /// [uFit] : incertitude U(I) affichée ; [uPrudent] : conservée pour le rapport uniquement.
  final double x, c, corrected, uFit, uPrudent;
  final CorrectionMethod methodC;
  final String nature, k;

  /// Incertitude affichée U(I).
  double get u => uFit;
}

/// calculerResultat : même ordre de contrôles que la version MATLAB.
///   Correction  C(I)  = a_C · I + b_C
///   Valeur corrigée   = I + C(I)
///   Incertitude U(I)  = a_U · I + b_U   (valeur affichée)
///   U prudente  Up(I) = U(I) + résidu max (conservée pour le rapport uniquement)
/// Sécurité : hors étendue, U(I) négative (au point ou à une borne), nature inconnue ou
/// unités incompatibles → bloqué. Une incertitude négative n'est jamais remplacée par 0.
CalcResult calculer(Analysis a, Meta meta, Object xRaw, CorrectionMethod methodC, {required bool confirmed}) {
  if (!confirmed) throw const CoreError('confirm');
  final x = xRaw is double ? xRaw : parseNum(xRaw.toString());
  if (!x.isFinite) throw const CoreError('input');
  if (x < a.lo || x > a.hi) throw CoreError('outOfRange', {'lo': a.lo, 'hi': a.hi});
  final c = methodC == CorrectionMethod.regression ? a.c.at(x) : interpolation(x, a.pts);
  if (!a.maj.usable) throw const CoreError('majorant');
  final uFit = a.u.at(x);
  if (!uFit.isFinite || uFit < 0 || a.u.at(a.lo) < 0 || a.u.at(a.hi) < 0) throw const CoreError('negModel');
  final uPrudent = a.maj.at(x);
  if (meta.nature.isEmpty) throw const CoreError('nature');
  if (meta.unitI.isNotEmpty && meta.unitI.trim() != meta.unitC.trim()) throw const CoreError('unitsCalc');
  return CalcResult(
    x: x,
    c: c,
    corrected: x + c,
    uFit: uFit,
    uPrudent: uPrudent,
    methodC: methodC,
    nature: meta.nature,
    k: meta.k,
  );
}

/// Alerte de linéarité : le résidu max de la correction dépasse la plus petite
/// incertitude du certificat (comparaison seulement si les unités sont identiques).
bool alerteLinearite(Analysis a, Meta meta, UncType uncType) {
  final unitU = uncType == UncType.relative ? meta.unitI : meta.unitU;
  if (meta.unitC.trim() != unitU.trim()) return false;
  return a.c.residuMax > a.pts.map((p) => p.u).reduce(math.min);
}

/// Affichage : incertitude à 2 chiffres significatifs arrondie VERS LE HAUT
/// (jamais sous-estimée) ; la correction est affichée avec le même nombre de
/// décimales. Les valeurs stockées ne sont jamais arrondies.
({double value, int decimals}) arrondirIncertitude(double u) {
  if (!u.isFinite || u <= 0) return (value: u, decimals: 2);
  final p = 1 - (math.log(u) / math.ln10).floor(); // position du 2e chiffre significatif
  final f = math.pow(10, p).toDouble();
  // Tolérance relative 1e-9 : 0,08 (= 8,000000000000002 × 10⁻²) reste 0,08.
  var value = (u * f * (1 - 1e-9)).ceil() / f;
  if (p < 0) value = value.roundToDouble();
  return (value: value, decimals: math.max(0, p));
}

class CertLine {
  const CertLine(this.ref, this.eq, this.err, {required this.ok, this.recalcule = false});
  final double ref, eq, err;
  final bool ok, recalcule;
}

/// Ligne de résultat d'un certificat : nombres avant ±U (ordre des colonnes).
/// Convention : Erreur = indication − référence ; Correction = −Erreur.
/// Une ligne sans erreur imprimée ou incohérente est signalée (ok = false),
/// jamais corrigée en silence.
CertLine ligneCertificat(List<double> nums) {
  if (nums.length >= 3) {
    final t = nums.sublist(nums.length - 3);
    final a = t[0], b = t[1], c = t[2];
    final tolerance = math.max(0.03, c.abs() * 0.15);
    if ((b - a - c).abs() <= tolerance) return CertLine(a, b, c, ok: true);
    if ((a - b - c).abs() <= tolerance) return CertLine(b, a, c, ok: true);
    return CertLine(a, b, c, ok: false);
  }
  return CertLine(nums[0], nums[1], nums[1] - nums[0], ok: false, recalcule: true);
}
