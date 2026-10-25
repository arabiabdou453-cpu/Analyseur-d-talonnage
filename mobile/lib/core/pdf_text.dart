/// Lecteur de texte PDF minimal — miroir de io/extraireTextePDF.m.
///
/// Flux non compressés ou FlateDecode, polices simples (WinAnsi / Latin-1),
/// opérateurs de texte (Tj, TJ, ', ") et de position (Td, TD, Tm, T*, TL, cm,
/// q/Q). Les largeurs de glyphes ne sont pas lues : la position des segments
/// d'un même TJ est estimée (0,55 em par caractère). Les PDF numérisés,
/// chiffrés ou à polices CID ne donnent pas de texte exploitable.
/// Tout s'exécute sur l'appareil ; aucun accès réseau.
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'engine.dart' show CoreError;

/// Lignes de texte, de haut en bas dans chaque flux de contenu.
List<String> extrairePdfLignes(Uint8List octets) {
  final s = String.fromCharCodes(octets); // octet n -> caractère n (Latin-1)
  if (s.length < 5 || !s.startsWith('%PDF-')) throw const CoreError('pdfInvalid');
  if (s.contains('/Encrypt')) throw const CoreError('pdfEncrypted');

  final debuts = RegExp(r'(?<!end)stream\r?\n').allMatches(s).map((m) => m.end).toList();
  final fins = RegExp('endstream').allMatches(s).map((m) => m.start).toList();
  final objets = RegExp(r'\d+\s+\d+\s+obj').allMatches(s).map((m) => m.start).toList();
  final ignorer = RegExp(r'/Subtype\s*/Image|/Type\s*/XRef|/Type\s*/ObjStm|/Length1|/FontFile|/EmbeddedFile');

  final lignes = <String>[];
  for (final st in debuts) {
    final en0 = fins.firstWhere((f) => f > st, orElse: () => -1);
    if (en0 < 0) continue;
    var en = en0;
    while (en > st && (octets[en - 1] == 10 || octets[en - 1] == 13)) {
      en--;
    }
    final o = objets.lastWhere((p) => p < st, orElse: () => 0);
    final dico = s.substring(o, st);
    if (ignorer.hasMatch(dico)) continue;
    var donnees = Uint8List.sublistView(octets, st, en);
    if (dico.contains('/FlateDecode')) {
      try {
        donnees = Uint8List.fromList(const ZLibDecoder().decodeBytes(donnees));
      } catch (_) {
        continue; // flux illisible : ignoré
      }
    } else if (dico.contains('/Filter')) {
      continue; // autres filtres non pris en charge
    }
    final texte = String.fromCharCodes(donnees);
    if (!RegExp(r'\bBT\b').hasMatch(texte) || !RegExp('T[Jj]').hasMatch(texte)) continue;
    lignes.addAll(_lignesFlux(texte));
  }
  return lignes;
}

final RegExp _jeton = RegExp(r'\((?:\\[\s\S]|[^\\()]|\((?:\\[\s\S]|[^\\()])*\))*\)|<<|>>|<[0-9A-Fa-f\s]*>|\[|\]|'
    r'''/[^\s/\[\]()<>{}%]*|[+-]?(?:\d+\.?\d*|\.\d+)|%[^\r\n]*|[A-Za-z'"*][A-Za-z0-9'"*]*''');

typedef _M = List<double>; // matrice 3x3 en ligne : [a b 0 c d 0 e f 1]

_M _id() => [1, 0, 0, 0, 1, 0, 0, 0, 1];
_M _mat(List<double> v) => [v[0], v[1], 0, v[2], v[3], 0, v[4], v[5], 1];
_M _mul(_M a, _M b) => [
      for (var i = 0; i < 3; i++)
        for (var j = 0; j < 3; j++) a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j],
    ];

class _Txt {
  const _Txt(this.s);
  final String s;
}

class _Item {
  const _Item(this.x, this.y, this.t, this.seq);
  final double x, y;
  final String t;
  final int seq;
}

