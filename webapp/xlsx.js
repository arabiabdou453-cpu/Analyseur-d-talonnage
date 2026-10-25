/* Classeur Excel à deux feuilles (« Interpolation », « Modélisation »), écrit sans
 * bibliothèque : XML Office Open + archive ZIP (méthode « stockée »).
 * Tous les résultats sont de VRAIES formules Excel (noms anglais, Excel les traduit) :
 *   a = SLOPE(y,x), b = INTERCEPT(y,x), R² = RSQ(y,x), n = COUNT(x), résidu max = MAX(|résidu|),
 *   valeur ajustée = a·x + b, résidu = y − ajustée, U prudente = ajustée + résidu max.
 * Chaque formule porte aussi sa valeur calculée en cache (<v>) pour les aperçus (téléphone,
 * visionneuses) ; Excel recalcule à l'ouverture (fullCalcOnLoad). Les valeurs ne sont jamais
 * arrondies : seul le format d'affichage limite les décimales. */
(function (root) {
  'use strict';

  const enc = new TextEncoder();
  const xmlEsc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' }[c]))
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');
  const col = i => String.fromCharCode(65 + i); // A..Z suffisent ici

  /* ---------- ZIP (stocké, sans compression) ---------- */
  const CRC = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
    return t;
  })();
  function crc32(b) { let c = 0xffffffff; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
  function zip(files) {
    const chunks = [], central = [];
    let offset = 0;
    const d = new Date(), dosTime = (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1);
    const dosDate = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
    for (const [name, text] of files) {
      const data = typeof text === 'string' ? enc.encode(text) : text, nm = enc.encode(name), crc = crc32(data);
      const h = new DataView(new ArrayBuffer(30));
      h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x0800, true); h.setUint16(8, 0, true);
      h.setUint16(10, dosTime, true); h.setUint16(12, dosDate, true); h.setUint32(14, crc, true);
      h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, nm.length, true); h.setUint16(28, 0, true);
      chunks.push(new Uint8Array(h.buffer), nm, data);
      const c = new DataView(new ArrayBuffer(46));
      c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint16(8, 0x0800, true);
      c.setUint16(10, 0, true); c.setUint16(12, dosTime, true); c.setUint16(14, dosDate, true); c.setUint32(16, crc, true);
      c.setUint32(20, data.length, true); c.setUint32(24, data.length, true); c.setUint16(28, nm.length, true);
      c.setUint32(42, offset, true);
      central.push(new Uint8Array(c.buffer), nm);
      offset += 30 + nm.length + data.length;
    }
    const cdSize = central.reduce((s, b) => s + b.length, 0);
    const e = new DataView(new ArrayBuffer(22));
    e.setUint32(0, 0x06054b50, true); e.setUint16(8, files.length, true); e.setUint16(10, files.length, true);
    e.setUint32(12, cdSize, true); e.setUint32(16, offset, true);
    const all = [...chunks, ...central, new Uint8Array(e.buffer)];
    const out = new Uint8Array(all.reduce((s, b) => s + b.length, 0));
    let p = 0; for (const b of all) { out.set(b, p); p += b.length; }
    return out;
  }

  /* ---------- Cellules ---------- */
  const S = { header: 1, title: 2, label: 3, input: 4, calc: 5, index: 6, resLabel: 7 };
  const num = v => (Number.isFinite(v) ? String(v) : null);
  function cellXml(ref, c) {
    if (c.f) {
      const v = num(c.v);
      return v === null
        ? `<c r="${ref}" s="${c.s || 0}" t="e"><f>${xmlEsc(c.f)}</f><v>#DIV/0!</v></c>`
        : `<c r="${ref}" s="${c.s || 0}"><f>${xmlEsc(c.f)}</f><v>${v}</v></c>`;
    }
    if (typeof c.v === 'number') return num(c.v) === null ? '' : `<c r="${ref}" s="${c.s || 0}"><v>${num(c.v)}</v></c>`;
    return `<c r="${ref}" s="${c.s || 0}" t="inlineStr"><is><t xml:space="preserve">${xmlEsc(c.v)}</t></is></c>`;
  }
  function sheetXml(cells, widths, freezeRow, hasDrawing) {
    const rows = new Map();
    for (const [ref, c] of Object.entries(cells)) {
      const m = /^([A-Z])(\d+)$/.exec(ref), r = +m[2];
      if (!rows.has(r)) rows.set(r, []);
      rows.get(r).push([m[1], ref, c]);
    }
    const data = [...rows.keys()].sort((a, b) => a - b).map(r =>
      `<row r="${r}">${rows.get(r).sort((a, b) => a[0].localeCompare(b[0])).map(([, ref, c]) => cellXml(ref, c)).join('')}</row>`).join('');
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>
<sheetViews><sheetView workbookViewId="0"><pane ySplit="${freezeRow}" topLeftCell="A${freezeRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
<sheetFormatPr defaultRowHeight="15"/>
<cols>${widths.map((w, i) => `<col min="${i + 1}" max="${i + 1}" width="${w}" customWidth="1"/>`).join('')}</cols>
<sheetData>${data}</sheetData>
<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>
<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>
${hasDrawing ? '<drawing r:id="rId1"/>' : ''}
</worksheet>`;
  }

  /* ---------- Graphique XY + courbe de tendance linéaire ---------- */
  function richTitle(text, size = 1200) {
    return `<c:title><c:tx><c:rich><a:bodyPr/><a:p><a:pPr><a:defRPr sz="${size}" b="1"/></a:pPr><a:r><a:rPr lang="fr-FR" sz="${size}" b="1"/><a:t>${xmlEsc(text)}</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>`;
  }
  function numRef(sheet, colL, r1, r2, values) {
    return `<c:numRef><c:f>'${sheet}'!$${colL}$${r1}:$${colL}$${r2}</c:f><c:numCache><c:formatCode>General</c:formatCode><c:ptCount val="${values.length}"/>${values.map((v, i) => (Number.isFinite(v) ? `<c:pt idx="${i}"><c:v>${v}</c:v></c:pt>` : '')).join('')}</c:numCache></c:numRef>`;
  }
  function chartXml(o) {
    const ser = (idx, name, yCol, ys, color, withTrend, asLine) => `<c:ser><c:idx val="${idx}"/><c:order val="${idx}"/><c:tx><c:v>${xmlEsc(name)}</c:v></c:tx>
<c:spPr>${asLine ? `<a:ln w="22225"><a:solidFill><a:srgbClr val="${color}"/></a:solidFill><a:prstDash val="dash"/></a:ln>` : '<a:ln w="19050"><a:noFill/></a:ln>'}</c:spPr>
<c:marker>${asLine ? '<c:symbol val="none"/>' : `<c:symbol val="circle"/><c:size val="7"/><c:spPr><a:solidFill><a:srgbClr val="${color}"/></a:solidFill></c:spPr>`}</c:marker>
${withTrend ? `<c:trendline><c:spPr><a:ln w="19050"><a:solidFill><a:srgbClr val="${color}"/></a:solidFill></a:ln></c:spPr><c:trendlineType val="linear"/><c:dispRSqr val="1"/><c:dispEq val="1"/><c:trendlineLbl><c:numFmt formatCode="General" sourceLinked="0"/></c:trendlineLbl></c:trendline>` : ''}
<c:xVal>${numRef(o.sheet, 'B', o.r1, o.r2, o.xs)}</c:xVal><c:yVal>${numRef(o.sheet, yCol, o.r1, o.r2, ys)}</c:yVal><c:smooth val="0"/></c:ser>`;
    const axis = (id, cross, pos, title, grid) => `<c:valAx><c:axId val="${id}"/><c:scaling><c:orientation val="minMax"/></c:scaling><c:delete val="0"/><c:axPos val="${pos}"/>${grid ? '<c:majorGridlines><c:spPr><a:ln w="6350"><a:solidFill><a:srgbClr val="E2E8F0"/></a:solidFill></a:ln></c:spPr></c:majorGridlines>' : ''}${richTitle(title, 1000)}<c:numFmt formatCode="General" sourceLinked="0"/><c:majorTickMark val="out"/><c:minorTickMark val="none"/><c:tickLblPos val="low"/><c:crossAx val="${cross}"/><c:crosses val="autoZero"/><c:crossBetween val="midCat"/></c:valAx>`;
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<c:roundedCorners val="0"/>
<c:chart>${richTitle(o.title)}<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>
<c:scatterChart><c:scatterStyle val="lineMarker"/><c:varyColors val="0"/>
${ser(0, o.yName, 'C', o.ys, '0E4F7A', true, false)}${o.extra ? ser(1, o.extra.name, o.extra.col, o.extra.ys, 'D97706', false, true) : ''}
<c:axId val="500000001"/><c:axId val="500000002"/></c:scatterChart>
${axis(500000001, 500000002, 'b', o.xTitle, false)}${axis(500000002, 500000001, 'l', o.yTitle, true)}
</c:plotArea><c:legend><c:legendPos val="b"/><c:overlay val="0"/></c:legend><c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>
</c:chartSpace>`;
  }
  const drawingXml = n => `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<xdr:twoCellAnchor><xdr:from><xdr:col>8</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>17</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
<xdr:to><xdr:col>17</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>37</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>
<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${n + 1}" name="Graphique ${n}"/><xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>
<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">
<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId1"/>
</a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor></xdr:wsDr>`;
  const rels = items => `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${items.map(([id, type, target]) =>
    `<Relationship Id="${id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/${type}" Target="${target}"/>`).join('')}</Relationships>`;

  const STYLES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
