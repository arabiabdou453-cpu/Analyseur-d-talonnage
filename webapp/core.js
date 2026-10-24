/* Moteur de calcul de la version web — miroir de core/*.m (MATLAB).
 * Fonctions pures, sans DOM ni texte d'interface : les erreurs portent un code
 * (CoreError.code) traduit par app.js. Testé par tests.html avec les valeurs
 * de référence de tests/TestRegression.m. */
(function (root) {
  'use strict';

  const TOL = 1e-10; // options.toleranceRelative (parametresParDefaut.m)

  class CoreError extends Error {
    constructor(code, params = {}) { super(code); this.code = code; this.params = params; }
  }

  /* normaliserDonnees : virgule décimale, espaces (y compris insécables), moins Unicode, ± (incertitude seulement). */
  function parseNum(raw, allowPlusMinus = false) {
    let s = String(raw ?? '').trim().replace(/[  ]/g, ' ').replace(/[−–]/g, '-');
    if (allowPlusMinus && s.startsWith('±')) s = s.slice(1).trim();
    s = s.replace(/ /g, '');
    if (s.includes(',') && !s.includes('.')) s = s.replace(',', '.');
    if (s === '' || !/^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/.test(s)) return NaN;
    return Number(s);
  }

  /* ajusterDroite : OLS centrée y = a·x + b (pas d'inversion de matrice). */
  function ajusterDroite(x, y) {
    const n = x.length;
    if (n < 3 || n !== y.length || ![...x, ...y].every(Number.isFinite)) throw new CoreError('fitInput');
    const xc = x.reduce((s, v) => s + v, 0) / n, yc = y.reduce((s, v) => s + v, 0) / n;
    const dx = x.map(v => v - xc), dy = y.map(v => v - yc);
    const Sxx = dx.reduce((s, v) => s + v * v, 0);
    const scale = Math.max(...x.map(Math.abs), 1);
    if (Sxx <= (Number.EPSILON * scale) ** 2 * n) throw new CoreError('range');
    const a = dx.reduce((s, v, i) => s + v * dy[i], 0) / Sxx, b = yc - a * xc;
    const ajuste = x.map(v => a * v + b), residu = y.map((v, i) => v - ajuste[i]);
    const SSE = residu.reduce((s, r) => s + r * r, 0), SST = dy.reduce((s, v) => s + v * v, 0);
    const constant = SST <= TOL * Math.max(1, y.reduce((s, v) => s + v * v, 0));
    return {
      a, b, x: x.slice(), mesure: y.slice(), ajuste, residu, residuMax: Math.max(...residu.map(Math.abs)),
      SSE, SST, R2: constant ? NaN : 1 - SSE / SST, sRes: Math.sqrt(SSE / (n - 2)), n, constant,
    };
  }

  /* evaluerCritere : e_max <= seuil avec tolérance numérique documentée. */
  function evaluerCritere(model, seuil) {
    if (!Number.isFinite(seuil) || seuil < 0) throw new CoreError('threshold');
    const tol = TOL * Math.max(1, Math.abs(seuil), model.residuMax);
    let r2 = 'r2.ok';
    if (model.constant) r2 = 'r2.undef'; else if (model.R2 < 0.5) r2 = 'r2.low';
    return { ok: model.residuMax <= seuil + tol, seuil, tol, r2 };
  }

  /* validerDonnees : rows = [[I, C, U] en texte], settings = {mode, alphaC, alphaU, limitC, limitU}. */
  function valider(rows, settings, meta = {}) {
    const errors = [], warnings = [];
    const pts = rows.map((r, i) => {
      const v = r.map((s, j) => parseNum(s, j === 2));
      v.forEach((val, j) => { if (!Number.isFinite(val)) errors.push({ code: 'nan', params: { row: i + 1, col: j }, cell: [i, j] }); });
      if (v[2] < 0) errors.push({ code: 'negU', params: { row: i + 1 }, cell: [i, 2] });
      return { x: v[0], c: v[1], u: v[2] };
    });
    if (pts.length < 3) errors.unshift({ code: 'minPoints', params: {} });
    if (!errors.length) {
      for (let i = 0; i < pts.length; i++) {
        const j = pts.findIndex((p, k) => k > i && p.x === pts[i].x);
        if (j > -1) { errors.push({ code: 'dup', params: { a: i + 1, b: j + 1 } }); break; }
      }
      const xs = pts.map(p => p.x);
      const e = Math.max(...xs) - Math.min(...xs);
      if (e === 0 || e <= Number.EPSILON * Math.max(...xs.map(Math.abs), 1) * Math.max(1, pts.length)) errors.push({ code: 'range', params: {} });
    }
    let sC = NaN, sU = NaN;
    if (!errors.length) {
      const meanU = pts.reduce((s, p) => s + p.u, 0) / pts.length;
      if (settings.mode === 'absolute') {
        sC = parseNum(settings.limitC); sU = parseNum(settings.limitU);
      } else {
        const aC = parseNum(settings.alphaC), aU = parseNum(settings.alphaU);
        if (![aC, aU].every(v => Number.isFinite(v) && v >= 0)) errors.push({ code: 'threshold', params: {} });
        sC = aC * meanU; sU = aU * meanU;
      }
      if (![sC, sU].every(v => Number.isFinite(v) && v >= 0) && !errors.some(e2 => e2.code === 'threshold')) errors.push({ code: 'threshold', params: {} });
    }
    if (!errors.length) {
      if (pts.some(p => p.u === 0)) warnings.push('warn.zeroU');
      if (pts.length === 3) warnings.push('warn.three');
      if (meta.unitI && meta.unitC && meta.unitI.trim() !== meta.unitC.trim()) warnings.push('warn.units');
    }
    const needsSort = !errors.length && pts.some((p, i) => i && p.x <= pts[i - 1].x);
    return { errors, warnings, pts, sC, sU, needsSort };
  }

  /* analyserEtalonnage : pts triés par indication croissante. */
  function analyser(pts, sC, sU) {
    if (pts.some((p, i) => i && p.x <= pts[i - 1].x)) throw new CoreError('notSorted');
    const x = pts.map(p => p.x);
    const c = ajusterDroite(x, pts.map(p => p.c)), u = ajusterDroite(x, pts.map(p => p.u));
    const lo = x[0], hi = x[x.length - 1];
    const maj = { a: u.a, b: u.b + u.residuMax };
    maj.bornes = [lo, hi].map(v => maj.a * v + maj.b);
    maj.usable = maj.bornes.every(v => v >= -TOL * Math.max(1, ...pts.map(p => Math.abs(p.u))));
    return { pts, c, u, maj, lo, hi, sC, sU, decC: evaluerCritere(c, sC), decU: evaluerCritere(u, sU) };
  }

  /* interp1 linéaire de la correction, strictement dans l'étendue. */
  function interpolation(x, pts) {
    if (!(x >= pts[0].x && x <= pts[pts.length - 1].x)) throw new CoreError('outOfRange');
    for (let i = 1; i < pts.length; i++) {
      if (x <= pts[i].x) {
        const l = pts[i - 1], r = pts[i];
        return l.c + (x - l.x) * (r.c - l.c) / (r.x - l.x);
      }
    }
    return pts[pts.length - 1].c;
  }

  /* calculerResultat : même ordre de contrôles que la version MATLAB. */
  function calculer(A, meta, xRaw, methodC, methodU, confirmed) {
    if (!confirmed) throw new CoreError('confirm');
    const x = typeof xRaw === 'number' ? xRaw : parseNum(xRaw);
    if (!Number.isFinite(x)) throw new CoreError('input');
    if (x < A.lo || x > A.hi) throw new CoreError('outOfRange', { lo: A.lo, hi: A.hi });
    let C;
    if (methodC === 'regression') C = A.c.a * x + A.c.b;
    else if (methodC === 'interpolation') C = interpolation(x, A.pts);
    else throw new CoreError('method');
    if (!A.maj.usable) throw new CoreError('majorant');
    let model;
    if (methodU === 'majorant') model = A.maj; else if (methodU === 'fitted') model = A.u; else throw new CoreError('method');
    const U = model.a * x + model.b;
    const bornes = [A.lo, A.hi].map(v => model.a * v + model.b);
    if (!Number.isFinite(U) || U < 0 || bornes.some(v => v < 0)) throw new CoreError('negModel');
    if (!meta.nature) throw new CoreError('nature');
    if (meta.unitI && meta.unitI.trim() !== (meta.unitC || '').trim()) throw new CoreError('unitsCalc');
    return { x, C, corrected: x + C, U, methodC, methodU, nature: meta.nature };
  }

  /* Ligne de résultat d'un certificat : nombres avant ±U (ordre des colonnes du PDF).
   * Convention : Erreur = indication − référence ; Correction = −Erreur.
   * Une ligne sans erreur imprimée ou incohérente est signalée (ok = false), jamais corrigée en silence. */
  function ligneCertificat(nums, U) {
    if (nums.length >= 3) {
      const [a, b, c] = nums.slice(-3), tol = Math.max(0.03, Math.abs(c) * 0.15);
      if (Math.abs(b - a - c) <= tol) return { ref: a, eq: b, err: c, ok: true };
      if (Math.abs(a - b - c) <= tol) return { ref: b, eq: a, err: c, ok: true };
      return { ref: a, eq: b, err: c, ok: false };
    }
    const [a, b] = nums;
    return { ref: a, eq: b, err: b - a, ok: false, recalcule: true };
  }

  root.EtalonnageCore = Object.freeze({
    TOL, CoreError, parseNum, ajusterDroite, evaluerCritere, valider, analyser, interpolation, calculer, ligneCertificat,
  });
})(typeof window !== 'undefined' ? window : globalThis);
