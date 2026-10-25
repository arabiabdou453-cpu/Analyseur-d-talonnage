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
    // n = 2 accepté (droite exacte, résidu nul, non représentatif : averti par valider) ; n < 2 impossible.
    if (n < 2 || n !== y.length || ![...x, ...y].every(Number.isFinite)) throw new CoreError('fitInput');
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
      // s_res = √(SSE/(n−2)) : non défini pour n = 2 (aucun degré de liberté).
      SSE, SST, R2: constant ? NaN : 1 - SSE / SST, sRes: n > 2 ? Math.sqrt(SSE / (n - 2)) : NaN, n, constant,
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

  /* validerDonnees : rows = [[I, C, U] en texte],
   * settings = {mode, alphaC, alphaU, limitC, limitU, uncType: 'absolute' | 'relative'}.
   * Incertitude relative (% de la lecture) : U_abs = U% × |I| / 100, calculée avant la
   * régression ; la valeur d'origine est conservée dans uRaw. */
  function valider(rows, settings, meta = {}) {
    const errors = [], warnings = [];
    const relative = settings.uncType === 'relative';
    const pts = rows.map((r, i) => {
      const v = r.map((s, j) => parseNum(s, j === 2));
      v.forEach((val, j) => { if (!Number.isFinite(val)) errors.push({ code: 'nan', params: { row: i + 1, col: j }, cell: [i, j] }); });
      if (v[2] < 0) errors.push({ code: 'negU', params: { row: i + 1 }, cell: [i, 2] });
      const u = relative ? v[2] * Math.abs(v[0]) / 100 : v[2];
      return { x: v[0], c: v[1], u, uRaw: v[2] };
    });
    if (pts.length < 2) errors.unshift({ code: 'minPoints', params: {} });
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
      if (pts.length === 2) warnings.push('warn.two');
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

  /* calculerResultat : même ordre de contrôles que la version MATLAB.
   *   Correction  C(I)  = a_C · I + b_C            (ou interpolation point par point, au choix explicite)
   *   Valeur corrigée   = I + C(I)
   *   U modélisée U(I)  = a_U · I + b_U
   *   U prudente  Up(I) = U(I) + résidu max de la modélisation  (recommandée ; = droite majorante)
   * Sécurité : hors étendue, U prudente négative, nature inconnue ou unités incompatibles → bloqué.
   * Une U modélisée négative n'est jamais remplacée par 0 : elle est signalée « non exploitable ». */
  function calculer(A, meta, xRaw, methodC, confirmed) {
    if (!confirmed) throw new CoreError('confirm');
    const x = typeof xRaw === 'number' ? xRaw : parseNum(xRaw);
    if (!Number.isFinite(x)) throw new CoreError('input');
    if (x < A.lo || x > A.hi) throw new CoreError('outOfRange', { lo: A.lo, hi: A.hi });
    let C;
    if (methodC === 'regression') C = A.c.a * x + A.c.b;
    else if (methodC === 'interpolation') C = interpolation(x, A.pts);
    else throw new CoreError('method');
    if (!A.maj.usable) throw new CoreError('majorant');
    const uPrudent = A.maj.a * x + A.maj.b;
    if (!Number.isFinite(uPrudent) || uPrudent < 0) throw new CoreError('negModel');
    const uFit = A.u.a * x + A.u.b;
    const uFitOk = Number.isFinite(uFit) && uFit >= 0 && [A.lo, A.hi].every(v => A.u.a * v + A.u.b >= 0);
    if (!meta.nature) throw new CoreError('nature');
    if (meta.unitI && meta.unitI.trim() !== (meta.unitC || '').trim()) throw new CoreError('unitsCalc');
    return { x, C, corrected: x + C, uFit, uFitOk, uPrudent, U: uPrudent, methodC, nature: meta.nature, k: meta.k || '' };
  }

  /* Alerte de linéarité : le résidu max de la correction dépasse la plus petite incertitude
   * du certificat (comparaison seulement si les unités sont identiques). */
  function alerteLinearite(A, meta = {}) {
    const unitU = meta.uncType === 'relative' ? (meta.unitI || '') : (meta.unitU || '');
    if ((meta.unitC || '').trim() !== unitU.trim()) return false;
    return A.c.residuMax > Math.min(...A.pts.map(p => p.u));
  }

  /* Affichage : incertitude à 2 chiffres significatifs arrondie VERS LE HAUT (jamais sous-estimée) ;
   * la correction et la valeur corrigée sont affichées avec le même nombre de décimales.
   * Les valeurs stockées ne sont jamais arrondies. */
  function arrondirIncertitude(u) {
    if (!Number.isFinite(u) || u <= 0) return { value: u, decimals: 2 };
    const p = 1 - Math.floor(Math.log10(u)); // position du 2e chiffre significatif
    const f = 10 ** p;
    // Tolérance relative 1e-9 : 0,08 (= 8,000000000000002 × 10⁻²) reste 0,08 et ne passe pas à 0,09.
    const value = Math.ceil(u * f * (1 - 1e-9)) / f;
    return { value: p < 0 ? Math.round(value) : value, decimals: Math.max(0, p) };
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
    alerteLinearite, arrondirIncertitude,
  });
})(typeof window !== 'undefined' ? window : globalThis);
