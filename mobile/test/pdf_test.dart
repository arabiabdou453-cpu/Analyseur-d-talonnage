// Lecture PDF et repérage des tableaux — mêmes cas que tests/TestImportPDF.m.
// Données anonymisées au format des certificats ISQ (aucune donnée client).
import 'dart:typed_data';

import 'package:analyseur_etalonnage/core/certificate.dart';
import 'package:analyseur_etalonnage/core/engine.dart';
import 'package:analyseur_etalonnage/core/pdf_text.dart';
import 'package:analyseur_etalonnage/core/referentiel.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

const _t = 1e-12;
const pm = '±';

const lignesISQ = [
  'Certificat nº  00/XX/TEST0001  Page  2  de 2',
  'Température (ºC)',
  "Valeur de   Valeur de   d'élargi.",
  'Erreur  Incertitde élargie',
  '-0,080  0,0  0,08  $pm 0,27  2,00',
  '25,020  24,9  -0,12  $pm 0,42  2,00',
  '60,043  59,8  -0,26  $pm 0,63  2,00',
  'Humidité (%hr), à 23°C',
  '11,76  13,60  1,84  $pm 1,7  2,00',
  '50,34  51,99  1,64  $pm 1,8  2,00',
  '79,85  80,50  0,65  $pm 2,4  2,00',
  'Instrument étalonné :  Enregistreur de température et humidité',
  'Constructeur:  MARQUE',
  'Type:  MODELE',
  'Nº ident.:  ID-0001',
  "Date d'étalonnage:  2026-07-15",
  "Local d'étalonnage:  Installations LABO",
  'Condition ambiante:  Température:  23,4 ºC  Humidité relative:  37,7 %hr',
];

/// Contenu : un titre et deux lignes ; la première dans un seul TJ à plusieurs
/// colonnes. \351 = é, \272 = º, \261 = ± (WinAnsi).
const contenuTest = r'BT /F1 9 Tf 14 TL 1 0 0 1 50 700 Tm (Temp\351rature \(\272C\)) Tj T* '
    r'[(-0,080)-6000(0,0)-5000(0,08)-4000(\261 0,27)-3000(2,00)] TJ '
    r'0 -14 Td (25,020) Tj 60 0 Td (24,9) Tj 50 0 Td (-0,12) Tj 45 0 Td (\261 0,42) Tj 40 0 Td (2,00) Tj ET';

Uint8List pdf(String contenu, {bool compresser = false}) {
  var octets = Uint8List.fromList(contenu.codeUnits);
  var filtre = '';
  if (compresser) {
    octets = Uint8List.fromList(const ZLibEncoder().encode(octets));
    filtre = ' /Filter /FlateDecode';
  }
  final entete = '%PDF-1.4\n4 0 obj\n<< /Length ${octets.length}$filtre >>\nstream\n'.codeUnits;
  final fin = '\nendstream\nendobj\n%%EOF\n'.codeUnits;
  return Uint8List.fromList([...entete, ...octets, ...fin]);
}

