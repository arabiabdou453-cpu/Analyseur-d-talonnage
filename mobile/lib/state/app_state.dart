/// État de l'application : saisie, analyse, calculs, préférences.
/// Toute modification des données invalide l'analyse (« À recalculer », F2).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/certificate.dart';
import '../core/data_io.dart';
import '../core/engine.dart';
import '../l10n/strings.dart';
import '../util/format.dart';

class AppState extends ChangeNotifier {
  AppState() {
    for (final c in [...metaCtl.values, ...settingsCtl.values]) {
      c.addListener(_changed);
    }
    // Une saisie de k par l'utilisateur vaut vérification (les affectations du code fixent kVerified ensuite).
    metaCtl['k']!.addListener(() => kVerified = metaCtl['k']!.text.trim().isNotEmpty);
    _setRows(const []);
  }

  // ---------- Préférences ----------
  String lang = 'fr';
  ThemeMode themeMode = ThemeMode.system;
  String t(String key, [Map<String, Object> vars = const {}]) => tr(lang, key, vars);

  void toggleLang() {
    lang = lang == 'fr' ? 'ar' : 'fr';
    _persist();
    notifyListeners();
  }

  void toggleTheme(Brightness current) {
    themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    _persist();
    notifyListeners();
  }

  // ---------- Saisie ----------
  final Map<String, TextEditingController> metaCtl = {
    for (final k in ['instrument', 'identifier', 'certificate', 'date', 'lab', 'unitI', 'unitC', 'unitU', 'validUntil'])
      k: TextEditingController(),
    // k = 2 pré-rempli mais signalé « à vérifier » tant qu'il ne vient ni du certificat ni de l'utilisateur.
    'k': TextEditingController(text: '2'),
  };
  final Map<String, TextEditingController> settingsCtl = {
    'alphaC': TextEditingController(text: '0.25'),
    'alphaU': TextEditingController(text: '0.25'),
    'limitC': TextEditingController(text: '0'),
    'limitU': TextEditingController(text: '0'),
  };
  String nature = '';
  ThresholdMode mode = ThresholdMode.fraction;
  UncType uncType = UncType.absolute;

  /// Faux tant que k = 2 est la valeur par défaut (affichée « à vérifier »).
  bool kVerified = false;
  final List<List<TextEditingController>> rows = [];
  Set<(int, int)> badCells = {};
  List<Issue> errors = [];

  Meta get meta => Meta(
        instrument: metaCtl['instrument']!.text.trim(),
        identifier: metaCtl['identifier']!.text.trim(),
        certificate: metaCtl['certificate']!.text.trim(),
        date: metaCtl['date']!.text.trim(),
        lab: metaCtl['lab']!.text.trim(),
        unitI: metaCtl['unitI']!.text.trim(),
        unitC: metaCtl['unitC']!.text.trim(),
        unitU: metaCtl['unitU']!.text.trim(),
        nature: nature,
        k: metaCtl['k']!.text.trim(),
        validUntil: metaCtl['validUntil']!.text.trim(),
      );

  Settings get settings => Settings(
        mode: mode,
        alphaC: settingsCtl['alphaC']!.text,
        alphaU: settingsCtl['alphaU']!.text,
        limitC: settingsCtl['limitC']!.text,
        limitU: settingsCtl['limitU']!.text,
        uncType: uncType,
      );

  List<List<String>> get rawRows => [for (final r in rows) r.map((c) => c.text).toList()];
  List<List<String>> get filledRows => rawRows.where((r) => r.any((v) => v.trim().isNotEmpty)).toList();

  void setNature(String v) {
    nature = v;
    _changed();
  }

  void setUncType(UncType u) {
    uncType = u;
    _changed();
  }

  void setMode(ThresholdMode m) {
    mode = m;
    _changed();
  }

  void _setRows(List<List<String>> values) {
    for (final r in rows) {
      for (final c in r) {
        c.dispose();
      }
    }
    rows.clear();
    final src = values.isEmpty ? const [['', '', ''], ['', '', ''], ['', '', '']] : values;
    for (final v in src) {
      _addRow(v);
    }
  }

  void _addRow(List<String> v) {
    final r = [for (var j = 0; j < 3; j++) TextEditingController(text: j < v.length ? v[j] : '')];
    for (final c in r) {
      c.addListener(_changed);
    }
    rows.add(r);
  }

  void addRow() {
    if (rows.length >= maxPoints) return;
    _addRow(const ['', '', '']);
    _changed();
  }

