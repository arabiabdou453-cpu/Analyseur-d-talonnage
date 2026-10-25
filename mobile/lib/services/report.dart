/// Rapport d'analyse PDF (en français). Ce n'est pas un certificat
/// d'étalonnage (F12) : il reprend données, métadonnées, coefficients,
/// résidus, décisions, graphiques et limites, calculés par le même moteur
/// que l'interface.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/engine.dart';
import '../ui/charts.dart' show niceTicks;
import '../util/format.dart';

/// Polices PDF standard : Latin-1 uniquement. Les symboles hors Latin-1 sont
/// remplacés par un équivalent lisible plutôt que perdus.
String _s(String v) {
  const map = {
    '−': '-', '–': '-', '—': '-', '→': '->', '≤': '<=', '≥': '>=',
    '’': "'", '‘': "'", '“': '"', '”': '"', '…': '...', ' ': ' ',
  };
  final b = StringBuffer();
  for (final r in v.runes) {
    final ch = String.fromCharCode(r);
    if (map.containsKey(ch)) {
      b.write(map[ch]);
    } else if (r <= 0xff) {
      b.write(ch);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

String _n(double v, [int d = 10]) => fmtNum(v, 'fr', d);
String _eq(String sym, double a, double b) => '$sym = ${_n(a)} · I ${b < 0 ? '- ${_n(-b)}' : '+ ${_n(b)}'}';

const _primary = PdfColor.fromInt(0xFF0E6E8C);
const _muted = PdfColor.fromInt(0xFF64748B);
const _ko = PdfColor.fromInt(0xFFB91C1C);
const _amber = PdfColor.fromInt(0xFFD97706);
const _grid = PdfColor.fromInt(0xFFE2E8F0);

Future<Uint8List> buildReport({
  required Analysis a,
  required Meta meta,
  required List<CalcResult> history,
  required List<String> warnings,
  required String Function(String key) tFr,
  required DateTime analyzedAt,
  required Settings settings,
}) async {
  final doc = pw.Document(
    title: "Rapport d'analyse d'étalonnage",
    creator: "Analyseur d'étalonnage",
    producer: "Analyseur d'étalonnage",
  );
  final font = PdfFont.helvetica(doc.document);
  final nature = switch (meta.nature) { 'U' => 'Élargie U', 'u' => 'Type u', _ => 'Inconnue' };
  final crit = settings.mode == ThresholdMode.absolute
      ? 'Seuil absolu'
      : 'Fraction de U moyenne (alpha = ${_n(parseNum(settings.alphaC))} / ${_n(parseNum(settings.alphaU))})';
  String dec(Decision d) => d.ok ? 'Acceptable' : 'Non représentatif';

  pw.Widget h(String t) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 1.2))),
        child: pw.Text(_s(t.toUpperCase()), style: pw.TextStyle(fontSize: 9.5, color: _primary, fontWeight: pw.FontWeight.bold)),
      );
  pw.Widget table(List<String> head, List<List<String>> rows, {Map<int, pw.Alignment>? align}) => pw.TableHelper.fromTextArray(
        headers: head.map(_s).toList(),
        data: [for (final r in rows) r.map(_s).toList()],
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _muted),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellAlignments: align ?? {},
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _grid, width: .5), bottom: pw.BorderSide(color: _grid, width: .5)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      );
  final right = {for (var i = 1; i < 8; i++) i: pw.Alignment.centerRight};

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(_s("Rapport d'analyse - pas un certificat d'étalonnage"), style: const pw.TextStyle(fontSize: 7, color: _muted)),
      pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _muted)),
    ]),
    build: (ctx) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s("Rapport d'analyse d'étalonnage"), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(_s([meta.instrument, meta.certificate].where((s) => s.isNotEmpty).join(' - ')),
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ),
        pw.Text(_s('Analyse du ${_date(analyzedAt)}'), style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ]),
      h('Instrument et certificat'),
      table(['Champ', 'Valeur', 'Champ', 'Valeur'], [
        ['Instrument', _v(meta.instrument), 'Identifiant', _v(meta.identifier)],
        ['N° de certificat', _v(meta.certificate), "Date d'étalonnage", _v(meta.date)],
        ['Laboratoire', _v(meta.lab), 'Étendue', '${_n(a.lo)} -> ${_n(a.hi)} ${meta.unitI}'],
        ['Unités (I / C / U)', '${_v(meta.unitI)} / ${_v(meta.unitC)} / ${_v(meta.unitU)}', 'Nature / k', '$nature / ${_v(meta.k)}'],
      ]),
      h('Modèles et décisions'),
      table(['Modèle', 'Équation', 'R²', 'Résidu max', 's_res', 'Seuil', 'Décision'], [
        ['Correction', _eq('C', a.c.a, a.c.b), _n(a.c.r2, 6), _n(a.c.residuMax), _n(a.c.sRes), _n(a.sC), dec(a.decC)],
        ['Incertitude', _eq('U', a.u.a, a.u.b), _n(a.u.r2, 6), _n(a.u.residuMax), _n(a.u.sRes), _n(a.sU), dec(a.decU)],
        ['Majorante', _eq('U', a.maj.a, a.maj.b), '-', '-', '-', '-', a.maj.usable ? 'Utilisable' : 'Non utilisable'],
      ]),
      pw.SizedBox(height: 4),
      pw.Text(_s('Critère : $crit ; modèle acceptable si résidu max <= seuil (tolérance numérique 1e-10). '
          's_res est un indicateur d’ajustement, pas une incertitude élargie.'), style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
      h('Points et résidus'),
      table(['#', 'Indication', 'Correction', 'C ajustée', 'Résidu C', 'Incertitude', 'U ajustée', 'Résidu U'], [
        for (var i = 0; i < a.pts.length; i++)
          ['${i + 1}', _n(a.pts[i].x), _n(a.pts[i].c), _n(a.c.ajuste[i]), _n(a.c.residu[i]), _n(a.pts[i].u), _n(a.u.ajuste[i]), _n(a.u.residu[i])],
      ], align: right),
      h('Graphiques'),
      pw.Row(children: [
        pw.Expanded(child: _chartBox('Modèle de correction', _chart(font, a, unc: false))),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _chartBox("Modèle d'incertitude (pointillés : majorante)", _chart(font, a, unc: true))),
      ]),
      pw.SizedBox(height: 8),
      pw.Row(children: [
        pw.Expanded(child: _chartBox('Résidus - correction (bande : ± seuil)', _residus(font, a, unc: false))),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _chartBox('Résidus - incertitude (bande : ± seuil)', _residus(font, a, unc: true))),
      ]),
      if (history.isNotEmpty) ...[
        h('Calculs'),
        table(['#', 'Indication', 'Correction', 'Valeur corrigée', 'U modélisée', 'U prudente (recommandée)', 'Méthode C'], [
          for (final (i, r) in history.indexed)
            [
              '${i + 1}',
              _n(r.x),
              _n(r.c),
              _n(r.corrected),
              r.uFitOk ? _n(r.uFit) : 'non exploitable',
              '${_n(r.uPrudent)} (${r.nature}, k = ${r.k.isEmpty ? '-' : r.k})',
              r.methodC == CorrectionMethod.regression ? 'Régression' : 'Interpolation',
            ],
        ], align: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight}),
      ],
      if (warnings.isNotEmpty) ...[
        h('Remarques et avertissements'),
        for (final w in warnings) pw.Bullet(text: _s(tFr(w)), style: const pw.TextStyle(fontSize: 8)),
      ],
      h('Limites'),
      for (final l in [
        "Régressions linéaires ordinaires non pondérées ; l'indication est traitée comme variable explicative sans modèle de son incertitude.",
        'La majorante enveloppe les valeurs aux points fournis ; aucune garantie entre les points sans justification.',
        "L'incertitude du certificat n'est pas un budget complet d'incertitude d'utilisation ; k n'est jamais supposé.",
        'Les seuils sont des réglages initiaux, non une règle normative (GUM, ISO/IEC 17025, FD X 07-014).',
        "Outil d'aide : ce rapport ne constitue pas à lui seul une validation ou une décision métrologique officielle. Il doit être revu par un spécialiste.",
      ])
        pw.Bullet(text: _s(l), style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
    ],
  ));
  return doc.save();
}

