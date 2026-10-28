/// Référentiel unique de l'application (miroir de webapp/referentiel.js) :
/// familles exclues, grandeurs et unités proposées, exemples.
library;

/// Familles dont les résultats sont établis point par point : ni interpolation ni modélisation.
const List<String> famillesExclues = ['Dimensionnel', 'Masses étalons (poids)', 'Instruments de volume (verrerie)'];

/// Valeur de « famille » pour une série exploitable.
const String familleAutre = 'Autre';

class Grandeur {
  const Grandeur(this.nom, this.unites);
  final String nom;
  final List<String> unites;
}

/// Grandeurs et unités de la saisie manuelle (familles exclues absentes).
const List<Grandeur> grandeurs = [
  Grandeur('Température', ['°C', 'K', '°F']),
  Grandeur('Pression', ['Pa', 'kPa', 'MPa', 'bar', 'mbar', 'psi', 'mmHg']),
  Grandeur('Masse (instruments de pesage)', ['mg', 'g', 'kg', 't']),
  Grandeur('Humidité relative', ['%HR']),
  Grandeur('Temps', ['s', 'min', 'h']),
  Grandeur('Fréquence', ['Hz', 'kHz', 'MHz']),
  Grandeur('Tension', ['mV', 'V', 'kV']),
  Grandeur('Courant', ['µA', 'mA', 'A']),
  Grandeur('Résistance', ['Ω', 'kΩ', 'MΩ']),
  Grandeur('Force', ['N', 'kN']),
  Grandeur('Couple', ['N·m']),
  Grandeur('Vitesse de rotation', ['tr/min']),
  Grandeur('Vitesse linéaire', ['m/s', 'km/h']),
  Grandeur('Débit', ['L/min', 'm³/h']),
  Grandeur('pH', ['pH']),
  Grandeur('Conductivité', ['µS/cm', 'mS/cm']),
  Grandeur('Éclairement', ['lx']),
  Grandeur('Niveau sonore', ['dB']),
];

/// Grandeur et unité canonique d'une unité saisie ou extraite (casse ignorée en secours).
({Grandeur? grandeur, String unite}) trouverUnite(String u) {
  for (final g in grandeurs) {
    if (g.unites.contains(u)) return (grandeur: g, unite: u);
  }
  for (final g in grandeurs) {
    for (final v in g.unites) {
      if (v.toLowerCase() == u.toLowerCase()) return (grandeur: g, unite: v);
    }
  }
  return (grandeur: null, unite: u);
}

class Exemple {
  const Exemple(this.instrument, this.instrumentAr, this.certificat, this.grandeur, this.unite, this.points);
  final String instrument, instrumentAr, certificat, grandeur, unite;

  /// [indication, correction, incertitude] : correction faible devant l'étendue,
  /// incertitude croissante avec l'indication.
  final List<List<double>> points;
}

const List<Exemple> exemples = [
  Exemple('Thermomètre numérique', 'ميزان حرارة رقمي', 'EX-2026-0101', 'Température', '°C',
      [[-20, 0.12, 0.10], [0, 0.08, 0.10], [20, 0.05, 0.11], [50, 0.02, 0.12], [100, -0.04, 0.15], [150, -0.09, 0.18]]),
  Exemple('Manomètre numérique', 'مقياس ضغط رقمي', 'EX-2026-0102', 'Pression', 'bar',
      [[0, 0.010, 0.020], [2, 0.015, 0.022], [4, 0.020, 0.025], [6, 0.030, 0.028], [8, 0.035, 0.030], [10, 0.040, 0.033]]),
  Exemple('Balance électronique', 'ميزان إلكتروني', 'EX-2026-0103', 'Masse (instruments de pesage)', 'g',
      [[0, 0, 0.001], [100, -0.001, 0.0015], [200, -0.002, 0.002], [500, -0.004, 0.003], [1000, -0.008, 0.005], [2000, -0.015, 0.009]]),
  Exemple('Hygromètre', 'مقياس الرطوبة', 'EX-2026-0104', 'Humidité relative', '%HR',
      [[10, 1.2, 1.0], [30, 0.8, 1.1], [50, 0.5, 1.2], [70, 0.1, 1.4], [90, -0.4, 1.6]]),
  Exemple('Multimètre numérique', 'متعدد القياسات الرقمي', 'EX-2026-0105', 'Tension', 'V',
      [[0.1, 0.0001, 0.0002], [1, 0.0003, 0.0004], [2, 0.0005, 0.0006], [5, 0.0010, 0.0011], [10, 0.0018, 0.0020], [20, 0.0035, 0.0038]]),
  Exemple('Tachymètre', 'مقياس سرعة الدوران', 'EX-2026-0106', 'Vitesse de rotation', 'tr/min',
      [[500, 0.5, 1.0], [1000, 0.8, 1.2], [2000, 1.5, 1.8], [3000, 2.2, 2.5], [5000, 3.5, 3.8], [8000, 5.8, 6.0]]),
  Exemple('Dynamomètre', 'مقياس القوة', 'EX-2026-0107', 'Force', 'kN',
      [[5, 0.01, 0.02], [10, 0.02, 0.03], [20, 0.04, 0.04], [30, 0.05, 0.05], [40, 0.07, 0.06], [50, 0.08, 0.07]]),
  Exemple('Débitmètre', 'مقياس التدفق', 'EX-2026-0108', 'Débit', 'L/min',
      [[2, 0.05, 0.06], [5, 0.08, 0.08], [10, 0.12, 0.11], [20, 0.20, 0.18], [40, 0.35, 0.30]]),
];
