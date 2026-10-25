/// Graphiques des modèles et des résidus (dessinés sans bibliothèque externe),
/// mêmes conventions que la version web.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/engine.dart';
import '../util/format.dart';

class ChartColors {
  const ChartColors(this.scheme);
  final ColorScheme scheme;
  Color get grid => scheme.outlineVariant.withValues(alpha: .6);
  Color get text => scheme.onSurfaceVariant;
  Color get fit => scheme.primary;
  Color get point => scheme.onSurface;
  Color get majorant => const Color(0xFFD97706);
  Color get barOk => scheme.primary;
  Color get barKo => scheme.error;
  Color get surface => scheme.surface;
}

/// Pas « ronds » pour les graduations (1, 2, 5 × 10^n).
List<double> niceTicks(double min, double max, [int count = 4]) {
  final span = (max - min) == 0 ? (max.abs() == 0 ? 1.0 : max.abs()) : max - min;
  final raw = span / count;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final n = raw / mag;
  final step = (n < 1.5 ? 1 : n < 3 ? 2 : n < 7 ? 5 : 10) * mag;
  final out = <double>[];
  // Multiples entiers du pas (pas d'accumulation d'erreur : 0 reste 0).
  for (var i = (min / step).ceil(); i * step <= max + step * 1e-6; i++) {
    out.add(i == 0 ? 0 : double.parse((i * step).toStringAsPrecision(12)));
  }
  return out;
}

(double, double) _domain(Iterable<double> vals, double pad) {
  var lo = vals.reduce(math.min), hi = vals.reduce(math.max);
  if (lo == hi) {
    final d = lo.abs() * .1 == 0 ? 1.0 : lo.abs() * .1;
    lo -= d;
    hi += d;
  }
  final p = (hi - lo) * pad;
  return (lo - p, hi + p);
}

class _Frame {
  _Frame(this.size, this.x0, this.x1, this.y0, this.y1);
  static const l = 52.0, r = 12.0, t = 10.0, b = 24.0;
  final Size size;
  final double x0, x1, y0, y1;
  double px(double v) => l + (v - x0) / (x1 - x0) * (size.width - l - r);
  double py(double v) => size.height - b - (v - y0) / (y1 - y0) * (size.height - t - b);
}

void _axes(Canvas canvas, _Frame f, ChartColors c, String lang) {
  final grid = Paint()
    ..color = c.grid
    ..strokeWidth = 1;
  final style = TextStyle(color: c.text, fontSize: 10, fontFeatures: const [FontFeature.tabularFigures()]);
  for (final v in niceTicks(f.y0, f.y1).where((v) => v >= f.y0 && v <= f.y1)) {
    canvas.drawLine(Offset(_Frame.l, f.py(v)), Offset(f.size.width - _Frame.r, f.py(v)), grid);
    final tp = TextPainter(text: TextSpan(text: fmtNum(v, lang, 4), style: style), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(_Frame.l - 6 - tp.width, f.py(v) - tp.height / 2));
  }
  final n = math.max(3, math.min(6, (f.size.width / 80).floor()));
  for (final v in niceTicks(f.x0, f.x1, n).where((v) => v >= f.x0 && v <= f.x1)) {
    final tp = TextPainter(text: TextSpan(text: fmtNum(v, lang, 4), style: style), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(f.px(v) - tp.width / 2, f.size.height - _Frame.b + 6));
  }
}

/// Nuage des points du certificat + droite ajustée (+ majorante pour U).
class ModelChart extends StatelessWidget {
  const ModelChart({super.key, required this.analysis, required this.uncertainty, this.marker, this.height = 220});
  final Analysis analysis;
  final bool uncertainty;
  final Offset? marker;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ModelPainter(analysis, uncertainty, marker, ChartColors(Theme.of(context).colorScheme), lang),
        ),
      ),
    );
  }
}

class _ModelPainter extends CustomPainter {
  _ModelPainter(this.a, this.unc, this.marker, this.c, this.lang);
  final Analysis a;
  final bool unc;
  final Offset? marker;
  final ChartColors c;
  final String lang;