String _v(String s) => s.isEmpty ? '-' : s;
String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

pw.Widget _chartBox(String title, pw.Widget chart) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(_s(title), style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
      pw.SizedBox(height: 3),
      chart,
    ]);

(double, double) _dom(Iterable<double> v, double pad) {
  var lo = v.reduce(math.min), hi = v.reduce(math.max);
  if (lo == hi) {
    final d = lo.abs() * .1 == 0 ? 1.0 : lo.abs() * .1;
    lo -= d;
    hi += d;
  }
  final p = (hi - lo) * pad;
  return (lo - p, hi + p);
}

const _w = 240.0, _h = 130.0, _ml = 34.0, _mr = 6.0, _mt = 6.0, _mb = 16.0;

void _axes(PdfGraphics g, PdfFont font, double x0, double x1, double y0, double y1,
    double Function(double) px, double Function(double) py) {
  g.setStrokeColor(_grid);
  g.setLineWidth(.5);
  for (final v in niceTicks(y0, y1).where((v) => v >= y0 && v <= y1)) {
    g
      ..moveTo(_ml, py(v))
      ..lineTo(_w - _mr, py(v))
      ..strokePath();
    final s = _s(_n(v, 4));
    g.setFillColor(_muted);
    g.drawString(font, 6, s, _ml - 3 - font.stringMetrics(s).width * 6, py(v) - 2);
  }
  for (final v in niceTicks(x0, x1, 5).where((v) => v >= x0 && v <= x1)) {
    final s = _s(_n(v, 4));
    g.setFillColor(_muted);
    g.drawString(font, 6, s, px(v) - font.stringMetrics(s).width * 3, 4);
  }
}