List<String> _lignesFlux(String texte) {
  var ctm = _id(), tm = _id(), tlm = _id();
  final pile = <_M>[];
  var tl = 0.0, fs = 1.0;
  var ops = <Object>[];
  List<Object>? tableau;
  final items = <_Item>[];

  void ajouter(Object v) => (tableau ?? ops).add(v);
  void deplacer(double tx, double ty) {
    tlm = _mul([1, 0, 0, 0, 1, 0, tx, ty, 1], tlm);
    tm = List.of(tlm);
  }

  void emettre(String txt, double dx) {
    final m = _mul([1, 0, 0, 0, 1, 0, dx * fs, 0, 1], _mul(tm, ctm));
    items.add(_Item(m[6], m[7], txt, items.length));
  }

  void emettreTableau(List<Object> elements) {
    // Un TJ peut porter plusieurs colonnes séparées par de grands décalages.
    var avance = 0.0, debut = 0.0;
    var seg = StringBuffer();
    for (final v in elements) {
      if (v is double) {
        if (v < -1000 && seg.toString().trim().isNotEmpty) {
          emettre(seg.toString(), debut);
          seg = StringBuffer();
          avance -= v / 1000;
          debut = avance;
        } else {
          // Décalage de la taille d'une espace (> 0,25 em) : on garde la séparation des mots.
          if (v < -250 && seg.isNotEmpty) seg.write(' ');
          avance -= v / 1000;
          if (seg.isEmpty) debut = avance;
        }
      } else if (v is _Txt) {
        if (seg.isEmpty) debut = avance;
        seg.write(v.s);
        avance += v.s.length * 0.55;
      }
    }
    if (seg.toString().trim().isNotEmpty) emettre(seg.toString(), debut);
  }

  for (final m in _jeton.allMatches(texte)) {
    final j = m[0]!;
    final c = j[0];
    if (c == '%' || j == '<<' || j == '>>') continue;
    if (c == '(') {
      ajouter(_Txt(_decoderLitteral(j)));
      continue;
    }
    if (c == '<') {
      ajouter(_Txt(_decoderHexa(j)));
      continue;
    }
    if (c == '[') {
      tableau = <Object>[];
      continue;
    }
    if (c == ']') {
      ops.add(tableau ?? <Object>[]);
      tableau = null;
      continue;
    }
    if (c == '/') {
      ajouter(j);
      continue;
    }
    if ('+-.0123456789'.contains(c)) {
      ajouter(double.tryParse(j.endsWith('.') ? '${j}0' : (j.startsWith('.') ? '0$j' : j)) ?? 0.0);
      continue;
    }
    final n = ops.whereType<double>().toList();
    switch (j) {
      case 'q':
        pile.add(ctm);
      case 'Q':
        if (pile.isNotEmpty) ctm = pile.removeLast();
      case 'cm':
        if (n.length >= 6) ctm = _mul(_mat(n.sublist(n.length - 6)), ctm);
      case 'BT':
        tm = _id();
        tlm = _id();
      case 'Tf':
        if (n.isNotEmpty) fs = n.last;
      case 'TL':
        if (n.isNotEmpty) tl = n.last;
      case 'Td':
        if (n.length >= 2) deplacer(n[n.length - 2], n.last);
      case 'TD':
        if (n.length >= 2) {
          tl = -n.last;
          deplacer(n[n.length - 2], n.last);
        }
      case 'Tm':
        if (n.length >= 6) {
          tlm = _mat(n.sublist(n.length - 6));
          tm = List.of(tlm);
        }
      case 'T*':
        deplacer(0, -tl);
      case 'Tj':
        {
          final t = ops.whereType<_Txt>();
          if (t.isNotEmpty) emettre(t.last.s, 0);
        }
      case "'":
      case '"':
        {
          deplacer(0, -tl);
          final t = ops.whereType<_Txt>();
          if (t.isNotEmpty) emettre(t.last.s, 0);
        }
      case 'TJ':
        {
          final a = ops.whereType<List<Object>>();
          if (a.isNotEmpty) emettreTableau(a.last);
        }
    }
    ops = <Object>[];
  }

  items.sort((a, b) {
    final dy = b.y.compareTo(a.y);
    if (dy != 0) return dy;
    final dx = a.x.compareTo(b.x);
    return dx != 0 ? dx : a.seq.compareTo(b.seq);
  });
  final lignes = <String>[];
  var i = 0;
  while (i < items.length) {
    var fin = i;
    while (fin + 1 < items.length && (items[fin + 1].y - items[i].y).abs() <= 2.5) {
      fin++;
    }
    final groupe = items.sublist(i, fin + 1)
      ..sort((a, b) {
        final dx = a.x.compareTo(b.x);
        return dx != 0 ? dx : a.seq.compareTo(b.seq);
      });
    final brut = groupe.map((e) => e.t).join('  ');
    final propre = String.fromCharCodes(
            brut.codeUnits.where((u) => (u >= 32 && u <= 126) || (u >= 160 && u <= 255)))
        .trim();
    if (propre.isNotEmpty) lignes.add(propre);
    i = fin + 1;
  }
  return lignes;
}

String _decoderLitteral(String j) {
  final s = j.substring(1, j.length - 1);
  final out = StringBuffer();
  var i = 0;
  const echap = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f'};
  while (i < s.length) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      final d = s[i + 1];
      final oct = RegExp('^[0-7]{1,3}').firstMatch(s.substring(i + 1));
      if (oct != null) {
        out.writeCharCode(int.parse(oct[0]!, radix: 8) & 0xff);
        i += 1 + oct[0]!.length;
        continue;
      }
      if (echap.containsKey(d)) {
        out.write(echap[d]);
      } else if (d == '\r' || d == '\n') {
        if (d == '\r' && i + 2 < s.length && s[i + 2] == '\n') i++;
      } else {
        out.write(d);
      }
      i += 2;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

String _decoderHexa(String j) {
  var h = j.substring(1, j.length - 1).replaceAll(RegExp(r'\s'), '');
  if (h.isEmpty) return '';
  if (h.length.isOdd) h += '0';
  return String.fromCharCodes([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
}
