/// Repérage des tableaux de résultats d'un certificat — miroir de
/// io/analyserTexteCertificat.m.
///
/// Seules les lignes « référence | équipement | erreur | ±U | (k) » sont
/// retenues ; les autres nombres du document sont ignorés. Une ligne de titre
/// du type « Température (ºC) » ouvre une nouvelle série.
/// Convention : Erreur = indication − référence ; Correction = −Erreur.
library;

import 'engine.dart';
import 'referentiel.dart';

class CertPoint {
  const CertPoint(this.line, this.u, this.k);
  final CertLine line;
  final double u;

  /// k imprimé sur la ligne, NaN sinon.
  final double k;

  double get x => line.eq;
  double get c => -line.err;
  bool get ok => line.ok;
}

class CertSeries {
  CertSeries(this.title, this.quantity, this.unit);
  final String title, quantity, unit;
  final List<CertPoint> points = [];

  /// Famille (référentiel), renseignée à l'extraction.
  String famille = familleAutre;

  bool get inconsistent => points.any((p) => !p.ok);

  /// k seulement s'il est imprimé, identique, sur chaque ligne de la série.
  double get k {
    if (points.isEmpty || points.any((p) => !p.k.isFinite)) return double.nan;
    final k0 = points.first.k;
    return points.every((p) => (p.k - k0).abs() < 1e-9) ? k0 : double.nan;
  }
}

class CertMeta {
  const CertMeta({
    this.certificate = '',
    this.instrument = '',
    this.identifier = '',
    this.date = '',
    this.lab = '',
    this.conditions = '',
    this.expanded = false,
  });
  final String certificate, instrument, identifier, date, lab, conditions;

  /// Vrai seulement si le certificat mentionne explicitement une incertitude élargie.
  final bool expanded;
}

class Certificate {
  const Certificate(this.series, this.meta, {required this.hasText, this.famille = familleAutre});
  final List<CertSeries> series;

  /// Famille détectée sur l'ensemble du document.
  final String famille;
  final CertMeta meta;
  final bool hasText;
}

final RegExp _titre = RegExp(
  r'\b(Temp[ée]rature|Humidit[ée]|Pression|Masse|Tension|Courant|Longueur|R[ée]sistance|Fr[ée]quence|Force|Couple|D[ée]bit|Vitesse)[^()]*\(([^)]{1,12})\)',
  caseSensitive: false,
);
final RegExp _nombre = RegExp('(±|\\+/-)?\\s*([-+−–]?\\d+(?:[.,]\\d+)?)');

String _unite(String u) {
  var t = u.trim().replaceFirst('º', '°'); // º -> °
  if (RegExp(r'^%\s*hr$', caseSensitive: false).hasMatch(t)) t = '%hr';
  return t;
}

String _grandeur(String g) => g.isEmpty ? g : g[0].toUpperCase() + g.substring(1).toLowerCase();

