import 'package:analyseur_etalonnage/core/data_io.dart';
import 'package:analyseur_etalonnage/core/engine.dart';
import 'package:analyseur_etalonnage/core/pdf_text.dart';
import 'package:analyseur_etalonnage/l10n/strings.dart';
import 'package:analyseur_etalonnage/services/report.dart';
import 'package:analyseur_etalonnage/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher throwsCode(String code) => throwsA(isA<CoreError>().having((e) => e.code, 'code', code));

void main() {
  group('CSV', () {
    test('modèle point-virgule et virgule décimale (examples/exemple_bon.csv)', () {
      final rows = parseCsv('﻿Indication;Correction;Incertitude\r\n0;0,1;0,2\r\n10;0,2;0,22\r\n');
      expect(rows, [
        ['0', '0,1', '0,2'],
        ['10', '0,2', '0,22'],
      ]);
    });
    test('colonnes dans un autre ordre, séparateur virgule', () {
      expect(parseCsv('Incertitude,Indication,Correction\n0.2,0,0.1'), [
        ['0', '0.1', '0.2'],
      ]);
    });
    test('erreurs explicites', () {
      expect(() => parseCsv('Indication;Correction;Incertitude\n'), throwsCode('csvEmpty'));
      expect(() => parseCsv('A;B;C\n1;2;3'), throwsCode('csvHeader'));
      expect(() => parseCsv('Indication;Correction;Incertitude\n1;2'), throwsCode('csvCols'));
    });
    test('valeurs invalides conservées en texte puis refusées par la validation', () {
      final rows = parseCsv('Indication;Correction;Incertitude\n0;abc;0,2\n10;0,2;0,3\n20;0,3;0,4');
      expect(valider(rows, const Settings()).errors.single.code, 'nan');
    });
  });

  group('sessions', () {
    test('aller-retour', () {
      const s = Session(
        Meta(instrument: 'Thermomètre', certificate: 'X-1', unitI: '°C', unitC: '°C', nature: 'U', k: '2'),
        Settings(mode: ThresholdMode.absolute, limitC: '0,1', limitU: '0,2'),
        [
          ['0', '0,1', '0,2'],
        ],
      );
      final r = decodeSession(encodeSession(s));
      expect(r.meta.instrument, 'Thermomètre');
      expect(r.meta.nature, 'U');
      expect(r.meta.k, '2');
      expect(r.settings.mode, ThresholdMode.absolute);
      expect(r.settings.limitU, '0,2');
      expect(r.points, s.points);
    });
    test('session de la version web acceptée', () {
      final r = decodeSession('{"schema":1,"app":"AnalyseurEtalonnage-web","meta":{"instrument":"T","nature":"U"},'
          '"points":[["0","0,1","0,2"]],"settings":{"mode":"fraction","alphaC":"0.25","alphaU":"0.25"}}');
      expect(r.meta.instrument, 'T');
      expect(r.points.single, ['0', '0,1', '0,2']);
    });
    test('fichier falsifié : valeurs bornées, types refusés, nature inconnue rejetée', () {
      final long = 'x' * 5000;
      final r = decodeSession('{"meta":{"instrument":"$long","nature":"<script>","unitI":{"a":1}},'
          '"points":[[1,2,3],"pas une ligne",[null,true,"0,5"]]}');
      expect(r.meta.instrument.length, 200);
      expect(r.meta.nature, '');
      expect(r.meta.unitI, '');
      expect(r.points, [
        ['1', '2', '3'],
        ['', '', ''],
        ['', '', '0,5'],
      ]);
      expect(() => decodeSession('pas du json'), throwsCode('session'));
      expect(() => decodeSession('{"points":"x"}'), throwsCode('session'));
      expect(() => decodeSession('{"points":[${List.filled(501, '[]').join(',')}]}'), throwsCode('session'));
    });
  });

  group('affichage des nombres', () {
    test('10 chiffres significatifs, virgule en français, pas de faux zéro', () {
      expect(fmtNum(15.37469135689, 'fr'), '15,37469136');
      expect(fmtNum(0.1 + 0.2, 'en'), '0.3');
      expect(fmtNum(100, 'fr'), '100');
      expect(fmtNum(0.0000123456, 'en'), '0.0000123456'); // >= 1e-5 : notation décimale
      expect(fmtNum(0.00000123456, 'en'), '1.23456e-6'); // < 1e-5 : scientifique
      expect(fmtNum(1e-17, 'en'), '1e-17');
      expect(fmtNum(0, 'fr'), '0');
      expect(fmtNum(double.nan, 'fr'), '—');
      expect(equation('C', -0.000588, 0.389, 'fr'), 'C = -0,000588 · I + 0,389');
      expect(equation('C', 0.01, -0.1, 'en'), 'C = 0.01 · I − 0.1');
    });
  });

  test('rapport PDF généré (moteur identique à l’interface)', () async {
    final v = valider([
      ['0', '0,1', '0,2'],
      ['10', '0,2', '0,22'],
      ['20', '0,3', '0,24'],
      ['30', '0,4', '0,26'],
    ], const Settings());
    final a = analyser(v.pts, v.sC, v.sU);
    const meta = Meta(instrument: 'Thermomètre numérique', certificate: 'EX-1', unitI: '°C', unitC: '°C', unitU: '°C', nature: 'U');
    final r = calculer(a, meta, 15.0, CorrectionMethod.regression, confirmed: true);
    final bytes = await buildReport(
      a: a,
      meta: meta,
      history: [r],
      warnings: const ['warn.three'],
      tFr: (k) => tr('fr', k),
      analyzedAt: DateTime(2026, 10, 25, 9, 30),
      settings: const Settings(),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
    // Relecture du rapport par notre propre lecteur : accents et valeurs présents.
    // Le PDF place chaque mot séparément : on normalise les espaces avant de comparer.
    final texte = extrairePdfLignes(bytes).join(' ').replaceAll(RegExp(r'\s+'), ' ');
    expect(texte, contains("Rapport d'analyse d'étalonnage"));
    expect(texte, contains('C = 0,01 · I + 0,1'));
    expect(texte, contains('15,25'));
    expect(texte, contains('Thermomètre numérique'));
  });
}