pw.Widget _chart(PdfFont font, Analysis a, {required bool unc}) => pw.CustomPaint(
      size: const PdfPoint(_w, _h),
      painter: (g, size) {
        final xs = a.pts.map((p) => p.x).toList(), ys = a.pts.map((p) => unc ? p.u : p.c).toList();
        final m = unc ? a.u : a.c;
        final (x0, x1) = _dom(xs, .05);
        final (y0, y1) = _dom([...ys, m.at(a.lo), m.at(a.hi), if (unc) ...[a.maj.at(a.lo), a.maj.at(a.hi)]], .08);
        double px(double v) => _ml + (v - x0) / (x1 - x0) * (_w - _ml - _mr);
        double py(double v) => _mb + (v - y0) / (y1 - y0) * (_h - _mt - _mb);
        _axes(g, font, x0, x1, y0, y1, px, py);
        g
          ..setStrokeColor(_primary)
          ..setLineWidth(1.4)
          ..moveTo(px(a.lo), py(m.at(a.lo)))
          ..lineTo(px(a.hi), py(m.at(a.hi)))
          ..strokePath();
        if (unc) {
          g
            ..setStrokeColor(_amber)
            ..setLineDashPattern([4, 3])
            ..moveTo(px(a.lo), py(a.maj.at(a.lo)))
            ..lineTo(px(a.hi), py(a.maj.at(a.hi)))
            ..strokePath()
            ..setLineDashPattern();
        }
        g
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1);
        for (var i = 0; i < xs.length; i++) {
          g
            ..drawEllipse(px(xs[i]), py(ys[i]), 2.4, 2.4)
            ..strokePath();
        }
      },
    );

pw.Widget _residus(PdfFont font, Analysis a, {required bool unc}) => pw.CustomPaint(
      size: const PdfPoint(_w, _h * .75),
      painter: (g, size) {
        final m = unc ? a.u : a.c, d = unc ? a.decU : a.decC, thr = d.seuil, h = size.y;
        final (x0, x1) = _dom(m.x, .1);
        final (y0, y1) = _dom([...m.residu, thr, -thr, 0], .08);
        double px(double v) => _ml + (v - x0) / (x1 - x0) * (_w - _ml - _mr);
        double py(double v) => _mb + (v - y0) / (y1 - y0) * (h - _mt - _mb);
        _axes(g, font, x0, x1, y0, y1, px, py);
        g
          ..setFillColor(const PdfColor(0.055, 0.43, 0.55, 0.08))
          ..drawRect(_ml, py(-thr), _w - _ml - _mr, py(thr) - py(-thr))
          ..fillPath()
          ..setStrokeColor(_amber)
          ..setLineWidth(.8)
          ..setLineDashPattern([3, 2]);
        for (final y in [thr, -thr]) {
          g
            ..moveTo(_ml, py(y))
            ..lineTo(_w - _mr, py(y))
            ..strokePath();
        }
        g.setLineDashPattern();
        for (var i = 0; i < m.x.length; i++) {
          final r = m.residu[i];
          final top = py(math.max(0, r)), bottom = py(math.min(0, r));
          g
            ..setFillColor(r.abs() <= thr + d.tolerance ? _primary : _ko)
            ..drawRect(px(m.x[i]) - 4, bottom, 8, math.max(.6, top - bottom))
            ..fillPath();
        }
      },
    );
