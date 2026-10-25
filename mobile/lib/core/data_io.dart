/// Import CSV, export CSV et sessions JSON — mêmes formats que la version web
/// (une session enregistrée sur le site s'ouvre dans l'application, et
/// inversement). Fonctions pures : aucune lecture de fichier ici.
library;

import 'dart:convert';

import 'engine.dart';

const int maxPdfBytes = 20 * 1024 * 1024;
const int maxTextBytes = 2 * 1024 * 1024;
const int maxPoints = 500;

/// io/importerPoints : en-tête Indication, Correction, Incertitude (ordre libre),
/// séparateur « ; », tabulation ou « , ». Les valeurs restent du texte : elles
/// sont validées par [valider], jamais converties en zéro.
List<List<String>> parseCsv(String text) {
  final lines = text.replaceFirst('﻿', '').split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) throw const CoreError('csvEmpty');
  final delim = lines.first.contains(';') ? ';' : (lines.first.contains('\t') ? '\t' : ',');
  List<String> split(String l) =>
      l.split(delim).map((v) => v.trim().replaceFirstMapped(RegExp(r'^"(.*)"$'), (m) => m[1]!)).toList();
  final head = split(lines.first).map((h) => h.toLowerCase()).toList();
  final idx = ['indication', 'correction', 'incertitude'].map(head.indexOf).toList();
  if (idx.any((i) => i < 0)) throw const CoreError('csvHeader');
  final rows = <List<String>>[];
  for (var n = 1; n < lines.length; n++) {
    final c = split(lines[n]);
    if (c.length < 3) throw CoreError('csvCols', {'line': n + 1});
    rows.add([for (final i in idx) i < c.length ? _clip(c[i], 40) : '']);
  }
  if (rows.isEmpty) throw const CoreError('csvEmpty');
  if (rows.length > maxPoints) throw const CoreError('tooLarge');
  return rows;
}

String _clip(Object? v, int max) {
  final s = v is String || v is num ? v.toString() : '';
  return s.length > max ? s.substring(0, max) : s;
}

String _d(double v) => v.isFinite ? double.parse(v.toStringAsPrecision(12)).toString().replaceAll('.', ',') : '';

/// Export CSV (séparateur « ; », virgule décimale, BOM UTF-8 pour Excel).
String exportCsv(Analysis a, List<CalcResult> history) {
  final b = StringBuffer('﻿');
  void row(List<Object> cells) => b.write('${cells.join(';')}\r\n');
  row(['Indication', 'Correction', 'Incertitude', 'C_ajustee', 'Residu_C', 'U_ajustee', 'Residu_U', 'U_majorante']);
  for (var i = 0; i < a.pts.length; i++) {
    final p = a.pts[i];
    row([p.x, p.c, p.u, a.c.ajuste[i], a.c.residu[i], a.u.ajuste[i], a.u.residu[i], a.maj.at(p.x)].map(_d).toList());
  }
  row(['']);
  row(['Modele', 'a', 'b', 'R2', 'Residu_max', 's_res', 'Seuil', 'Decision']);
  String dec(Decision d) => d.ok ? 'Acceptable' : 'Non representatif';
  row(['Correction', _d(a.c.a), _d(a.c.b), _d(a.c.r2), _d(a.c.residuMax), _d(a.c.sRes), _d(a.sC), dec(a.decC)]);
  row(['Incertitude', _d(a.u.a), _d(a.u.b), _d(a.u.r2), _d(a.u.residuMax), _d(a.u.sRes), _d(a.sU), dec(a.decU)]);
  row(['U_prudente (majorante)', _d(a.maj.a), _d(a.maj.b), '', '', '', '', a.maj.usable ? 'Utilisable' : 'Non utilisable']);
  if (history.isNotEmpty) {
    row(['']);
    row(['Calcul_indication', 'Correction', 'Valeur_corrigee', 'U_modelisee', 'U_prudente', 'k', 'Nature', 'Methode_C']);
    for (final r in history) {
      row([_d(r.x), _d(r.c), _d(r.corrected), r.uFitOk ? _d(r.uFit) : 'non exploitable', _d(r.uPrudent), r.k, r.nature, r.methodC.name]);
    }
  }
  return b.toString();
}

class Session {
  const Session(this.meta, this.settings, this.points, {this.kVerified = false});
  final Meta meta;
  final Settings settings;
  final List<List<String>> points;

  /// Vrai si k vient du certificat ou de l'utilisateur (sinon « à vérifier »).
  final bool kVerified;
}

String encodeSession(Session s) => const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'app': 'AnalyseurEtalonnage-mobile',
      'meta': {
        'instrument': s.meta.instrument,
        'identifier': s.meta.identifier,
        'certificate': s.meta.certificate,
        'date': s.meta.date,
        'lab': s.meta.lab,
        'unitI': s.meta.unitI,
        'unitC': s.meta.unitC,
        'unitU': s.meta.unitU,
        'nature': s.meta.nature,
        'k': s.meta.k,
        'validUntil': s.meta.validUntil,
      },
      'kVerified': s.kVerified,
      'settings': {
        'mode': s.settings.mode == ThresholdMode.absolute ? 'absolute' : 'fraction',
        'alphaC': s.settings.alphaC,
        'alphaU': s.settings.alphaU,
        'limitC': s.settings.limitC,
        'limitU': s.settings.limitU,
        'uncType': s.settings.uncType == UncType.relative ? 'relative' : 'absolute',
      },
      'points': s.points,
    });

/// Session venant d'un fichier : donnée non fiable. Seules des chaînes courtes
/// et un nombre borné de points sont acceptés ; aucun résultat n'est relu
/// (l'analyse est toujours relancée).
Session decodeSession(String text) {
  Object? j;
  try {
    j = jsonDecode(text);
  } on FormatException {
    throw const CoreError('session');
  }
  if (j is! Map || j['points'] is! List || (j['points'] as List).length > maxPoints) {
    throw const CoreError('session');
  }
  final m = j['meta'] is Map ? j['meta'] as Map : const {};
  final st = j['settings'] is Map ? j['settings'] as Map : const {};
  String f(Map src, String k, [int max = 200]) => _clip(src[k], max);
  final nature = f(m, 'nature');
  return Session(
    Meta(
      instrument: f(m, 'instrument'),
      identifier: f(m, 'identifier'),
      certificate: f(m, 'certificate'),
      date: f(m, 'date', 40),
      lab: f(m, 'lab'),
      unitI: f(m, 'unitI', 40),
      unitC: f(m, 'unitC', 40),
      unitU: f(m, 'unitU', 40),
      nature: const ['', 'U', 'u'].contains(nature) ? nature : '',
      k: f(m, 'k', 40),
      validUntil: f(m, 'validUntil', 10),
    ),
    Settings(
      mode: st['mode'] == 'absolute' ? ThresholdMode.absolute : ThresholdMode.fraction,
      alphaC: st.containsKey('alphaC') ? f(st, 'alphaC', 40) : '0.25',
      alphaU: st.containsKey('alphaU') ? f(st, 'alphaU', 40) : '0.25',
      limitC: st.containsKey('limitC') ? f(st, 'limitC', 40) : '0',
      limitU: st.containsKey('limitU') ? f(st, 'limitU', 40) : '0',
      uncType: st['uncType'] == 'relative' ? UncType.relative : UncType.absolute,
    ),
    [
      for (final r in j['points'] as List)
        [for (var i = 0; i < 3; i++) r is List && i < r.length ? _clip(r[i], 40) : ''],
    ],
    kVerified: j['kVerified'] == true,
  );
}