</styleSheet>`;

  /* ---------- Feuilles ---------- */
  const R0 = 10, FIRST = 11; // ligne d'en-tête du tableau ; première ligne de données

  function buildSheet(kind, A, meta, opts) {
    const unc = kind === 'U';
    const pts = A.pts, n = pts.length, r1 = FIRST, r2 = FIRST + n - 1;
    const model = unc ? A.u : A.c;
    const ys = pts.map(p => (unc ? p.u : p.c));
    const uI = meta.unitI || '', uY = unc ? (meta.uncType === 'relative' ? meta.unitI : meta.unitU) || '' : meta.unitC || '';
    const cells = {};
    const put = (ref, v, s = 0, f) => { cells[ref] = { v, s, f }; };
    put('A1', unc ? "Modélisation de l'incertitude : U = a·I + b" : 'Interpolation de la correction : C = a·I + b', S.title);
    const head = [
      ['N° de certificat', meta.certificate], ['Laboratoire', meta.lab], ["Date d'étalonnage", meta.date],
      ['Instrument', meta.instrument],
      ['Unités', `Indication : ${uI || '-'} ; Correction : ${meta.unitC || '-'} ; Incertitude : ${uY || '-'}`],
      ["Facteur d'élargissement k", `${meta.k || '-'}${opts.kVerified ? '' : ' (à vérifier)'} ; nature : ${meta.nature === 'U' ? 'élargie U' : meta.nature === 'u' ? 'type u' : 'inconnue'}`],
      ['Convention', unc ? 'U prudente = U ajustée + résidu max ; incertitude convertie en absolue si relative (U = U% × |I| / 100)'
        : 'Valeur corrigée = indication + correction ; correction = − erreur'],
    ];
    head.forEach(([k, v], i) => { put(`A${2 + i}`, k, S.label); put(`C${2 + i}`, v || '-'); });
    const yName = unc ? `Incertitude U${uY ? ` (${uY})` : ''}` : `Correction${uY ? ` (${uY})` : ''}`;
    const headers = ['N°', `Indication${uI ? ` (${uI})` : ''}`, yName, 'Valeur ajustée = a·x + b', 'Résidu', '|Résidu|'];
    if (unc) headers.push('U prudente');
    headers.forEach((h, i) => put(`${col(i)}${R0}`, h, S.header));
    pts.forEach((p, i) => {
      const r = r1 + i;
      put(`A${r}`, i + 1, S.index);
      put(`B${r}`, p.x, S.input);
      put(`C${r}`, ys[i], S.input);
      put(`D${r}`, model.ajuste[i], S.calc, `$J$${FIRST}*B${r}+$J$${FIRST + 1}`);
      put(`E${r}`, model.residu[i], S.calc, `C${r}-D${r}`);
      put(`F${r}`, Math.abs(model.residu[i]), S.calc, `ABS(E${r})`);
      if (unc) put(`G${r}`, model.ajuste[i] + model.residuMax, S.calc, `D${r}+$J$${FIRST + 4}`);
    });
    const y = `C${r1}:C${r2}`, x = `B${r1}:B${r2}`;
    put(`I${R0}`, 'Résultat', S.header); put(`J${R0}`, 'Valeur', S.header);
    const res = [
      ['a (pente)', model.a, `SLOPE(${y},${x})`],
      ["b (ordonnée à l'origine)", model.b, `INTERCEPT(${y},${x})`],
      ['R²', model.R2, `RSQ(${y},${x})`],
      ['n (points)', n, `COUNT(${x})`],
      ['Résidu max |e|', model.residuMax, `MAX(F${r1}:F${r2})`],
    ];
    res.forEach(([k, v, f], i) => { put(`I${FIRST + i}`, k, S.resLabel); put(`J${FIRST + i}`, v, i === 3 ? S.index : S.calc, f); });
    put(`I${FIRST + 6}`, 'Modification des valeurs existantes : recalcul automatique. Ajout ou suppression de points : régénérer le classeur depuis l’application.');
    const widths = [6, 16, 18, 22, 14, 14, unc ? 14 : 4, 3, 26, 18];
    const chart = chartXml({
      sheet: unc ? 'Modélisation' : 'Interpolation', r1, r2, xs: pts.map(p => p.x), ys,
      title: unc ? "Modélisation de l'incertitude" : 'Interpolation de la correction', yName,
      xTitle: `Indication${uI ? ` (${uI})` : ''}`, yTitle: yName,
      extra: unc ? { name: 'U prudente', col: 'G', ys: model.ajuste.map(v => v + model.residuMax) } : null,
    });
    return { xml: sheetXml(cells, widths, R0, true), chart };
  }

  function build(A, meta, opts = {}) {
    const s1 = buildSheet('C', A, meta, opts), s2 = buildSheet('U', A, meta, opts);
    const ct = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
</Types>`;
    const wb = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Interpolation" sheetId="1" r:id="rId1"/><sheet name="Modélisation" sheetId="2" r:id="rId2"/></sheets>