void main() {
  group('repérage des tableaux', () {
    final cert = analyserCertificat(lignesISQ);
    test('deux séries, valeurs et convention C = −Erreur', () {
      expect(cert.series.length, 2);
      final t = cert.series[0], h = cert.series[1];
      expect(t.quantity, 'Température');
      expect(t.unit, '°C');
      expect([for (final p in t.points) p.x], [0, 24.9, 59.8]);
      for (final (i, c) in [-0.08, 0.12, 0.26].indexed) {
        expect(t.points[i].c, closeTo(c, _t));
      }
      expect([for (final p in t.points) p.u], [0.27, 0.42, 0.63]);
      expect([for (final p in t.points) p.line.ref], [-0.08, 25.02, 60.043]);
      expect(t.k, 2);
      expect(t.inconsistent, isFalse);
      expect(h.unit, '%hr');
      expect([for (final p in h.points) p.x], [13.6, 51.99, 80.5]);
      for (final (i, c) in [-1.84, -1.64, -0.65].indexed) {
        expect(h.points[i].c, closeTo(c, _t));
      }
    });
    test('métadonnées', () {
      final m = cert.meta;
      expect(m.certificate, '00/XX/TEST0001');
      expect(m.identifier, 'ID-0001');
      expect(m.date, '2026-07-15');
      expect(m.lab, 'LABO');
      expect(m.expanded, isTrue);
      expect(m.instrument, 'Enregistreur de température et humidité — MARQUE MODELE');
    });
    test('numéro de certificat collé au symbole nº', () {
      for (final l in ['Certificat nº26/DZ/X001', 'Certificat n° 26/DZ/X001', 'Certificat n.: 26/DZ/X001']) {
        expect(analyserCertificat([l]).meta.certificate, '26/DZ/X001', reason: l);
      }
    });
    test('espace de mot dans un TJ conservée', () {
      final l = extrairePdfLignes(pdf(r'BT /F1 9 Tf 1 0 0 1 50 700 Tm [(Certificat n)(\272)-401(26/DZ/X001)] TJ ET'));
      expect(l.single, 'Certificat nº 26/DZ/X001');
    });
    test('nombres hors tableau ignorés', () {
      final c = analyserCertificat([
        'Condition ambiante:  Température:  23,4 ºC  Humidité relative:  37,7 %hr',
        'Résolution Temp.:  0,1°C',
        "Intervalle d'indication:  -20 à +70 °C",
      ]);
      expect(c.series, isEmpty);
    });
    test('k non supposé, nature non déduite', () {
      final c = analyserCertificat(['Masse (g)', '1,000  1,002  0,002  $pm 0,001', '2,000  2,003  0,003  $pm 0,001']);
      expect(c.series.single.k.isNaN, isTrue);
      expect(c.meta.expanded, isFalse);
    });
    test('erreur absente ou incohérente signalée', () {
      final c = analyserCertificat(['Température (°C)', '10,00  10,50  0,90  $pm 0,3  2,00', '11,76  1,84  $pm 1,7']);
      expect(c.series.single.points.map((p) => p.ok), [false, false]);
      expect(c.series.single.points.first.c, closeTo(-0.9, _t)); // valeur imprimée conservée
    });
    test('signe moins Unicode', () {
      final c = analyserCertificat(['Tension (V)', '0,500  0,480  −0,020  $pm 0,01']);
      expect(c.series.single.points.single.c, closeTo(0.02, _t));
    });
  });

  group('lecture PDF', () {
    test('flux non compressé', () {
      final l = extrairePdfLignes(pdf(contenuTest));
      expect(l[0], 'Température (ºC)');
      expect(l[1], '-0,080  0,0  0,08  $pm 0,27  2,00');
      expect(l[2], '25,020  24,9  -0,12  $pm 0,42  2,00');
      final s = analyserCertificat(l).series.single;
      expect(s.points.map((p) => p.c).toList(), [closeTo(-0.08, _t), closeTo(0.12, _t)]);
    });
    test('flux FlateDecode', () {
      final s = analyserCertificat(extrairePdfLignes(pdf(contenuTest, compresser: true))).series.single;
      expect(s.points.map((p) => p.x).toList(), [0, 24.9]);
    });
    test('fichier non PDF refusé', () {
      expect(() => extrairePdfLignes(Uint8List.fromList('pas un pdf'.codeUnits)),
          throwsA(isA<CoreError>().having((e) => e.code, 'code', 'pdfInvalid')));
    });
    test('PDF chiffré refusé', () {
      expect(() => extrairePdfLignes(Uint8List.fromList('%PDF-1.4\ntrailer << /Encrypt 5 0 R >>'.codeUnits)),
          throwsA(isA<CoreError>().having((e) => e.code, 'code', 'pdfEncrypted')));
    });
    test('PDF sans tableau', () {
      final c = analyserCertificat(extrairePdfLignes(pdf('BT /F1 10 Tf 1 0 0 1 50 700 Tm (Rapport sans resultats) Tj ET')));
      expect(c.series, isEmpty);
      expect(c.hasText, isFalse); // moins de 20 caractères utiles
    });
  });

  test('familles exclues : classification par mots-clés', () {
    expect(classerFamille('Cale étalon 25 mm'), famillesExclues[0]);
    expect(classerFamille('', 'Pied à coulisse numérique'), famillesExclues[0]);
    expect(classerFamille('Poids étalon 1 kg classe F1'), famillesExclues[1]);
    expect(classerFamille('', 'Burette 50 mL'), famillesExclues[2]);
    expect(classerFamille('Température (°C)', 'Thermomètre'), familleAutre);
    expect(classerFamille('Masse (g)', 'Balance — poids étalons classe F1'), familleAutre); // pesage : les poids sont la référence
  });
}