  void removeRow(int i) {
    for (final c in rows.removeAt(i)) {
      c.dispose();
    }
    if (rows.isEmpty) _addRow(const ['', '', '']);
    _changed();
  }

  void setRows(List<List<String>> values) {
    _setRows(values);
    _changed();
  }

  void clearRows() => setRows(const []);

  void loadExample() {
    String n(String s) => lang == 'fr' ? s : s.replaceAll(',', '.');
    _setRows([
      [n('0'), n('0,1'), n('0,2')],
      [n('10'), n('0,2'), n('0,22')],
      [n('20'), n('0,3'), n('0,24')],
      [n('30'), n('0,4'), n('0,26')],
    ]);
    metaCtl['instrument']!.text = lang == 'fr' ? 'Thermomètre numérique' : 'ميزان حرارة رقمي';
    metaCtl['certificate']!.text = 'EX-0001';
    for (final k in ['unitI', 'unitC', 'unitU']) {
      metaCtl[k]!.text = '°C';
    }
    metaCtl['k']!.text = '2';
    kVerified = true; // jeu d'exemple : k = 2 fait partie des données
    uncType = UncType.absolute;
    nature = 'U';
    _changed();
  }

  /// Applique une série extraite d'un certificat PDF (après revue par l'utilisateur).
  void applyCertificate(CertSeries s, CertMeta m, {required bool multiple}) {
    _setRows([for (final p in s.points) [rawNum(p.x, lang), rawNum(p.c, lang), rawNum(p.u, lang)]]);
    void set(String k, String v) {
      if (v.isNotEmpty) metaCtl[k]!.text = v;
    }

    set('instrument', [m.instrument, if (multiple) s.quantity].where((e) => e.isNotEmpty).join(' — '));
    set('identifier', m.identifier);
    set('certificate', m.certificate);
    set('date', m.date);
    set('lab', m.lab);
    for (final k in ['unitI', 'unitC', 'unitU']) {
      set(k, s.unit);
    }
    // k seulement s'il est imprimé sur chaque ligne ; nature U seulement si
    // le certificat parle explicitement d'incertitude élargie. Jamais supposés.
    metaCtl['k']!.text = s.k.isFinite ? rawNum(s.k, lang) : '2';
    kVerified = s.k.isFinite;
    uncType = UncType.absolute;
    if (m.expanded) nature = 'U';
    _changed();
  }

  // ---------- Analyse ----------
  Analysis? analysis;
  Meta? analysisMeta;
  DateTime? analyzedAt;
  List<String> warnings = [];
  bool stale = false;

  void _changed() {
    if (analysis != null) {
      analysis = null;
      history.clear();
      lastResult = null;
      calcError = null;
      confirmed = false;
      stale = true;
    }
    errors = [];
    badCells = {};
    _persist();
    notifyListeners();
  }

