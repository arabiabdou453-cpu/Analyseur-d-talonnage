// Tests du moteur Dart — mêmes cas et mêmes valeurs de référence que
// tests/TestRegression.m (MATLAB) et webapp/tests.html (web).
import 'package:analyseur_etalonnage/core/engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _t = 1e-12;

List<Point> pts(List<double> x, List<double> c, List<double> u) =>
    [for (var i = 0; i < x.length; i++) Point(x[i], c[i], u[i])];

Matcher throwsCode(String code) =>
    throwsA(isA<CoreError>().having((e) => e.code, 'code', code));

void expectList(List<double> got, List<double> exp, [double tol = _t]) {
  expect(got.length, exp.length);
  for (var i = 0; i < exp.length; i++) {
    expect(got[i], closeTo(exp[i], tol), reason: 'index $i');
  }
}

const meta = Meta(nature: 'U', unitI: 'u', unitC: 'u');
const fraction = Settings(alphaC: '0.25', alphaU: '0.25');

void main() {
  group('casAExact', () {
    const x = <double>[0, 10, 20, 30], cc = [.1, .2, .3, .4], uu = [.2, .22, .24, .26];
    final c = ajusterDroite(x, cc), u = ajusterDroite(x, uu);
    final v = valider([for (var i = 0; i < 4; i++) ['${x[i]}', '${cc[i]}', '${uu[i]}']], fraction);
    final a = analyser(v.pts, v.sC, v.sU);

    test('coefficients et R²', () {
      expect(c.a, closeTo(.01, _t));
      expect(c.b, closeTo(.1, _t));
      expectList(c.residu, [0, 0, 0, 0]);
      expect(c.r2, closeTo(1, _t));
      expect(u.a, closeTo(.002, _t));
      expect(u.b, closeTo(.2, _t));
    });
    test('seuil 25 % de la moyenne des U', () => expect(v.sC, closeTo(.0575, _t)));
    test('majorante >= U aux points', () {
      for (var i = 0; i < 4; i++) {
        expect(a.maj.at(x[i]), greaterThanOrEqualTo(uu[i] - _t));
      }
    });
    test('calcul en 15', () {
      final r = calculer(a, meta, 15.0, CorrectionMethod.regression, confirmed: true);
      expect(r.c, closeTo(.25, _t));
      expect(r.corrected, closeTo(15.25, _t));
      expect(r.u, closeTo(.23, _t));
    });
    test('blocages du calculateur', () {
      expect(() => calculer(a, meta, 31.0, CorrectionMethod.regression, confirmed: true),
          throwsCode('outOfRange'));
      expect(() => calculer(a, meta, 15.0, CorrectionMethod.regression, confirmed: false),
          throwsCode('confirm'));
      expect(
          () => calculer(a, meta.copyWith(nature: ''), 15.0, CorrectionMethod.regression,
              confirmed: true),
          throwsCode('nature'));
      expect(
          () => calculer(a, meta.copyWith(unitC: 'mV'), 15.0, CorrectionMethod.regression,
              confirmed: true),
          throwsCode('unitsCalc'));
      expect(
          () => calculer(a, meta.copyWith(unitC: ''), 15.0, CorrectionMethod.regression,
              confirmed: true),
          throwsCode('unitsCalc'));
    });
    test('bornes incluses', () {
      expect(calculer(a, meta, 0.0, CorrectionMethod.regression, confirmed: true).uFit,
          closeTo(.2, _t));
      expect(calculer(a, meta, '30', CorrectionMethod.interpolation, confirmed: true).c,
          closeTo(.4, _t));
    });
  });

  group('casBReference', () {
    const x = <double>[0, 20, 50, 80, 100], cc = [.4, .1, .8, .3, .2], uu = [.8, .3, .5, .7, .2];
    final c = ajusterDroite(x, cc), u = ajusterDroite(x, uu);
    test('valeurs de référence MATLAB', () {
      expect(c.a, closeTo(-.0005882352941176471, _t));
      expect(c.b, closeTo(.3894117647058824, _t));
      expect(c.residuMax, closeTo(.44, _t));
      expect(c.r2, closeTo(.008058017727639, _t));
      expect(c.sRes, closeTo(.3107233811734211, _t));
      expect(u.b + u.residuMax, closeTo(.911764705882353, _t));
    });
    test('contrôle indépendant par équations normales', () {
      final n = x.length;
      final sx = x.reduce((a, b) => a + b), sy = cc.reduce((a, b) => a + b);
      var sxy = 0.0, sxx = 0.0;
      for (var i = 0; i < n; i++) {
        sxy += x[i] * cc[i];
        sxx += x[i] * x[i];
      }
      final a2 = (n * sxy - sx * sy) / (n * sxx - sx * sx);
      expect(c.a, closeTo(a2, _t));
      expect(c.b, closeTo((sy - a2 * sx) / n, _t));
    });
    test('décision et remarque R²', () {
      final a = analyser(pts(x, cc, uu), .125, .125);
      expect(a.decC.ok, isFalse);
      expect(a.decC.r2Key, 'r2.low');
    });
  });

  group('casConstant', () {
    final m = ajusterDroite(<double>[0, 10, 20], <double>[.2, .2, .2]);
    test('pente nulle, R² indéfini, s_res nul', () {
      expect(m.a, closeTo(0, _t));
      expect(m.r2.isNaN, isTrue);
      expect(m.sRes, closeTo(0, _t));
    });
    test('pas de rejet à cause du R² indéfini', () {
      expect(evaluerCritere(m, 0).ok, isTrue);
      expect(evaluerCritere(m, 0).r2Key, 'r2.undef');
    });
  });

  group('validation', () {
    bool has(Validation v, String code) => v.errors.any((e) => e.code == code);
    const ok3 = [
      ['0', '.1', '.2'],
      ['10', '.2', '.3'],
      ['20', '.3', '.4'],
    ];
    test('2 points refusés (minimum 3)', () {
      expect(valider([['0', '.1', '.2'], ['10', '.2', '.3']], fraction).errors.first.code, 'minPoints');
    });
    test('doublons refusés', () {
      expect(has(valider([['10', '.1', '.2'], ['10', '.2', '.3'], ['10', '.3', '.4']], fraction), 'dup'), isTrue);
    });
    test('U négative refusée', () {
      expect(has(valider([['0', '.1', '.2'], ['10', '.2', '-.1'], ['20', '.3', '.4']], fraction), 'negU'), isTrue);
    });
    test('texte et cellule vide refusés (jamais de zéro silencieux)', () {
      expect(has(valider([['0', '.1', '.2'], ['10', 'abc', '.3'], ['20', '.3', '.4']], fraction), 'nan'), isTrue);
      expect(has(valider([['0', '.1', '.2'], ['10', '', '.3'], ['20', '.3', '.4']], fraction), 'nan'), isTrue);
    });
    test('seuils invalides refusés', () {
      expect(has(valider(ok3, const Settings(alphaC: '-1')), 'threshold'), isTrue);
      expect(
          has(valider(ok3, const Settings(mode: ThresholdMode.absolute, limitC: '0.1', limitU: 'x')), 'threshold'),
          isTrue);
    });
    test('tri proposé, pas imposé ; avertissements', () {
      final v = valider([['20', '.3', '.4'], ['0', '.1', '0'], ['10', '.2', '.3']], fraction);
      expect(v.needsSort && v.errors.isEmpty, isTrue);
      expect(v.warnings, containsAll(['warn.zeroU', 'warn.three']));
      expect(() => analyser(v.pts, v.sC, v.sU), throwsCode('notSorted'));
    });
    test('unités différentes signalées', () {
      final v = valider(ok3, fraction, const Meta(unitI: '°C', unitC: 'K'));
      expect(v.warnings, contains('warn.units'));
    });
  });

  group('normalisation', () {
    test('formats acceptés', () {
      expect(parseNum('0,25'), closeTo(.25, _t));
      expect(parseNum('−0,5'), closeTo(-.5, _t));
      expect(parseNum('± 0,27', allowPlusMinus: true), closeTo(.27, _t));
      expect(parseNum('1 000,5'), closeTo(1000.5, _t));
      expect(parseNum('.5'), closeTo(.5, _t));
      expect(parseNum('-.5'), closeTo(-.5, _t));
      expect(parseNum('5.'), closeTo(5, _t));
      expect(parseNum('1e-3'), closeTo(.001, _t));
    });
    test('formats refusés', () {
      expect(parseNum('± 0,27').isNaN, isTrue);
      expect(parseNum('1.234,5').isNaN, isTrue);
      expect(parseNum('12 °C').isNaN, isTrue);
      expect(parseNum('').isNaN, isTrue);
    });
  });

  group('interpolation', () {
    final p = pts([0, 10, 20], [1, 3, 2], [0, 0, 0]);
    test('retrouve C aux points et entre les points', () {
      expect(interpolation(10, p), closeTo(3, _t));
      expect(interpolation(15, p), closeTo(2.5, _t));
    });
    test('hors étendue', () => expect(() => interpolation(21, p), throwsCode('outOfRange')));
  });

  group('incertitude ajustée négative dans l’étendue', () {
    final a = analyser(pts([0, 10, 20], [0, 0, 0], [0, 0, 1]), 1, 1);
    test('coefficients', () {
      expect(a.u.a, closeTo(.05, _t));
      expect(a.u.b, closeTo(-1 / 6, _t));
    });
    test('U(I) négative à une borne : calcul bloqué, jamais remplacée par 0', () {
      expect(() => calculer(a, meta, 15.0, CorrectionMethod.regression, confirmed: true), throwsCode('negModel'));
    });
    test('majorante utilisable', () => expect(a.maj.usable, isTrue));
  });

  group('cahier des charges CalibFit (tolérance 1e-6)', () {
    const t6 = 1e-6;
    final rows = [
      ['0', '0,10', '0,05'],
      ['20', '0,00', '0,06'],
      ['40', '-0,10', '0,08'],
      ['60', '-0,10', '0,08'],
      ['80', '-0,20', '0,09'],
      ['100', '-0,30', '0,10'],
    ];
    final v = valider(rows, fraction);
    final a = analyser(v.pts, v.sC, v.sU);
    const m = Meta(nature: 'U', unitI: '°C', unitC: '°C', unitU: '°C', k: '2');
    test('coefficients et résidus max', () {
      expect(a.c.a, closeTo(-0.00371429, t6));
      expect(a.c.b, closeTo(0.0857143, t6));
      expect(a.c.residuMax, closeTo(0.0371429, t6));
      expect(a.u.a, closeTo(0.000485714, t6));
      expect(a.u.b, closeTo(0.0523810, t6));
      expect(a.u.residuMax, closeTo(0.00819048, t6));
    });
    test('calculateur pour I = 50', () {
      final r = calculer(a, m, 50.0, CorrectionMethod.regression, confirmed: true);
      expect(r.c, closeTo(-0.1, t6));
      expect(r.corrected, closeTo(49.9, t6));
      expect(r.uFit, closeTo(0.0766667, t6));
      expect(r.uPrudent, closeTo(0.0848571, t6));
    });
    test('I = 120 et I = −5 bloqués', () {
      expect(() => calculer(a, m, 120.0, CorrectionMethod.regression, confirmed: true), throwsCode('outOfRange'));
      expect(() => calculer(a, m, -5.0, CorrectionMethod.regression, confirmed: true), throwsCode('outOfRange'));
    });
    test('alerte de linéarité', () {
      expect(alerteLinearite(a, m, UncType.absolute), isFalse); // 0,037 < 0,05
      expect(alerteLinearite(a, m.copyWith(unitU: 'K'), UncType.absolute), isFalse); // unités différentes
      final b = analyser(pts([0, 10, 20], [0, .5, 0], [.01, .01, .01]), 1, 1);
      expect(alerteLinearite(b, m, UncType.absolute), isTrue);
    });
  });

  test('incertitude relative : U_abs = U% × |I| / 100, valeur d’origine conservée', () {
    final v = valider([['10', '0', '1'], ['-20', '0', '1'], ['50', '0', '2']], const Settings(uncType: UncType.relative));
    expectList(v.pts.map((p) => p.u).toList(), [0.1, 0.2, 1]);
    expectList(v.pts.map((p) => p.uRaw).toList(), [1, 1, 2]);
  });

  test('arrondi d’affichage de U : 2 chiffres significatifs vers le haut', () {
    expect(arrondirIncertitude(0.0766667), (value: 0.077, decimals: 3));
    expect(arrondirIncertitude(0.0848571), (value: 0.085, decimals: 3));
    expect(arrondirIncertitude(0.08), (value: 0.08, decimals: 3));
    expect(arrondirIncertitude(0.121), (value: 0.13, decimals: 2));
    expect(arrondirIncertitude(2.41), (value: 2.5, decimals: 1));
    expect(arrondirIncertitude(37), (value: 37.0, decimals: 0));
    expect(arrondirIncertitude(123), (value: 130.0, decimals: 0));
  });

  group('lignes de certificat (Correction = −Erreur)', () {
    test('réf | équip | erreur', () {
      final r = ligneCertificat([-0.08, 0, 0.08]);
      expect(r.ok && r.ref == -0.08 && r.eq == 0 && r.err == 0.08, isTrue);
    });
    test('équip | réf | erreur', () {
      final r = ligneCertificat([24.9, 25.02, -0.12]);
      expect(r.ok && r.ref == 25.02 && r.eq == 24.9, isTrue);
    });
    test('incohérences signalées, jamais acceptées en silence', () {
      expect(ligneCertificat([-0.08, 0.08, 0]).ok, isFalse);
      expect(ligneCertificat([10, 10.5, 0.9]).ok, isFalse);
      expect(ligneCertificat([11.76, 1.84]).ok, isFalse);
    });
  });
}
