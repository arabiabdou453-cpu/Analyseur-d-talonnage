// Parcours complet de l'interface : exemple → analyse → calcul, en français
// puis en arabe (sens de lecture de droite à gauche).
import 'package:analyseur_etalonnage/main.dart';
import 'package:analyseur_etalonnage/state/app_state.dart';
import 'package:analyseur_etalonnage/ui/analysis_page.dart';
import 'package:analyseur_etalonnage/ui/calc_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _app(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Petit téléphone Android courant : 360 × 780 points logiques.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1080, 2340);
  addTearDown(tester.view.reset);
  final state = AppState();
  await state.restore();
  await tester.pumpWidget(EtalonnageApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('français par défaut ; exemple, analyse et calcul', (tester) async {
    final s = await _app(tester);
    expect(find.text('Analyseur d’étalonnage'), findsOneWidget);
    expect(find.text('Données'), findsWidgets);

    await tester.tap(find.text('Exemple')); // exemple tiré au hasard : 5 à 8 points
    await tester.pumpAndSettle();
    expect(s.filledRows.length, inInclusiveRange(5, 8));
    s.setRows([['0', '0,1', '0,2'], ['10', '0,2', '0,22'], ['20', '0,3', '0,24'], ['30', '0,4', '0,26']]);
    s.setUnit('°C');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyser les données'));
    await tester.pumpAndSettle();
    expect(s.analysis, isNotNull);
    expect(find.text('Les deux modèles sont acceptables selon le critère sur les résidus'), findsOneWidget);
    final eq = find.text('C = 0,01 · I + 0,1');
    await tester.scrollUntilVisible(eq, 300,
        scrollable: find.descendant(of: find.byType(AnalysisPage), matching: find.byType(Scrollable)).first);
    expect(eq, findsOneWidget);

    await tester.tap(find.text('Calculateur').last);
    await tester.pumpAndSettle();
    final calcField = find.descendant(of: find.byType(CalcPage), matching: find.byType(TextField)).first;
    await tester.enterText(calcField, '15'); // calcul instantané
    await tester.pumpAndSettle();
    expect(s.calcError?.code, 'confirm'); // confirmation explicite exigée

    await tester.tap(find.descendant(of: find.byType(CalcPage), matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(s.lastResult!.corrected, closeTo(15.25, 1e-12));
    expect(s.lastResult!.uPrudent, closeTo(0.23, 1e-12));
    // Affichage : U à 2 chiffres significatifs vers le haut, C avec le même nombre de décimales.
    expect(find.text('15,25 ± 0,23 °C'), findsOneWidget);

    await tester.enterText(calcField, '31'); // hors étendue : bloqué
    await tester.pumpAndSettle();
    expect(s.calcError?.code, 'outOfRange');
    expect(s.lastResult, isNull);
  });

  testWidgets('une modification invalide l’analyse (F2)', (tester) async {
    final s = await _app(tester);
    await tester.tap(find.text('Exemple'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyser les données'));
    await tester.pumpAndSettle();
    expect(s.analysis, isNotNull);
    s.rows[0][1].text = '9,87'; // valeur absente de tous les exemples
    await tester.pumpAndSettle();
    expect(s.analysis, isNull);
    expect(s.stale, isTrue);
    await tester.pump(const Duration(seconds: 1)); // laisse passer l'enregistrement différé du brouillon
  });

  testWidgets('arabe : interface de droite à gauche', (tester) async {
    final s = await _app(tester);
    s.toggleLang();
    await tester.pumpAndSettle();
    expect(find.text('محلل المعايرة'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('محلل المعايرة')));
    expect(dir, TextDirection.rtl);
    await tester.pump(const Duration(seconds: 1)); // laisse passer l'enregistrement différé du brouillon
  });
}
