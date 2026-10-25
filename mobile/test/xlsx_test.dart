// Classeur Excel : vraies formules présentes, valeurs en cache identiques au
// moteur Dart (cas de test du cahier des charges), structure du fichier.
import 'package:analyseur_etalonnage/core/engine.dart';
import 'package:analyseur_etalonnage/core/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = [
    ['0', '0,10', '0,05'],
    ['20', '0,00', '0,06'],
    ['40', '-0,10', '0,08'],
    ['60', '-0,10', '0,08'],
    ['80', '-0,20', '0,09'],
    ['100', '-0,30', '0,10'],
  ];
  final v = valider(rows, const Settings());
  final a = analyser(v.pts, v.sC, v.sU);
  const meta = Meta(certificate: 'CE 01/26', instrument: 'Thermomètre', date: '2026-07-15', unitI: '°C', unitC: '°C', unitU: '°C', k: '2', nature: 'U');
  final files = unzipStored(buildXlsx(a, meta, uncType: UncType.absolute, kVerified: true));
  final s1 = files['xl/worksheets/sheet1.xml']!, s2 = files['xl/worksheets/sheet2.xml']!;
  double cached(String xml, String ref) =>
      double.parse(RegExp('<c r="$ref"[^>]*><f>[^<]*</f><v>([^<]*)</v>').firstMatch(xml)![1]!);

  test('deux feuilles, deux graphiques', () {
    expect(files.length, 15);
    expect(files['xl/workbook.xml'], contains('<sheet name="Interpolation"'));
    expect(files['xl/workbook.xml'], contains('<sheet name="Modélisation"'));
    expect(files.containsKey('xl/charts/chart1.xml') && files.containsKey('xl/charts/chart2.xml'), isTrue);
  });

  test('formules Excel (pas seulement des valeurs)', () {
    for (final f in ['SLOPE(C11:C16,B11:B16)', 'INTERCEPT(C11:C16,B11:B16)', 'RSQ(C11:C16,B11:B16)', 'COUNT(B11:B16)', 'MAX(F11:F16)']) {
      expect(s1, contains('<f>$f</f>'));
      expect(s2, contains('<f>$f</f>'));
    }
    expect(s1, contains(r'<f>$J$11*B11+$J$12</f>'));
    expect(s1, contains('<f>C11-D11</f>'));
    expect(s1, contains('<f>ABS(E11)</f>'));
    expect(s2, contains(r'<f>D11+$J$15</f>')); // U prudente
  });

  test('valeurs en cache identiques au moteur', () {
    expect(cached(s1, 'J11'), closeTo(a.c.a, 1e-15));
    expect(cached(s1, 'J12'), closeTo(a.c.b, 1e-15));
    expect(cached(s1, 'J15'), closeTo(0.0371429, 1e-6));
    expect(cached(s2, 'J11'), closeTo(0.000485714, 1e-6));
    expect(cached(s2, 'J12'), closeTo(0.0523810, 1e-6));
    expect(cached(s2, 'J15'), closeTo(0.00819048, 1e-6));
  });

  test('graphique : tendance linéaire avec équation et R², lié aux cellules', () {
    expect(files['xl/charts/chart1.xml'], contains('<c:trendlineType val="linear"/><c:dispRSqr val="1"/><c:dispEq val="1"/>'));
    expect(files['xl/charts/chart2.xml'], contains(r"'Modélisation'!$B$11:$B$16"));
  });

  test('mise en page et nom de fichier', () {
    expect(s1, contains('orientation="landscape"'));
    expect(s1, contains('state="frozen"'));
    expect(xlsxFileName(meta), 'certificat_CE-01-26_Thermometre_2026-07-15.xlsx');
  });

  test('échappement XML des métadonnées', () {
    final f = unzipStored(buildXlsx(a, meta.copyWith(instrument: 'A&B <x> "y"'), uncType: UncType.absolute, kVerified: false));
    expect(f['xl/worksheets/sheet1.xml'], contains('A&amp;B &lt;x&gt; &quot;y&quot;'));
    expect(f['xl/worksheets/sheet1.xml'], contains('(à vérifier)'));
  });

  test('CRC-32 de référence', () => expect(crc32('123456789'.codeUnits), 0xcbf43926));
}