  /// validerDonnees + analyserEtalonnage. Le tri n'a lieu qu'après
  /// confirmation explicite ([confirmSort], F4).
  Future<bool> analyze(Future<bool> Function() confirmSort) async {
    final filled = <int>[];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].any((c) => c.text.trim().isNotEmpty)) filled.add(i);
    }
    final v = valider([for (final i in filled) rows[i].map((c) => c.text).toList()], settings, meta);
    if (v.errors.isNotEmpty) {
      errors = v.errors;
      badCells = {for (final e in v.errors) if (e.cell != null) (filled[e.cell!.$1], e.cell!.$2)};
      notifyListeners();
      return false;
    }
    final w = [...v.warnings];
    var pts = v.pts;
    if (v.needsSort) {
      if (!await confirmSort()) return false;
      pts = [...pts]..sort((a, b) => a.x.compareTo(b.x));
      _setRows([for (final p in pts) [rawNum(p.x, lang), rawNum(p.c, lang), rawNum(p.uRaw, lang)]]);
      w.add('warn.sorted');
    }
    try {
      final a = analyser(pts, v.sC, v.sU);
      if (!a.maj.usable) w.add('warn.majorant');
      if (alerteLinearite(a, meta, uncType)) w.add('warn.linearity');
      if (uncType == UncType.relative) w.add('warn.relative');
      if (!kVerified) w.add('warn.kDefault');
      analysis = a;
      analysisMeta = meta;
      analyzedAt = DateTime.now();
      warnings = w;
      errors = [];
      badCells = {};
      stale = false;
      history.clear();
      lastResult = null;
      calcError = null;
      confirmed = false;
      calcInput.text = rawNum(double.parse(((a.lo + a.hi) / 2).toStringAsPrecision(10)), lang);
      _persist();
      liveCalc(); // calcul instantané dès l'arrivée sur le calculateur (notifie l'interface)
      return true;
    } on CoreError catch (e) {
      errors = [Issue(e.code, e.params)];
      notifyListeners();
      return false;
    }
  }

  String issueText(Issue e) {
    final p = Map<String, Object>.of(e.params);
    if (e.code == 'nan') {
      p['col'] = t(['col.indication', 'col.correction', 'col.uncertainty'][e.params['col'] as int]);
    }
    return t('err.${e.code}', p);
  }

  String errorText(CoreError e) {
    final p = Map<String, Object>.of(e.params);
    if (e.code == 'outOfRange' && p['lo'] is double) {
      p['lo'] = fmtNum(p['lo']! as double, lang);
      p['hi'] = fmtNum(p['hi']! as double, lang);
    }
    return t('err.${e.code}', p);
  }

  // ---------- Calculateur ----------
  final TextEditingController calcInput = TextEditingController();
  CorrectionMethod methodC = CorrectionMethod.regression;
  bool confirmed = false;
  CoreError? calcError;
  CalcResult? lastResult;
  final List<CalcResult> history = [];

  void setCalcOptions({CorrectionMethod? c, bool? confirm}) {
    methodC = c ?? methodC;
    confirmed = confirm ?? confirmed;
    liveCalc();
  }

  /// Calcul instantané à chaque saisie (à partir des coefficients de l'analyse).
  void liveCalc() {
    final a = analysis;
    if (a == null) return;
    try {
      lastResult = calculer(a, analysisMeta!, calcInput.text, methodC, confirmed: confirmed);
      calcError = null;
    } on CoreError catch (e) {
      lastResult = null;
      calcError = e;
    }
    notifyListeners();
  }

  /// Ajoute le résultat affiché à l'historique.
  void calculate() {
    liveCalc();
    if (lastResult != null) {
      history.add(lastResult!);
      notifyListeners();
    }
  }

  bool get expired {
    final v = analysisMeta?.validUntil ?? '';
    return v.isNotEmpty && v.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0;
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  // ---------- Sessions et persistance ----------
  Session get session => Session(meta, settings, rawRows, kVerified: kVerified);

  void applySession(Session s) {
    final m = s.meta;
    final values = {
      'instrument': m.instrument,
      'identifier': m.identifier,
      'certificate': m.certificate,
      'date': m.date,
      'lab': m.lab,
      'unitI': m.unitI,
      'unitC': m.unitC,
      'unitU': m.unitU,
      'validUntil': m.validUntil,
      'k': m.k.isEmpty ? '2' : m.k,
    };
    values.forEach((k, v) => metaCtl[k]!.text = v);
    kVerified = s.kVerified && m.k.isNotEmpty;
    nature = m.nature;
    mode = s.settings.mode;
    uncType = s.settings.uncType;
    settingsCtl['alphaC']!.text = s.settings.alphaC;
    settingsCtl['alphaU']!.text = s.settings.alphaU;
    settingsCtl['limitC']!.text = s.settings.limitC;
    settingsCtl['limitU']!.text = s.settings.limitU;
    _setRows(s.points);
    _changed();
  }

  static const _kDraft = 'draft.v1', _kLang = 'lang', _kTheme = 'theme';
  Timer? _saveTimer;
  bool _restoring = false;

  void _persist() {
    if (_restoring) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kDraft, encodeSession(session));
        await p.setString(_kLang, lang);
        await p.setString(_kTheme, themeMode.name);
      } catch (_) {
        // Stockage indisponible : l'application reste utilisable sans brouillon.
      }
    });
  }

  Future<void> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      _restoring = true;
      lang = supportedLangs.contains(p.getString(_kLang)) ? p.getString(_kLang)! : 'fr';
      themeMode = ThemeMode.values.firstWhere((m) => m.name == p.getString(_kTheme), orElse: () => ThemeMode.system);
      final draft = p.getString(_kDraft);
      if (draft != null) applySession(decodeSession(draft));
    } catch (_) {
      // Brouillon illisible : on repart d'un formulaire vide.
    } finally {
      _restoring = false;
      stale = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final c in [...metaCtl.values, ...settingsCtl.values, calcInput, for (final r in rows) ...r]) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Accès à l'état depuis l'arbre de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
