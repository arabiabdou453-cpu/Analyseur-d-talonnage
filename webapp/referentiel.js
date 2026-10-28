/* Référentiel unique du site (miroir de mobile/lib/core/referentiel.dart) :
   familles exclues, grandeurs et unités proposées, exemples. */
(function (global) {
  'use strict';

  /* Familles dont les résultats sont établis point par point : ni interpolation ni modélisation. */
  const FAMILLES_EXCLUES = ['Dimensionnel', 'Masses étalons (poids)', 'Instruments de volume (verrerie)'];

  /* Grandeurs et unités de la saisie manuelle (familles exclues absentes). */
  const GRANDEURS = [
    { nom: 'Température', unites: ['°C', 'K', '°F'] },
    { nom: 'Pression', unites: ['Pa', 'kPa', 'MPa', 'bar', 'mbar', 'psi', 'mmHg'] },
    { nom: 'Masse (instruments de pesage)', unites: ['mg', 'g', 'kg', 't'] },
    { nom: 'Humidité relative', unites: ['%HR'] },
    { nom: 'Temps', unites: ['s', 'min', 'h'] },
    { nom: 'Fréquence', unites: ['Hz', 'kHz', 'MHz'] },
    { nom: 'Tension', unites: ['mV', 'V', 'kV'] },
    { nom: 'Courant', unites: ['µA', 'mA', 'A'] },
    { nom: 'Résistance', unites: ['Ω', 'kΩ', 'MΩ'] },
    { nom: 'Force', unites: ['N', 'kN'] },
    { nom: 'Couple', unites: ['N·m'] },
    { nom: 'Vitesse de rotation', unites: ['tr/min'] },
    { nom: 'Vitesse linéaire', unites: ['m/s', 'km/h'] },
    { nom: 'Débit', unites: ['L/min', 'm³/h'] },
    { nom: 'pH', unites: ['pH'] },
    { nom: 'Conductivité', unites: ['µS/cm', 'mS/cm'] },
    { nom: 'Éclairement', unites: ['lx'] },
    { nom: 'Niveau sonore', unites: ['dB'] },
  ];

  /* Exemples : [indication, correction, incertitude] ; correction faible devant l'étendue,
     incertitude croissante avec l'indication. */
  const EXEMPLES = [
    { instrument: 'Thermomètre numérique', instrumentAr: 'ميزان حرارة رقمي', certificat: 'EX-2026-0101', grandeur: 'Température', unite: '°C',
      points: [[-20, 0.12, 0.10], [0, 0.08, 0.10], [20, 0.05, 0.11], [50, 0.02, 0.12], [100, -0.04, 0.15], [150, -0.09, 0.18]] },
    { instrument: 'Manomètre numérique', instrumentAr: 'مقياس ضغط رقمي', certificat: 'EX-2026-0102', grandeur: 'Pression', unite: 'bar',
      points: [[0, 0.010, 0.020], [2, 0.015, 0.022], [4, 0.020, 0.025], [6, 0.030, 0.028], [8, 0.035, 0.030], [10, 0.040, 0.033]] },
    { instrument: 'Balance électronique', instrumentAr: 'ميزان إلكتروني', certificat: 'EX-2026-0103', grandeur: 'Masse (instruments de pesage)', unite: 'g',
      points: [[0, 0, 0.001], [100, -0.001, 0.0015], [200, -0.002, 0.002], [500, -0.004, 0.003], [1000, -0.008, 0.005], [2000, -0.015, 0.009]] },
    { instrument: 'Hygromètre', instrumentAr: 'مقياس الرطوبة', certificat: 'EX-2026-0104', grandeur: 'Humidité relative', unite: '%HR',
      points: [[10, 1.2, 1.0], [30, 0.8, 1.1], [50, 0.5, 1.2], [70, 0.1, 1.4], [90, -0.4, 1.6]] },
    { instrument: 'Multimètre numérique', instrumentAr: 'متعدد القياسات الرقمي', certificat: 'EX-2026-0105', grandeur: 'Tension', unite: 'V',
      points: [[0.1, 0.0001, 0.0002], [1, 0.0003, 0.0004], [2, 0.0005, 0.0006], [5, 0.0010, 0.0011], [10, 0.0018, 0.0020], [20, 0.0035, 0.0038]] },
    { instrument: 'Tachymètre', instrumentAr: 'مقياس سرعة الدوران', certificat: 'EX-2026-0106', grandeur: 'Vitesse de rotation', unite: 'tr/min',
      points: [[500, 0.5, 1.0], [1000, 0.8, 1.2], [2000, 1.5, 1.8], [3000, 2.2, 2.5], [5000, 3.5, 3.8], [8000, 5.8, 6.0]] },
    { instrument: 'Dynamomètre', instrumentAr: 'مقياس القوة', certificat: 'EX-2026-0107', grandeur: 'Force', unite: 'kN',
      points: [[5, 0.01, 0.02], [10, 0.02, 0.03], [20, 0.04, 0.04], [30, 0.05, 0.05], [40, 0.07, 0.06], [50, 0.08, 0.07]] },
    { instrument: 'Débitmètre', instrumentAr: 'مقياس التدفق', certificat: 'EX-2026-0108', grandeur: 'Débit', unite: 'L/min',
      points: [[2, 0.05, 0.06], [5, 0.08, 0.08], [10, 0.12, 0.11], [20, 0.20, 0.18], [40, 0.35, 0.30]] },
  ];

  global.EtalonnageRef = Object.freeze({ FAMILLES_EXCLUES, GRANDEURS, EXEMPLES });
})(typeof window !== 'undefined' ? window : globalThis);