<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>`;
    return zip([
      ['[Content_Types].xml', ct],
      ['_rels/.rels', rels([['rId1', 'officeDocument', 'xl/workbook.xml']])],
      ['xl/workbook.xml', wb],
      ['xl/_rels/workbook.xml.rels', rels([['rId1', 'worksheet', 'worksheets/sheet1.xml'], ['rId2', 'worksheet', 'worksheets/sheet2.xml'], ['rId3', 'styles', 'styles.xml']])],
      ['xl/styles.xml', STYLES],
      ['xl/worksheets/sheet1.xml', s1.xml],
      ['xl/worksheets/sheet2.xml', s2.xml],
      ['xl/worksheets/_rels/sheet1.xml.rels', rels([['rId1', 'drawing', '../drawings/drawing1.xml']])],
      ['xl/worksheets/_rels/sheet2.xml.rels', rels([['rId1', 'drawing', '../drawings/drawing2.xml']])],
      ['xl/drawings/drawing1.xml', drawingXml(1)],
      ['xl/drawings/drawing2.xml', drawingXml(2)],
      ['xl/drawings/_rels/drawing1.xml.rels', rels([['rId1', 'chart', '../charts/chart1.xml']])],
      ['xl/drawings/_rels/drawing2.xml.rels', rels([['rId1', 'chart', '../charts/chart2.xml']])],
      ['xl/charts/chart1.xml', s1.chart],
      ['xl/charts/chart2.xml', s2.chart],
    ]);
  }

  /* Nom : certificat_<n°>_<série>_<date>.xlsx (caractères sûrs uniquement). */
  function fileName(meta) {
    const s = v => String(v || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^\w\-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40);
    return `certificat_${s(meta.certificate) || 'sans-numero'}_${s(meta.instrument) || 'serie'}_${s(meta.date) || new Date().toISOString().slice(0, 10)}.xlsx`;
  }

  /* Lecture des parties d'un ZIP stocké (utilisée par les tests). */
  function unzipStored(bytes) {
    const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength), dec = new TextDecoder(), out = {};
    let p = 0;
    while (p + 30 <= bytes.length && dv.getUint32(p, true) === 0x04034b50) {
      const size = dv.getUint32(p + 18, true), nl = dv.getUint16(p + 26, true), xl = dv.getUint16(p + 28, true);
      const name = dec.decode(bytes.subarray(p + 30, p + 30 + nl)), start = p + 30 + nl + xl;
      out[name] = dec.decode(bytes.subarray(start, start + size));
      p = start + size;
    }
    return out;
  }

  root.EtalonnageXlsx = Object.freeze({ build, fileName, unzipStored, crc32 });
})(typeof window !== 'undefined' ? window : globalThis);