Certificate analyserCertificat(List<String> lignes) {
  final series = <CertSeries>[];
  CertSeries? courant;
  for (final brut in lignes) {
    final l = brut.trim();
    final t = _titre.firstMatch(l);
    if (t != null && !l.contains('±')) {
      courant = CertSeries(l.replaceAll(RegExp(r'\s+'), ' '), _grandeur(t[1]!), _unite(t[2]!));
      series.add(courant);
      continue;
    }
    final jetons = _nombre.allMatches(l).map((m) => (pm: m[1] != null, v: parseNum(m[2]))).toList();
    final iU = jetons.indexWhere((j) => j.pm);
    if (iU < 2) continue;
    final avant = jetons.sublist(0, iU).map((j) => j.v).toList();
    final nums = avant.sublist(avant.length > 3 ? avant.length - 3 : 0);
    final u = jetons[iU].v.abs();
    if (!nums.every((v) => v.isFinite) || !u.isFinite) continue;
    final k = iU + 1 < jetons.length ? jetons[iU + 1].v : double.nan;
    if (courant == null) {
      courant = CertSeries('Série 1', '', '');
      series.add(courant);
    }
    courant.points.add(CertPoint(ligneCertificat(nums), u, k));
  }
  final texte = lignes.join('\n');
  for (final s in series) {
    s.famille = classerFamille(s.title, texte);
  }
  String valeur(String motif) {
    final m = RegExp(motif, caseSensitive: false).firstMatch(texte);
    return m == null ? '' : m[1]!.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  var date = valeur(r"Date\s*d.?\s*[ée]talonnage\s*:?\s*(\d{4}-\d{2}-\d{2}|\d{2}[/.\-]\d{2}[/.\-]\d{4})");
  final dm = RegExp(r'^(\d{2})[/.\-](\d{2})[/.\-](\d{4})$').firstMatch(date);
  if (dm != null) date = '${dm[3]}-${dm[2]}-${dm[1]}';
  final details = [valeur(r'Constructeur\s*:?\s*([^\n]+)'), valeur(r'(?:^|\n)Type\s*:?\s*([^\n]+)')]
      .where((s) => s.isNotEmpty)
      .join(' ');
  final instrument =
      [valeur(r'Instrument\s+[ée]talonn[ée]\s*:?\s*([^\n]+)'), details].where((s) => s.isNotEmpty).join(' — ');
  return Certificate(
    series.where((s) => s.points.isNotEmpty).toList(),
    CertMeta(
      // « n », puis au plus 2 symboles (º, °, .) : jamais un chiffre du numéro lui-même.
      certificate: valeur(r'Certificat\s*n[^A-Za-z0-9\s]{0,2}\s*:?\s*([A-Z0-9][\w/\-.]*)'),
      instrument: instrument,
      identifier: valeur(r'N.{0,2}\s*ident\.?\s*:?\s*([^\n]+)'),
      date: date,
      lab: valeur(r"Local\s*d.?\s*[ée]talonnage\s*:?\s*(?:Installations\s+)?([^\n]+)"),
      conditions: valeur(r'Condition\w*\s+ambiante\w*\s*:?\s*([^\n]+)'),
      expanded: RegExp(r'incerti\w*\s+[ée]largie|expanded\s+uncertainty', caseSensitive: false).hasMatch(texte),
    ),
    hasText: texte.replaceAll(RegExp(r'\s'), '').length > 20,
    famille: classerFamille('', texte),
  );
}

/// Famille d'une série : un nom de [famillesExclues], ou [familleAutre].
/// Mots-clés de la série, puis du document ; le contexte « pesage » d'un document
/// ne fait jamais exclure ses séries pour les poids étalons utilisés comme référence.
final List<RegExp> _motsFamille = [
  RegExp(r'\bdimensionnel|\blongueur\b|\bcales?\s+etalons?|pieds?\s+a\s+coulisse|micrometre|comparateur'),
  RegExp(r'poids\s+etalons?|masses?\s+etalons?|masse\s+conventionnelle|\bclasse\s+(e1|e2|f1|f2|m1|m2|m3)\b'),
  RegExp(r'verrerie|instruments?\s+de\s+volume|pipette|burette|\bfioles?\b|eprouvette'),
];

String _sansAccents(String s) {
  const de = 'àâäáéèêëîïíôöóùûüúçÀÂÄÁÉÈÊËÎÏÍÔÖÓÙÛÜÚÇ', vers = 'aaaaeeeeiiiooouuuucAAAAEEEEIIIOOOUUUUC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i < 0 ? ch : vers[i]);
  }
  return b.toString().toLowerCase();
}

String classerFamille(String texteSerie, [String texteDocument = '']) {
  String? chercher(String txt, int sauf) {
    for (var i = 0; i < _motsFamille.length; i++) {
      if (i != sauf && _motsFamille[i].hasMatch(txt)) return famillesExclues[i];
    }
    return null;
  }

  final doc = _sansAccents(texteDocument);
  return chercher(_sansAccents(texteSerie), -1) ??
      chercher(doc, RegExp('balance|pesage|ipfna').hasMatch(doc) ? 1 : -1) ??
      familleAutre;
}