  @override
  void paint(Canvas canvas, Size size) {
    final xs = a.pts.map((p) => p.x).toList();
    final ys = a.pts.map((p) => unc ? p.u : p.c).toList();
    final model = unc ? a.u : a.c;
    final lines = <(double Function(double), Color, bool)>[
      (model.at, c.fit, false),
      if (unc) (a.maj.at, c.majorant, true),
    ];
    final all = [...ys, for (final l in lines) ...[l.$1(a.lo), l.$1(a.hi)], if (marker != null) marker!.dy];
    final (x0, x1) = _domain(xs, .05);
    final (y0, y1) = _domain(all, .08);
    final f = _Frame(size, x0, x1, y0, y1);
    _axes(canvas, f, c, lang);
    for (final (fn, color, dashed) in lines) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final a0 = Offset(f.px(a.lo), f.py(fn(a.lo))), a1 = Offset(f.px(a.hi), f.py(fn(a.hi)));
      if (!dashed) {
        canvas.drawLine(a0, a1, p);
      } else {
        final len = (a1 - a0).distance;
        for (var d = 0.0; d < len; d += 10) {
          canvas.drawLine(Offset.lerp(a0, a1, d / len)!, Offset.lerp(a0, a1, math.min(d + 6, len) / len)!, p);
        }
      }
    }
    if (marker != null) {
      final m = Offset(f.px(marker!.dx), f.py(marker!.dy));
      canvas.drawLine(Offset(m.dx, _Frame.t), Offset(m.dx, size.height - _Frame.b),
          Paint()..color = c.majorant.withValues(alpha: .6)..strokeWidth = 1.2);
      canvas.drawCircle(m, 6, Paint()..color = c.majorant);
    }
    final fill = Paint()..color = c.surface;
    final stroke = Paint()
      ..color = c.point
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < xs.length; i++) {
      final o = Offset(f.px(xs[i]), f.py(ys[i]));
      canvas.drawCircle(o, 4.5, fill);
      canvas.drawCircle(o, 4.5, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ModelPainter old) => old.a != a || old.marker != marker || old.c.scheme != c.scheme;
}

/// Résidus signés en barres, bande ± seuil.
class ResidualChart extends StatelessWidget {
  const ResidualChart({super.key, required this.analysis, required this.uncertainty, this.height = 130});
  final Analysis analysis;
  final bool uncertainty;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ResidualPainter(analysis, uncertainty, ChartColors(Theme.of(context).colorScheme), lang),
        ),
      ),
    );
  }
}

class _ResidualPainter extends CustomPainter {
  _ResidualPainter(this.a, this.unc, this.c, this.lang);
  final Analysis a;
  final bool unc;
  final ChartColors c;
  final String lang;

  @override
  void paint(Canvas canvas, Size size) {
    final m = unc ? a.u : a.c;
    final d = unc ? a.decU : a.decC;
    final thr = d.seuil;
    final (x0, x1) = _domain(m.x, .1);
    final (y0, y1) = _domain([...m.residu, thr, -thr, 0], .08);
    final f = _Frame(size, x0, x1, y0, y1);
    _axes(canvas, f, c, lang);
    canvas.drawRect(Rect.fromLTRB(_Frame.l, f.py(thr), size.width - _Frame.r, f.py(-thr)),
        Paint()..color = c.fit.withValues(alpha: .08));
    final dash = Paint()
      ..color = c.majorant
      ..strokeWidth = 1.4;
    for (final y in [thr, -thr]) {
      for (var x = _Frame.l; x < size.width - _Frame.r; x += 8) {
        canvas.drawLine(Offset(x, f.py(y)), Offset(math.min(x + 4, size.width - _Frame.r), f.py(y)), dash);
      }
    }
    canvas.drawLine(Offset(_Frame.l, f.py(0)), Offset(size.width - _Frame.r, f.py(0)), Paint()..color = c.grid);
    final px = [for (final v in m.x) f.px(v)]..sort();
    var gap = double.infinity;
    for (var i = 1; i < px.length; i++) {
      gap = math.min(gap, px[i] - px[i - 1]);
    }
    final w = (gap.isFinite ? gap : 40) * .5;
    final bw = w.clamp(4.0, 26.0);
    for (var i = 0; i < m.x.length; i++) {
      final r = m.residu[i];
      final ok = r.abs() <= thr + d.tolerance;
      final top = f.py(math.max(0, r)), bottom = f.py(math.min(0, r));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(f.px(m.x[i]) - bw / 2, top, f.px(m.x[i]) + bw / 2, math.max(bottom, top + 1)),
            const Radius.circular(2)),
        Paint()..color = ok ? c.barOk : c.barKo,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResidualPainter old) => old.a != a || old.c.scheme != c.scheme;
}
