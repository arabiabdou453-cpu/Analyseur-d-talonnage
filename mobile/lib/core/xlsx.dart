/// Classeur Excel à deux feuilles (« Interpolation », « Modélisation ») —
/// miroir de webapp/xlsx.js, écrit sans bibliothèque : XML Office Open +
/// archive ZIP (méthode « stockée »).
///
/// Tous les résultats sont de VRAIES formules Excel (noms anglais, Excel les
/// traduit) : a = SLOPE(y,x), b = INTERCEPT(y,x), R² = RSQ(y,x),
/// n = COUNT(x), résidu max = MAX(|résidu|), valeur ajustée = a·x + b,
/// résidu = y − ajustée, U prudente = ajustée + résidu max. Chaque formule
/// porte aussi sa valeur en cache pour les aperçus ; Excel recalcule à
/// l'ouverture. Les valeurs ne sont jamais arrondies (format d'affichage seul).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'engine.dart';

String _x(Object? s) => (s ?? '')
    .toString()
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
    .replaceAll(RegExp('[\u0000-\u0008\u000b\u000c\u000e-\u001f]'), '');

String _col(int i) => String.fromCharCode(65 + i);

// ---------- ZIP (stocké) ----------
final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int crc32(List<int> b) {
  var c = 0xffffffff;
  for (final v in b) {
    c = _crcTable[(c ^ v) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

Uint8List _zip(List<(String, String)> files, DateTime now) {
  final out = BytesBuilder(), central = BytesBuilder();
  var offset = 0;
  final dosTime = (now.hour << 11) | (now.minute << 5) | (now.second >> 1);
  final dosDate = ((now.year - 1980) << 9) | (now.month << 5) | now.day;
  for (final (name, text) in files) {
    final data = utf8.encode(text), nm = utf8.encode(name), crc = crc32(data);
    final h = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 0x0800, Endian.little)
      ..setUint16(8, 0, Endian.little)
      ..setUint16(10, dosTime, Endian.little)
      ..setUint16(12, dosDate, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, nm.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    out
      ..add(h.buffer.asUint8List())
      ..add(nm)
      ..add(data);
    final c = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(12, dosTime, Endian.little)
      ..setUint16(14, dosDate, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, nm.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(c.buffer.asUint8List())
      ..add(nm);
    offset += 30 + nm.length + data.length;
  }
  final cd = central.takeBytes();
  final e = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, cd.length, Endian.little)
    ..setUint32(16, offset, Endian.little);
  out
    ..add(cd)
    ..add(e.buffer.asUint8List());
  return out.takeBytes();
}

/// Lecture des parties d'un ZIP stocké (utilisée par les tests).
Map<String, String> unzipStored(Uint8List bytes) {
  final dv = ByteData.sublistView(bytes), out = <String, String>{};
  var p = 0;
  while (p + 30 <= bytes.length && dv.getUint32(p, Endian.little) == 0x04034b50) {
    final size = dv.getUint32(p + 18, Endian.little), nl = dv.getUint16(p + 26, Endian.little);
    final xl = dv.getUint16(p + 28, Endian.little);
    final name = utf8.decode(bytes.sublist(p + 30, p + 30 + nl)), start = p + 30 + nl + xl;
    out[name] = utf8.decode(bytes.sublist(start, start + size));
    p = start + size;
  }
  return out;
}

// ---------- Cellules ----------
const _header = 1, _title = 2, _label = 3, _input = 4, _calc = 5, _index = 6, _resLabel = 7;

class _Cell {
  const _Cell(this.v, this.s, [this.f]);
  final Object? v; // double, int ou String
  final int s;
  final String? f;
}

String? _num(Object? v) {
  if (v is int) return '$v';
  if (v is double && v.isFinite) return v.toString();
  return null;
}

String _cellXml(String ref, _Cell c) {
  if (c.f != null) {
    final v = _num(c.v);
    return v == null
        ? '<c r="$ref" s="${c.s}" t="e"><f>${_x(c.f)}</f><v>#DIV/0!</v></c>'
        : '<c r="$ref" s="${c.s}"><f>${_x(c.f)}</f><v>$v</v></c>';
  }
  if (c.v is num) {
    final v = _num(c.v);
    return v == null ? '' : '<c r="$ref" s="${c.s}"><v>$v</v></c>';
  }
  return '<c r="$ref" s="${c.s}" t="inlineStr"><is><t xml:space="preserve">${_x(c.v)}</t></is></c>';
}

String _sheetXml(Map<String, _Cell> cells, List<double> widths, int freezeRow) {
  final rows = <int, List<(String, String, _Cell)>>{};
  for (final e in cells.entries) {
    final m = RegExp(r'^([A-Z])(\d+)$').firstMatch(e.key)!;
    rows.putIfAbsent(int.parse(m[2]!), () => []).add((m[1]!, e.key, e.value));
  }
  final keys = rows.keys.toList()..sort();
  final data = keys.map((r) {
    final cs = rows[r]!..sort((a, b) => a.$1.compareTo(b.$1));
    return '<row r="$r">${cs.map((c) => _cellXml(c.$2, c.$3)).join()}</row>';
  }).join();
  final cols = [for (final (i, w) in widths.indexed) '<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>'].join();
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>
<sheetViews><sheetView workbookViewId="0"><pane ySplit="$freezeRow" topLeftCell="A${freezeRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetFormatPr defaultRowHeight="15"/>
<cols>$cols</cols>
<sheetData>$data</sheetData>
<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>
<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>
<drawing r:id="rId1"/>
</worksheet>''';
}

// ---------- Graphique XY + courbe de tendance linéaire ----------
String _richTitle(String text, [int size = 1200]) =>
    '<c:title><c:tx><c:rich><a:bodyPr/><a:p><a:pPr><a:defRPr sz="$size" b="1"/></a:pPr><a:r><a:rPr lang="fr-FR" sz="$size" b="1"/><a:t>${_x(text)}</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>';

String _numRef(String sheet, String colL, int r1, int r2, List<double> values) =>
    "<c:numRef><c:f>'$sheet'!\$$colL\$$r1:\$$colL\$$r2</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val=\"${values.length}\"/>"
    '${[for (final (i, v) in values.indexed) if (v.isFinite) '<c:pt idx="$i"><c:v>$v</c:v></c:pt>'].join()}</c:numCache></c:numRef>';

String _chartXml({
  required String sheet,
  required int r1,
  required int r2,
  required List<double> xs,
  required List<double> ys,
  required String title,
  required String yName,
  required String xTitle,
  required String yTitle,
  (String, String, List<double>)? extra,
}) {
  String ser(int idx, String name, String yCol, List<double> yv, String color, {required bool trend, required bool line}) =>
      '<c:ser><c:idx val="$idx"/><c:order val="$idx"/><c:tx><c:v>${_x(name)}</c:v></c:tx>'
      '<c:spPr>${line ? '<a:ln w="22225"><a:solidFill><a:srgbClr val="$color"/></a:solidFill><a:prstDash val="dash"/></a:ln>' : '<a:ln w="19050"><a:noFill/></a:ln>'}</c:spPr>'
      '<c:marker>${line ? '<c:symbol val="none"/>' : '<c:symbol val="circle"/><c:size val="7"/><c:spPr><a:solidFill><a:srgbClr val="$color"/></a:solidFill></c:spPr>'}</c:marker>'
      '${trend ? '<c:trendline><c:spPr><a:ln w="19050"><a:solidFill><a:srgbClr val="$color"/></a:solidFill></a:ln></c:spPr><c:trendlineType val="linear"/><c:dispRSqr val="1"/><c:dispEq val="1"/><c:trendlineLbl><c:numFmt formatCode="General" sourceLinked="0"/></c:trendlineLbl></c:trendline>' : ''}'
      '<c:xVal>${_numRef(sheet, 'B', r1, r2, xs)}</c:xVal><c:yVal>${_numRef(sheet, yCol, r1, r2, yv)}</c:yVal><c:smooth val="0"/></c:ser>';
  String axis(int id, int cross, String pos, String t, {required bool grid}) =>
      '<c:valAx><c:axId val="$id"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="$pos"/>'
      '${grid ? '<c:majorGridlines><c:spPr><a:ln w="6350"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill></a:ln></c:spPr></c:majorGridlines>' : ''}'
      '${_richTitle(t, 1000)}<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="out"/><c:minorTickMark val="none"/><c:tickLblPos val="low"/>'
      '<c:crossAx val="$cross"/><c:crosses val="autoZero"/><c:crossBetween val="midCat"/></c:valAx>';
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<c:roundedCorners val="0"/>
<c:chart>${_richTitle(title)}<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>
<c:scatterChart><c:scatterStyle val="lineMarker"/><c:varyColors val="0"/>
${ser(0, yName, 'C', ys, '0E4F7A', trend: true, line: false)}${extra == null ? '' : ser(1, extra.$1, extra.$2, extra.$3, 'D97706', trend: false, line: true)}
<c:axId val="500000001"/><c:axId val="500000002"/></c:scatterChart>
${axis(500000001, 500000002, 'b', xTitle, grid: false)}${axis(500000002, 500000001, 'l', yTitle, grid: true)}
</c:plotArea><c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend><c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>
</c:chartSpace>''';
}

String _drawingXml(int n) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<xdr:twoCellAnchor><xdr:from><xdr:col>8</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>17</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
<xdr:to><xdr:col>17</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>37</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${n + 1}" name="Graphique $n"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>
<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">
<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId1"/>
</a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor></xdr:wsDr>''';

String _rels(List<(String, String, String)> items) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${items.map((e) => '<Relationship Id="${e.$1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/${e.$2}" Target="${e.$3}"/>').join()}</Relationships>';

const _styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="0.000######"/></numFmts>
<fonts count="4"><font><sz val="11"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="14"/><color rgb="FF0B3D5C"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font></fonts>
<fills count="5"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0E4F7A"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF7D6"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE6F1F8"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FFC8D3DF"/></left><right style="thin"><color rgb="FFC8D3DF"/></right><top style="thin"><color rgb="FFC8D3DF"/></top><bottom style="thin"><color rgb="FFC8D3DF"/></bottom><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="8">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="164" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"/>
<xf numFmtId="164" fontId="0" fillId="4" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"/>
<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';

// ---------- Feuilles ----------
const _r0 = 10, _first = 11; // ligne d'en-tête du tableau ; première ligne de données

(String, String) _sheet(bool unc, Analysis a, Meta meta, UncType uncType, bool kVerified) {
  final pts = a.pts, n = pts.length, r1 = _first, r2 = _first + n - 1;
  final model = unc ? a.u : a.c;
  final ys = [for (final p in pts) unc ? p.u : p.c];
  final uI = meta.unitI;
  final uY = unc ? (uncType == UncType.relative ? meta.unitI : meta.unitU) : meta.unitC;
  final cells = <String, _Cell>{};
  void put(String ref, Object? v, [int s = 0, String? f]) => cells[ref] = _Cell(v, s, f);
  String or(String v) => v.isEmpty ? '-' : v;

  put('A1', unc ? "Modélisation de l'incertitude : U = a·I + b" : 'Interpolation de la correction : C = a·I + b', _title);
  final nature = switch (meta.nature) { 'U' => 'élargie U', 'u' => 'type u', _ => 'inconnue' };
  final head = [
    ('N° de certificat', meta.certificate),
    ('Laboratoire', meta.lab),
    ("Date d'étalonnage", meta.date),
    ('Instrument', meta.instrument),
    ('Unités', 'Indication : ${or(uI)} ; Correction : ${or(meta.unitC)} ; Incertitude : ${or(uY)}'),
    ("Facteur d'élargissement k", '${or(meta.k)}${kVerified ? '' : ' (à vérifier)'} ; nature : $nature'),
    (
      'Convention',
      unc
          ? 'U prudente = U ajustée + résidu max ; incertitude convertie en absolue si relative (U = U% × |I| / 100)'
          : 'Valeur corrigée = indication + correction ; correction = − erreur'
    ),
  ];
  for (final (i, (k, v)) in head.indexed) {
    put('A${2 + i}', k, _label);
    put('C${2 + i}', or(v));
  }
  final yName = unc ? 'Incertitude U${uY.isEmpty ? '' : ' ($uY)'}' : 'Correction${uY.isEmpty ? '' : ' ($uY)'}';
  final headers = ['N°', 'Indication${uI.isEmpty ? '' : ' ($uI)'}', yName, 'Valeur ajustée = a·x + b', 'Résidu', '|Résidu|', if (unc) 'U prudente'];
  for (final (i, h) in headers.indexed) {
    put('${_col(i)}$_r0', h, _header);
  }
  for (var i = 0; i < n; i++) {
    final r = r1 + i;
    put('A$r', i + 1, _index);
    put('B$r', pts[i].x, _input);
    put('C$r', ys[i], _input);
    put('D$r', model.ajuste[i], _calc, '\$J\$$_first*B$r+\$J\$${_first + 1}');
    put('E$r', model.residu[i], _calc, 'C$r-D$r');
    put('F$r', model.residu[i].abs(), _calc, 'ABS(E$r)');
    if (unc) put('G$r', model.ajuste[i] + model.residuMax, _calc, 'D$r+\$J\$${_first + 4}');
  }
  final y = 'C$r1:C$r2', x = 'B$r1:B$r2';
  put('I$_r0', 'Résultat', _header);
  put('J$_r0', 'Valeur', _header);
  final res = [
    ('a (pente)', model.a, 'SLOPE($y,$x)'),
    ("b (ordonnée à l'origine)", model.b, 'INTERCEPT($y,$x)'),
    ('R²', model.r2, 'RSQ($y,$x)'),
    ('n (points)', n, 'COUNT($x)'),
    ('Résidu max |e|', model.residuMax, 'MAX(F$r1:F$r2)'),
  ];
  for (final (i, (k, v, f)) in res.indexed) {
    put('I${_first + i}', k, _resLabel);
    put('J${_first + i}', v, i == 3 ? _index : _calc, f);
  }
  put('I${_first + 6}',
      'Modification des valeurs existantes : recalcul automatique. Ajout ou suppression de points : régénérer le classeur depuis l’application.');
  final widths = <double>[6, 16, 18, 22, 14, 14, unc ? 14 : 4, 3, 26, 18];
  final chart = _chartXml(
    sheet: unc ? 'Modélisation' : 'Interpolation',
    r1: r1,
    r2: r2,
    xs: [for (final p in pts) p.x],
    ys: ys,
    title: unc ? "Modélisation de l'incertitude" : 'Interpolation de la correction',
    yName: yName,
    xTitle: 'Indication${uI.isEmpty ? '' : ' ($uI)'}',
    yTitle: yName,
    extra: unc ? ('U prudente', 'G', [for (final v in model.ajuste) v + model.residuMax]) : null,
  );
  return (_sheetXml(cells, widths, _r0), chart);
}

Uint8List buildXlsx(Analysis a, Meta meta, {required UncType uncType, required bool kVerified, DateTime? now}) {
  final (s1, c1) = _sheet(false, a, meta, uncType, kVerified);
  final (s2, c2) = _sheet(true, a, meta, uncType, kVerified);
  const ct = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>
<Override PartName="/xl/drawings/drawing2.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>
<Override PartName="/xl/charts/chart1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>
<Override PartName="/xl/charts/chart2.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>
</Types>''';
  const wb = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Interpolation" sheetId="1" r:id="rId1"/><sheet name="Modélisation" sheetId="2" r:id="rId2"/></sheets>
<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>''';
  return _zip([
    ('[Content_Types].xml', ct),
    ('_rels/.rels', _rels([('rId1', 'officeDocument', 'xl/workbook.xml')])),
    ('xl/workbook.xml', wb),
    (
      'xl/_rels/workbook.xml.rels',
      _rels([('rId1', 'worksheet', 'worksheets/sheet1.xml'), ('rId2', 'worksheet', 'worksheets/sheet2.xml'), ('rId3', 'styles', 'styles.xml')])
    ),
    ('xl/styles.xml', _styles),
    ('xl/worksheets/sheet1.xml', s1),
    ('xl/worksheets/sheet2.xml', s2),
    ('xl/worksheets/_rels/sheet1.xml.rels', _rels([('rId1', 'drawing', '../drawings/drawing1.xml')])),
    ('xl/worksheets/_rels/sheet2.xml.rels', _rels([('rId1', 'drawing', '../drawings/drawing2.xml')])),
    ('xl/drawings/drawing1.xml', _drawingXml(1)),
    ('xl/drawings/drawing2.xml', _drawingXml(2)),
    ('xl/drawings/_rels/drawing1.xml.rels', _rels([('rId1', 'chart', '../charts/chart1.xml')])),
    ('xl/drawings/_rels/drawing2.xml.rels', _rels([('rId1', 'chart', '../charts/chart2.xml')])),
    ('xl/charts/chart1.xml', c1),
    ('xl/charts/chart2.xml', c2),
  ], now ?? DateTime.now());
}

/// Nom : `certificat_<n°>_<série>_<date>.xlsx` (caractères sûrs uniquement).
String xlsxFileName(Meta meta) {
  String s(String v) {
    const accents = {'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c'};
    final plain = v.split('').map((c) => accents[c.toLowerCase()] ?? c).join();
    final t = plain.replaceAll(RegExp(r'[^\w\-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return t.length > 40 ? t.substring(0, 40) : t;
  }

  final n = s(meta.certificate), serie = s(meta.instrument), d = s(meta.date);
  return 'certificat_${n.isEmpty ? 'sans-numero' : n}_${serie.isEmpty ? 'serie' : serie}_'
      '${d.isEmpty ? DateTime.now().toIso8601String().substring(0, 10) : d}.xlsx';
}
