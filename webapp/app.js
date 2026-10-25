/* Analyseur d'étalonnage — version web.
 * Reproduit la logique de core/ (ajusterDroite, validerDonnees, analyserEtalonnage,
 * evaluerCritere, calculerResultat). Tout s'exécute dans le navigateur. */
(() => {
  'use strict';

  const TOL = window.EtalonnageCore.TOL; // options.toleranceRelative
  const STORE = 'etalonnage.v1';

  /* ---------- i18n ---------- */
  const I18N = {
    ar: {
      'app.title': 'محلل المعايرة',
      'app.subtitle': 'تحليل شهادات المعايرة · نماذج التصحيح وعدم اليقين',
      'tab.data': 'البيانات', 'tab.analysis': 'التحليل', 'tab.calc': 'الحاسبة', 'tab.report': 'التقرير',
      'theme': 'تبديل المظهر',
      'data.h': 'بيانات الشهادة', 'data.p': 'أدخل نقاط المعايرة كما وردت في الشهادة، ثم حدّد معايير القبول.',
      'points.title': 'نقاط المعايرة', 'points.sub': 'الإشارة · التصحيح · عدم اليقين',
      'points.hint': 'يمكنك لصق جدول من Excel مباشرة، أو سحب ملف CSV هنا.',
      'drop': 'أفلت ملف CSV هنا',
      'col.indication': 'الإشارة', 'col.correction': 'التصحيح', 'col.uncertainty': 'عدم اليقين',
      'col.fitC': 'C ملائم', 'col.resC': 'باقي C', 'col.fitU': 'U ملائم', 'col.resU': 'باقي U',
      'btn.example': 'مثال', 'btn.import': 'استيراد CSV', 'btn.clear': 'مسح', 'btn.addRow': 'إضافة نقطة',
      'btn.analyze': 'تحليل البيانات', 'btn.saveSession': 'حفظ الجلسة', 'btn.loadSession': 'فتح جلسة',
      'btn.calculate': 'احسب النتيجة', 'btn.exportCsv': 'تصدير CSV', 'btn.print': 'طباعة / PDF',
      'btn.goData': 'الانتقال إلى البيانات', 'btn.goAnalysis': 'عرض التحليل', 'btn.delRow': 'حذف النقطة',
      'meta.title': 'الجهاز والشهادة',
      'f.instrument': 'الجهاز', 'f.certificate': 'رقم الشهادة', 'f.date': 'تاريخ المعايرة', 'f.lab': 'المخبر',
      'f.unitI': 'وحدة الإشارة', 'f.unitC': 'وحدة التصحيح', 'f.unitU': 'وحدة عدم اليقين', 'f.nature': 'طبيعة عدم اليقين',
      'ph.instrument': 'مثال: ميزان حرارة رقمي', 'ph.optional': 'اختياري',
      'nature.unknown': 'غير محددة', 'nature.expanded': 'موسّع U', 'nature.standard': 'معياري u',
      'crit.title': 'معايير القبول',
      'mode.fraction': 'نسبة من متوسط U', 'mode.absolute': 'عتبة مطلقة',
      'f.alphaC': 'نسبة عتبة التصحيح', 'f.alphaU': 'نسبة عتبة عدم اليقين',
      'f.limitC': 'عتبة التصحيح', 'f.limitU': 'عتبة عدم اليقين',
      'crit.helpFraction': 'العتبة = النسبة × متوسط عدم اليقين. يُقبل النموذج إذا كان أكبر باقٍ ≤ العتبة.',
      'crit.helpAbsolute': 'يُقبل النموذج إذا كان أكبر باقٍ مطلق ≤ العتبة المحددة.',
      'sum.points': 'النقاط', 'sum.range': 'المجال', 'sum.meanU': 'متوسط U',
      'an.h': 'نتائج التحليل', 'an.p': 'انحدار خطي (المربعات الصغرى) للتصحيح ولعدم اليقين، مع الخط المحافظ.',
      'an.empty.h': 'لا يوجد تحليل بعد', 'an.empty.p': 'أدخل ثلاث نقاط معايرة على الأقل ثم اضغط «تحليل البيانات».',
      'verdict.ok': 'النموذجان مقبولان حسب معيار البواقي', 'verdict.ko': 'النموذجان غير ممثِّلين حسب معيار البواقي',
      'verdict.mixed': 'نموذج واحد فقط مقبول حسب معيار البواقي',
      'verdict.sub': 'حُلّلت {n} نقاط في المجال {lo} → {hi}. هذا الفحص لا يشكّل وحده مصادقة مترولوجية كاملة.',
      'kpi.points': 'عدد النقاط', 'kpi.range': 'مجال المعايرة', 'kpi.thrC': 'عتبة التصحيح', 'kpi.thrU': 'عتبة عدم اليقين',
      'model.correction': 'الاستيفاء (التصحيح)', 'model.uncertainty': 'النمذجة (عدم اليقين)', 'model.majorant': 'U الحذرة (الخط المحافظ)',
      'st.r2': 'R²', 'st.maxRes': 'أكبر باقٍ', 'st.sres': 's_res', 'st.thr': 'العتبة',
      'dec.ok': 'مقبول', 'dec.ko': 'غير ممثِّل',
      'r2.low': 'R² منخفض: ملاحظة إعلامية فقط، دون قاعدة رفض عامة.', 'r2.undef': 'R² غير معرّف: القيم ثابتة.',
      'r2.ok': 'R² مؤشر وصفي فقط.',
      'maj.note': 'الخط المحافظ = الخط الملائم + أكبر باقٍ ({r}).',
      'chart.measured': 'القيم المقيسة', 'chart.fit': 'الانحدار', 'chart.majorant': 'المحافظ',
      'chart.residuals': 'البواقي', 'chart.residual': 'الباقي', 'chart.threshold': '± العتبة',
      'an.disclaimer': 'العتبات إعدادات أولية ولا تمثل قاعدة معيارية عامة. التفسير المترولوجي النهائي من مسؤولية المختص.',
      'calc.h': 'حاسبة النتيجة', 'calc.p': 'احسب القيمة المصححة وعدم اليقين لإشارة داخل مجال المعايرة فقط.',
      'calc.form': 'المدخلات', 'f.inputI': 'الإشارة المقروءة', 'f.methodC': 'طريقة التصحيح', 'f.methodU': 'نموذج عدم اليقين',
      'method.regression': 'الانحدار الخطي', 'method.interpolation': 'الاستيفاء بين النقاط',
      'method.majorant': 'الخط المحافظ (Majorante)', 'method.fitted': 'الخط الملائم',
      'calc.confirm': 'أؤكد أنني راجعت النموذجين وطريقة الحساب.',
      'calc.result': 'النتيجة', 'calc.corrected': 'القيمة المصححة (I + C)', 'calc.correction': 'التصحيح',
      'calc.indication': 'الإشارة', 'calc.uncertainty': 'عدم اليقين', 'calc.method': 'الطريقة',
      'calc.empty': 'أدخل إشارة: تظهر النتيجة فورًا.',
      'calc.note': 'حساب داخل المجال؛ التفسير المترولوجي يحتاج إلى تأكيد.',
      'calc.history': 'سجل الحسابات', 'calc.historyEmpty': 'لا توجد حسابات بعد.',
      'calc.empty.h': 'الحاسبة غير متاحة', 'calc.empty.p': 'يجب إجراء التحليل أولًا لتفعيل الحاسبة.',
      'rep.h': 'تقرير التحليل', 'rep.p': 'معاينة قابلة للطباعة أو الحفظ بصيغة PDF.',
      'rep.empty.h': 'التقرير غير متاح', 'rep.empty.p': 'أجرِ التحليل لإنشاء التقرير.',
      'rep.title': 'تقرير تحليل المعايرة', 'rep.generated': 'أُنشئ في',
      'rep.meta': 'معلومات الجهاز', 'rep.points': 'نقاط المعايرة والبواقي', 'rep.models': 'النماذج والقرارات',
      'rep.charts': 'الرسوم البيانية', 'rep.calcs': 'الحسابات', 'rep.warnings': 'ملاحظات وتحذيرات',
      'rep.criterion': 'المعيار', 'rep.model': 'النموذج', 'rep.equation': 'المعادلة', 'rep.decision': 'القرار',
      'rep.foot': 'أداة مساعدة: هذا التقرير لا يُعدّ وحده اعتمادًا أو قرارًا مترولوجيًا رسميًا. يجب أن يراجعه مختص.',
      'footer': 'تُجرى جميع العمليات داخل المتصفح؛ لا تُرسل أي بيانات إلى خادم.',
      'none': '—',
      'err.minPoints': 'يلزم إدخال نقطتي معايرة على الأقل.',
      'err.nan': 'النقطة {row}، عمود {col}: قيمة غير رقمية أو فارغة.',
      'err.negU': 'النقطة {row}: عدم اليقين لا يمكن أن يكون سالبًا.',
      'err.dup': 'إشارتان متطابقتان في النقطتين {a} و{b}.',
      'err.range': 'مجال الإشارة معدوم أو ضيق جدًا عدديًا.',
      'err.threshold': 'العتبات والنسب يجب أن تكون أرقامًا غير سالبة.',
      'err.csvEmpty': 'ملف CSV فارغ أو لا يحتوي على نقاط.',
      'err.csvHeader': 'يجب أن يحتوي السطر الأول على الأعمدة Indication وCorrection وIncertitude.',
      'err.csvCols': 'عدد الأعمدة غير صحيح في السطر {line}.',
      'err.csvRead': 'تعذّرت قراءة الملف.', 'err.session': 'ملف الجلسة غير صالح.',
      'err.confirm': 'يرجى تأكيد مراجعة النموذجين قبل الحساب.',
      'err.nature': 'حدّد طبيعة عدم اليقين (U أو u) في بيانات الشهادة قبل عرض نتيجة كاملة.',
      'err.unitsCalc': 'وحدتا الإشارة والتصحيح مختلفتان؛ الحساب I + C محظور دون تحويل موثّق.',
      'err.input': 'أدخل إشارة رقمية صحيحة.',
      'err.outOfRange': 'الإشارة خارج مجال المعايرة [{lo} ، {hi}]؛ لا يُسمح بالاستقراء.',
      'err.majorant': 'نموذج عدم اليقين يعطي قيمة سالبة ضمن المجال ولا يمكن استخدامه.',
      'err.negModel': 'النموذج المختار يعطي عدم يقين سالبًا ضمن المجال أو عند النقطة.',
      'warn.zeroU': 'قيمة أو أكثر من عدم اليقين تساوي صفرًا؛ تحقّق منها.',
      'warn.sorted': 'تم ترتيب النقاط حسب الإشارة بعد موافقتك (كل صف بقي كاملًا).',
      'warn.three': 'ثلاث نقاط فقط: التحقق يبقى محدودًا.',
      'warn.units': 'وحدتا الإشارة والتصحيح مختلفتان: حساب I + C سيكون محظورًا.',
      'warn.majorant': 'الخط المحافظ يعطي قيمًا سالبة ضمن المجال ولا يمكن استخدامه.',
      'toast.saved': 'تم حفظ الجلسة', 'toast.loaded': 'تم فتح الجلسة', 'toast.imported': 'تم استيراد {n} نقاط',
      'toast.pasted': 'تم لصق {n} صفوف', 'toast.analyzed': 'اكتمل التحليل', 'toast.csv': 'تم تصدير الملف',
      'confirm.clear': 'مسح كل النقاط؟',
      'btn.importFile': 'استيراد CSV / PDF', 'btn.cancel': 'إلغاء', 'btn.loadSeries': 'تحميل هذه السلسلة',
      'drop2': 'أفلت ملف CSV أو PDF هنا',
      'pdf.reading': 'جارٍ قراءة الشهادة…',
      'pdf.title': 'جداول الشهادة المستخرجة',
      'pdf.sub': 'وُجدت {n} سلسلة. اختر السلسلة التي تريد تحليلها.',
      'pdf.verify': 'راجع القيم مقابل الشهادة الأصلية قبل التحليل. التصحيح = − الخطأ (المرجع − الجهاز).',
      'pdf.ref': 'المرجع', 'pdf.eq': 'الجهاز', 'pdf.err': 'الخطأ', 'pdf.points': '{n} نقاط',
      'pdf.none': 'لم يُعثر على جدول نتائج (مرجع · جهاز · خطأ · ±U) في هذا الملف.',
      'pdf.scanned': 'لا يحتوي الملف على نص قابل للقراءة (ربما صورة ممسوحة ضوئيًا). أدخل القيم يدويًا.',
      'err.pdfLib': 'تعذّر تحميل قارئ PDF (يلزم اتصال بالإنترنت، أو أن الملف لم يجتز فحص السلامة).',
      'err.tooLarge': 'الملف كبير جدًا (الحد: 20 ميغابايت لـ PDF، 2 ميغابايت لـ CSV/JSON).',
      'err.pdfRead': 'تعذّرت قراءة ملف PDF.',
      'toast.pdf': 'تم تحميل {n} نقاط من الشهادة',
      'series': 'سلسلة',
      'pdf.inconsistent': 'تنبيه: في النقاط المعلَّمة، الخطأ غير مكتوب أو لا يطابق (الجهاز − المرجع). قد تكون الأعمدة مختلطة؛ تحقّق منها في الشهادة.',
      'pdf.confirmInconsistent': 'بعض النقاط غير مؤكَّدة (خطأ غير مطابق أو غير مكتوب). هل تحققت منها يدويًا في الشهادة الأصلية؟',
      'confirm.sort': 'الإشارات غير مرتبة تصاعديًا. ترتيب النقاط (مع إبقاء كل صف كاملًا) ثم التحليل؟',
      'err.notSortedUser': 'لم يتم التحليل: النقاط غير مرتبة. رتّبها أو وافق على الترتيب.',
      'err.notSorted': 'النقاط غير مرتبة حسب الإشارة.', 'err.method': 'طريقة حساب غير معروفة.',
      'err.fitInput': 'يلزم نقطتان حقيقيتان ومنتهيتان على الأقل.',
      'f.k': 'معامل التوسيع k', 'k.verify': 'للتحقق', 'f.uncType': 'نوع عدم اليقين',
      'unc.absolute': 'مطلق', 'unc.relative': 'نسبي (% من القراءة)', 'f.validUntil': 'تاريخ انتهاء الصلاحية (اختياري)',
      'warn.two': 'نقطتان فقط: الخط مضبوط تمامًا والباقي معدوم — النموذج غير ممثِّل.',
      'warn.linearity': 'تنبيه الخطية: أكبر باقٍ للتصحيح يتجاوز أصغر عدم يقين في الشهادة؛ النموذج الخطي لم يعد مهملًا أمام عدم يقين المعايرة.',
      'warn.relative': 'عدم اليقين نسبي: حُوّل إلى قيمة مطلقة U = U% × |I| / 100 قبل الانحدار (القيم الأصلية محفوظة).',
      'warn.kDefault': 'k = 2 قيمة افتراضية غير مأخوذة من الشهادة: تحقّق منها.',
      'calc.heroNote': 'القيمة المصححة ± U الحذرة (k = {k}) · القيمة المصححة = الإشارة + التصحيح',
      'calc.uFit': 'U المنمذجة', 'calc.uFitNeg': 'غير قابلة للاستعمال (سالبة)', 'calc.uPrudent': 'U الحذرة',
      'calc.recommended': 'موصى بها', 'calc.expired': 'انتهت صلاحية الشهادة ({d}): النتيجة للعلم فقط.',
      'calc.validRange': 'المجال الصالح', 'calc.resMaxC': 'أكبر باقٍ للاستيفاء', 'calc.exact': 'قيم غير مقرّبة',
      'btn.copy': 'نسخ النتيجة', 'toast.copied': 'تم نسخ النتيجة', 'err.copy': 'تعذّر النسخ',
      'calc.formulas': 'الصيغ المستعملة',
      'calc.formulasNote': 'انحدار خطي بالمربعات الصغرى غير مرجّح. U مقرّبة إلى رقمين معنويين نحو الأعلى، والتصحيح بنفس عدد الأرقام العشرية.',
      'btn.addHistory': 'إضافة إلى السجل', 'btn.excel': 'تصدير Excel', 'toast.excel': 'تم تصدير ملف Excel',
    },
    fr: {
      'app.title': 'Analyseur d’étalonnage',
      'app.subtitle': 'Certificats d’étalonnage · modèles de correction et d’incertitude',
      'tab.data': 'Données', 'tab.analysis': 'Analyse', 'tab.calc': 'Calculateur', 'tab.report': 'Rapport',
      'theme': 'Changer de thème',
      'data.h': 'Données du certificat', 'data.p': 'Saisissez les points tels qu’ils figurent sur le certificat, puis réglez les critères d’acceptation.',
      'points.title': 'Points d’étalonnage', 'points.sub': 'Indication · Correction · Incertitude',
      'points.hint': 'Collez un tableau depuis Excel, ou glissez un fichier CSV ici.',
      'drop': 'Déposez le fichier CSV ici',
      'col.indication': 'Indication', 'col.correction': 'Correction', 'col.uncertainty': 'Incertitude',
      'col.fitC': 'C ajustée', 'col.resC': 'Résidu C', 'col.fitU': 'U ajustée', 'col.resU': 'Résidu U',
      'btn.example': 'Exemple', 'btn.import': 'Importer CSV', 'btn.clear': 'Effacer', 'btn.addRow': 'Ajouter un point',
      'btn.analyze': 'Analyser les données', 'btn.saveSession': 'Enregistrer la session', 'btn.loadSession': 'Ouvrir une session',
      'btn.calculate': 'Calculer', 'btn.exportCsv': 'Exporter CSV', 'btn.print': 'Imprimer / PDF',
      'btn.goData': 'Aller aux données', 'btn.goAnalysis': 'Voir l’analyse', 'btn.delRow': 'Supprimer le point',
      'meta.title': 'Instrument et certificat',
      'f.instrument': 'Instrument', 'f.certificate': 'N° de certificat', 'f.date': 'Date d’étalonnage', 'f.lab': 'Laboratoire',
      'f.unitI': 'Unité d’indication', 'f.unitC': 'Unité de correction', 'f.unitU': 'Unité d’incertitude', 'f.nature': 'Nature de l’incertitude',
      'ph.instrument': 'ex. Thermomètre numérique', 'ph.optional': 'Facultatif',
      'nature.unknown': 'Inconnue', 'nature.expanded': 'Élargie U', 'nature.standard': 'Type u',
      'crit.title': 'Critères d’acceptation',
      'mode.fraction': 'Fraction de U moyenne', 'mode.absolute': 'Seuil absolu',
      'f.alphaC': 'Fraction seuil correction', 'f.alphaU': 'Fraction seuil incertitude',
      'f.limitC': 'Seuil correction', 'f.limitU': 'Seuil incertitude',
      'crit.helpFraction': 'Seuil = fraction × incertitude moyenne. Modèle acceptable si résidu max ≤ seuil.',
      'crit.helpAbsolute': 'Modèle acceptable si le résidu absolu max ≤ seuil saisi.',
      'sum.points': 'Points', 'sum.range': 'Étendue', 'sum.meanU': 'U moyenne',
      'an.h': 'Résultats de l’analyse', 'an.p': 'Régression linéaire (moindres carrés) de la correction et de l’incertitude, avec droite majorante.',
      'an.empty.h': 'Aucune analyse', 'an.empty.p': 'Saisissez au moins trois points puis cliquez sur « Analyser les données ».',
      'verdict.ok': 'Les deux modèles sont acceptables selon le critère sur les résidus',
      'verdict.ko': 'Les deux modèles sont non représentatifs selon le critère sur les résidus',
      'verdict.mixed': 'Un seul modèle est acceptable selon le critère sur les résidus',
      'verdict.sub': '{n} points analysés sur l’étendue {lo} → {hi}. Ce contrôle ne constitue pas à lui seul une validation métrologique complète.',
      'kpi.points': 'Points', 'kpi.range': 'Étendue', 'kpi.thrC': 'Seuil correction', 'kpi.thrU': 'Seuil incertitude',
      'model.correction': 'Interpolation (correction)', 'model.uncertainty': 'Modélisation (incertitude)', 'model.majorant': 'U prudente (majorante)',
      'st.r2': 'R²', 'st.maxRes': 'Résidu max', 'st.sres': 's_res', 'st.thr': 'Seuil',
      'dec.ok': 'Acceptable', 'dec.ko': 'Non représentatif',
      'r2.low': 'R² faible : remarque informative, sans règle universelle de rejet.', 'r2.undef': 'R² non défini : données constantes.',
      'r2.ok': 'Le R² est un indicateur descriptif uniquement.',
      'maj.note': 'Majorante = droite ajustée + résidu max ({r}).',
      'chart.measured': 'Mesures', 'chart.fit': 'Régression', 'chart.majorant': 'Majorante',
      'chart.residuals': 'Résidus', 'chart.residual': 'Résidu', 'chart.threshold': '± seuil',
      'an.disclaimer': 'Les seuils sont des réglages initiaux, non une règle normative générale. L’interprétation métrologique finale relève du spécialiste.',
      'calc.h': 'Calculateur', 'calc.p': 'Calculez la valeur corrigée et l’incertitude pour une indication dans l’étendue uniquement.',
      'calc.form': 'Entrées', 'f.inputI': 'Indication lue', 'f.methodC': 'Méthode de correction', 'f.methodU': 'Modèle d’incertitude',
      'method.regression': 'Régression linéaire', 'method.interpolation': 'Interpolation linéaire',
      'method.majorant': 'Droite majorante', 'method.fitted': 'Droite ajustée',
      'calc.confirm': 'Je confirme avoir vérifié les modèles et la méthode de calcul.',
      'calc.result': 'Résultat', 'calc.corrected': 'Valeur corrigée (I + C)', 'calc.correction': 'Correction',
      'calc.indication': 'Indication', 'calc.uncertainty': 'Incertitude', 'calc.method': 'Méthode',
      'calc.empty': 'Saisissez une indication : le résultat s’affiche instantanément.',
      'calc.note': 'Calcul dans l’étendue ; interprétation métrologique à confirmer.',
      'calc.history': 'Historique', 'calc.historyEmpty': 'Aucun calcul pour l’instant.',
      'calc.empty.h': 'Calculateur indisponible', 'calc.empty.p': 'Lancez d’abord l’analyse pour activer le calculateur.',
      'rep.h': 'Rapport d’analyse', 'rep.p': 'Aperçu imprimable ou exportable en PDF.',
      'rep.empty.h': 'Rapport indisponible', 'rep.empty.p': 'Lancez l’analyse pour générer le rapport.',
      'rep.title': 'Rapport d’analyse d’étalonnage', 'rep.generated': 'Généré le',
      'rep.meta': 'Instrument', 'rep.points': 'Points et résidus', 'rep.models': 'Modèles et décisions',
      'rep.charts': 'Graphiques', 'rep.calcs': 'Calculs', 'rep.warnings': 'Remarques et avertissements',
      'rep.criterion': 'Critère', 'rep.model': 'Modèle', 'rep.equation': 'Équation', 'rep.decision': 'Décision',
      'rep.foot': 'Outil d’aide : ce rapport ne constitue pas à lui seul une validation ou une décision métrologique officielle. Il doit être revu par un spécialiste.',
      'footer': 'Tous les calculs sont effectués dans le navigateur ; aucune donnée n’est envoyée à un serveur.',
      'none': '—',
      'err.minPoints': 'Au moins deux points sont requis.',
      'err.nan': 'Point {row}, colonne {col} : valeur vide ou non numérique.',
      'err.negU': 'Point {row} : incertitude négative interdite.',
      'err.dup': 'Deux indications identiques aux points {a} et {b}.',
      'err.range': 'Étendue nulle ou numériquement dégénérée.',
      'err.threshold': 'Les seuils et fractions doivent être finis et non négatifs.',
      'err.csvEmpty': 'Fichier CSV vide ou sans points.',
      'err.csvHeader': 'La première ligne doit contenir Indication, Correction et Incertitude.',
      'err.csvCols': 'Nombre de colonnes incorrect ligne {line}.',
      'err.csvRead': 'Impossible de lire le fichier.', 'err.session': 'Fichier de session invalide.',
      'err.confirm': 'Les modèles doivent être confirmés explicitement avant exploitation.',
      'err.nature': 'La nature de l’incertitude (U ou u) doit être confirmée avant de présenter un résultat complet.',
      'err.unitsCalc': 'Calcul I + C bloqué : unités indication/correction incompatibles.',
      'err.input': 'L’indication doit être un nombre fini.',
      'err.outOfRange': 'Indication hors de l’étendue [{lo} ; {hi}] : pas d’extrapolation.',
      'err.majorant': 'Le modèle d’incertitude donne une valeur négative dans l’étendue et ne peut pas être utilisé.',
      'err.negModel': 'Le modèle actif donne une incertitude négative dans l’étendue ou au point calculé.',
      'warn.zeroU': 'Une ou plusieurs incertitudes sont nulles ; confirmez ces valeurs.',
      'warn.sorted': 'Points triés selon l’indication après votre confirmation (lignes entières conservées).',
      'warn.three': 'Trois points seulement : la validation reste limitée.',
      'warn.units': 'Unités indication/correction différentes : le calcul I + C sera bloqué.',
      'warn.majorant': 'La droite majorante donne des valeurs négatives dans l’étendue : inutilisable.',
      'toast.saved': 'Session enregistrée', 'toast.loaded': 'Session ouverte', 'toast.imported': '{n} points importés',
      'toast.pasted': '{n} lignes collées', 'toast.analyzed': 'Analyse terminée', 'toast.csv': 'Fichier exporté',
      'confirm.clear': 'Effacer tous les points ?',
      'btn.importFile': 'Importer CSV / PDF', 'btn.cancel': 'Annuler', 'btn.loadSeries': 'Charger cette série',
      'drop2': 'Déposez un fichier CSV ou PDF ici',
      'pdf.reading': 'Lecture du certificat…',
      'pdf.title': 'Tableaux extraits du certificat',
      'pdf.sub': '{n} série(s) trouvée(s). Choisissez celle à analyser.',
      'pdf.verify': 'Vérifiez les valeurs avec le certificat original avant l’analyse. Correction = − Erreur (référence − équipement).',
      'pdf.ref': 'Référence', 'pdf.eq': 'Équipement', 'pdf.err': 'Erreur', 'pdf.points': '{n} points',
      'pdf.none': 'Aucun tableau de résultats (référence · équipement · erreur · ±U) trouvé dans ce fichier.',
      'pdf.scanned': 'Le fichier ne contient pas de texte lisible (probablement un scan). Saisissez les valeurs manuellement.',
      'err.pdfLib': 'Impossible de charger le lecteur PDF (connexion Internet requise, ou contrôle d’intégrité échoué).',
      'err.tooLarge': 'Fichier trop volumineux (limite : 20 Mo pour un PDF, 2 Mo pour CSV/JSON).',
      'err.pdfRead': 'Impossible de lire le fichier PDF.',
      'toast.pdf': '{n} points chargés depuis le certificat',
      'series': 'Série',
      'pdf.inconsistent': 'Attention : pour les points signalés, l’erreur est absente ou ne correspond pas à (équipement − référence). Les colonnes peuvent être mélangées ; vérifiez-les sur le certificat.',
      'pdf.confirmInconsistent': 'Certains points ne sont pas confirmés (erreur absente ou incohérente). Les avez-vous vérifiés manuellement sur le certificat original ?',
      'confirm.sort': 'Les indications ne sont pas croissantes. Trier les points (lignes entières conservées) puis analyser ?',
      'err.notSortedUser': 'Analyse non lancée : points non triés. Triez-les ou acceptez le tri.',
      'err.notSorted': 'Points non triés selon l’indication.', 'err.method': 'Méthode de calcul non reconnue.',
      'err.fitInput': 'Il faut au moins deux paires réelles et finies.',
      'f.k': 'Facteur d’élargissement k', 'k.verify': 'à vérifier', 'f.uncType': 'Type d’incertitude',
      'unc.absolute': 'Absolue', 'unc.relative': 'Relative (% de la lecture)', 'f.validUntil': 'Date de validité (facultative)',
      'warn.two': 'Deux points seulement : droite exacte, résidu nul — modèle non représentatif.',
      'warn.linearity': 'Alerte de linéarité : le résidu max de la correction dépasse la plus petite incertitude du certificat ; le modèle linéaire n’est plus négligeable devant l’incertitude d’étalonnage.',
      'warn.relative': 'Incertitude relative : convertie en absolue U = U% × |I| / 100 avant régression (valeurs d’origine conservées).',
      'warn.kDefault': 'k = 2 est une valeur par défaut, non lue sur le certificat : à vérifier.',
      'calc.heroNote': 'Valeur corrigée ± U prudente (k = {k}) · valeur corrigée = indication + correction',
      'calc.uFit': 'U modélisée', 'calc.uFitNeg': 'Non exploitable (négative)', 'calc.uPrudent': 'U prudente',
      'calc.recommended': 'recommandée', 'calc.expired': 'Certificat expiré ({d}) : résultat à titre indicatif uniquement.',
      'calc.validRange': 'Étendue valide', 'calc.resMaxC': 'Résidu max interpolation', 'calc.exact': 'Valeurs non arrondies',
      'btn.copy': 'Copier le résultat', 'toast.copied': 'Résultat copié', 'err.copy': 'Copie impossible',
      'calc.formulas': 'Formules utilisées',
      'calc.formulasNote': 'Régression linéaire par moindres carrés ordinaires, non pondérée. U arrondie à 2 chiffres significatifs vers le haut ; correction affichée avec le même nombre de décimales.',
      'btn.addHistory': 'Ajouter à l’historique', 'btn.excel': 'Exporter Excel', 'toast.excel': 'Fichier Excel exporté',
    },
  };

  const ICONS = {
    folder: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
    save: '<path d="M5 3h11l5 5v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><path d="M7 3v5h8V3M7 21v-7h10v7"/>',
    table: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M3 15h18M9 4v16"/>',
    spark: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
    upload: '<path d="M12 15V4M7 9l5-5 5 5"/><path d="M4 15v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>',
    download: '<path d="M12 4v11M7 10l5 5 5-5"/><path d="M4 15v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>',
    doc: '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6M8 13h8M8 17h5"/>',
    sliders: '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
    play: '<path d="M7 4.5v15l12-7.5z"/>',
    chart: '<path d="M4 20V4M4 20h16"/><path d="M7 15l4-4 3 3 5-6"/>',
    calc: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 12h.01M12 12h.01M16 12h.01M8 16h.01M12 16h.01M16 16h.01"/>',
    target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
    list: '<path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/>',
    printer: '<path d="M6 9V3h12v6M6 18H4a1 1 0 0 1-1-1v-6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v6a1 1 0 0 1-1 1h-2"/><path d="M6 14h12v7H6z"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    alert: '<path d="M12 3l9.5 17h-19z"/><path d="M12 10v4M12 17h.01"/>',
    xcircle: '<circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/>',
  };
  const icon = (name, size = 16) =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ''}</svg>`;

  /* ---------- State ---------- */
  const $ = id => document.getElementById(id);
  const META_FIELDS = ['instrument', 'certificate', 'date', 'lab', 'unitI', 'unitC', 'unitU', 'nature', 'k', 'uncType', 'validUntil'];
  const state = {
    lang: 'fr',
    theme: null,
    mode: 'fraction',
    analysis: null,
    history: [],
    lastResult: null,
    tab: 'data',
  };

  const storage = {
    get() { try { return JSON.parse(localStorage.getItem(STORE) || 'null'); } catch { return null; } },
    set(v) { try { localStorage.setItem(STORE, JSON.stringify(v)); } catch { /* stockage indisponible */ } },
  };

  const t = (key, vars = {}) =>
    String(I18N[state.lang][key] ?? I18N.fr[key] ?? key).replace(/\{(\w+)\}/g, (_, v) => (v in vars ? vars[v] : ''));

  const esc = s => String(s ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));

  /* Affichage : 10 chiffres significatifs par défaut (le calcul interne reste en double).
   * Les petites valeurs restent en notation scientifique : jamais de faux zéro. */
  function fmt(v, digits = 10) {
    if (!Number.isFinite(v)) return '—';
    if (v === 0) return '0';
    const locale = state.lang === 'fr' ? 'fr-FR' : 'en-US';
    const abs = Math.abs(v);
    if (abs >= 1e9 || abs < 1e-5) return v.toExponential(Math.max(2, Math.min(digits, 10) - 1)).replace(/\.?0+e/, 'e');
    return new Intl.NumberFormat(locale, { maximumSignificantDigits: digits, useGrouping: abs >= 1e4 }).format(v);
  }
  const signed = v => (v < 0 ? '− ' + fmt(-v) : '+ ' + fmt(v));
  const Core = window.EtalonnageCore;
  const { parseNum } = Core;

  /* ---------- Points table ---------- */
  const tbody = $('pointsBody');

  function addRow(values = ['', '', ''], focus = false) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td class="idx"></td>${values.map((v, i) =>
      `<td><input class="num" inputmode="decimal" autocomplete="off" data-col="${i}" value="${esc(v)}"></td>`).join('')}
      <td class="act"><button class="row-del" type="button">${icon('x', 15)}</button></td>`;
    tbody.append(tr);
    renumber();
    if (focus) tr.querySelector('input').focus();
    return tr;
  }
  function setRows(rows) {
    tbody.replaceChildren();
    (rows.length ? rows : [['', '', ''], ['', '', ''], ['', '', '']]).forEach(r => addRow(r.map(v => String(v))));
  }
  function renumber() {
    [...tbody.rows].forEach((tr, i) => {
      tr.cells[0].textContent = i + 1;
      tr.querySelector('.row-del').title = t('btn.delRow');
      tr.querySelector('.row-del').setAttribute('aria-label', t('btn.delRow'));
      tr.querySelectorAll('input').forEach((inp, j) =>
        inp.setAttribute('aria-label', `${[t('col.indication'), t('col.correction'), t('col.uncertainty')][j]} ${i + 1}`));
    });
  }
  const rawRows = () => [...tbody.rows].map(tr => [...tr.querySelectorAll('input')].map(i => i.value));
  const nonEmptyRows = () => rawRows().filter(r => r.some(v => v.trim() !== ''));

  tbody.addEventListener('click', e => {
    const btn = e.target.closest('.row-del');
    if (!btn) return;
    btn.closest('tr').remove();
    if (!tbody.rows.length) addRow();
    renumber(); changed();
  });
  tbody.addEventListener('input', e => { e.target.classList.remove('bad'); changed(); });
  tbody.addEventListener('keydown', e => {
    if (e.key !== 'Enter' || !e.target.matches('input')) return;
    e.preventDefault();
    const tr = e.target.closest('tr'), col = +e.target.dataset.col;
    const next = tr.nextElementSibling || addRow();
    next.querySelectorAll('input')[col].focus();
  });
  // Collage d'un bloc tabulaire (Excel, CSV) à partir de la cellule active.
  tbody.addEventListener('paste', e => {
    const text = (e.clipboardData || window.clipboardData).getData('text');
    if (!/[\t\n;]/.test(text.trim())) return;
    e.preventDefault();
    const lines = text.replace(/\r/g, '').split('\n').filter(l => l.trim());
    const sep = text.includes('\t') ? '\t' : ';';
    let tr = e.target.closest('tr');
    const startCol = +e.target.dataset.col;
    let count = 0;
    lines.forEach(line => {
      const cells = line.split(sep).map(c => c.trim());
      if (cells.every(c => Number.isNaN(parseNum(c, true)))) return; // ligne d'en-tête
      if (!tr) tr = addRow();
      const inputs = tr.querySelectorAll('input');
      cells.forEach((c, j) => { if (inputs[startCol + j]) inputs[startCol + j].value = c; });
      tr = tr.nextElementSibling; count++;
    });
    renumber(); changed();
    if (count) toast(t('toast.pasted', { n: count }));
  });

  /* ---------- Settings & metadata ---------- */
  function readMeta() {
    const m = {};
    META_FIELDS.forEach(f => { m[f] = $('m-' + f).value.trim(); });
    return m;
  }
  function readSettings() {
    return {
      mode: state.mode,
      alphaC: $('s-alphaC').value, alphaU: $('s-alphaU').value,
      limitC: $('s-limitC').value, limitU: $('s-limitU').value,
      uncType: $('m-uncType').value === 'relative' ? 'relative' : 'absolute',
    };
  }
  function updateKPill() { $('kVerifyPill').hidden = !!state.kVerified; }
  function setMode(mode) {
    state.mode = mode;
    document.querySelectorAll('.seg button').forEach(b => {
      b.classList.toggle('on', b.dataset.mode === mode);
      b.setAttribute('aria-checked', b.dataset.mode === mode);
      b.setAttribute('role', 'radio');
    });
    $('fractionFields').hidden = mode !== 'fraction';
    $('absoluteFields').hidden = mode !== 'absolute';
    $('critHelp').textContent = t(mode === 'fraction' ? 'crit.helpFraction' : 'crit.helpAbsolute');
  }
  document.querySelectorAll('.seg button').forEach(b => b.addEventListener('click', () => { setMode(b.dataset.mode); changed(); }));
  META_FIELDS.forEach(f => $('m-' + f).addEventListener('input', () => { changed(); updateUnits(); }));
  ['s-alphaC', 's-alphaU', 's-limitC', 's-limitU'].forEach(id => $(id).addEventListener('input', changed));

  function updateUnits() {
    const m = readMeta();
    const wrap = u => (u ? `(${esc(u)})` : '');
    document.querySelectorAll('.unit-i').forEach(el => { el.innerHTML = wrap(m.unitI); });
    document.querySelectorAll('.unit-c').forEach(el => { el.innerHTML = wrap(m.unitC); });
    document.querySelectorAll('.unit-u').forEach(el => { el.innerHTML = wrap(m.unitU); });
  }

  /* ---------- Moteur (core.js, miroir de core/*.m) ---------- */
  const COLS = () => [t('col.indication'), t('col.correction'), t('col.uncertainty')];
  function coreMessage(code, params = {}) {
    const p = { ...params };
    if (code === 'nan') p.col = COLS()[params.col];
    if (code === 'outOfRange') { p.lo = fmt(params.lo); p.hi = fmt(params.hi); }
    return t('err.' + code, p);
  }

  /* validerDonnees + analyserEtalonnage. Tri seulement après confirmation explicite (F4). */
  function analyser() {
    tbody.querySelectorAll('input.bad').forEach(i => i.classList.remove('bad'));
    const filled = [...tbody.rows].filter(tr => [...tr.querySelectorAll('input')].some(i => i.value.trim()));
    const rows = filled.map(tr => [...tr.querySelectorAll('input')].map(i => i.value));
    const meta = readMeta(), s = readSettings();
    const v = Core.valider(rows, s, meta);
    v.errors.forEach(e => { if (e.cell) filled[e.cell[0]]?.querySelectorAll('input')[e.cell[1]].classList.add('bad'); });
    if (v.errors.length) return { errors: v.errors.map(e => coreMessage(e.code, e.params)), warnings: [] };
    const warnings = v.warnings.slice();
    let pts = v.pts;
    if (v.needsSort) {
      if (!confirm(t('confirm.sort'))) return { errors: [t('err.notSortedUser')], warnings: [] };
      pts = pts.slice().sort((a, b) => a.x - b.x);
      // Valeur d'origine (uRaw) : en mode relatif, p.u est la valeur convertie en absolu.
      setRows(pts.map(p => [rawStr(p.x), rawStr(p.c), rawStr(p.uRaw ?? p.u)]));
      warnings.push('warn.sorted');
    }
    let A;
    try { A = Core.analyser(pts, v.sC, v.sU); }
    catch (err) { return { errors: [err.code ? coreMessage(err.code, err.params) : err.message], warnings }; }
    if (!A.maj.usable) warnings.push('warn.majorant');
    if (Core.alerteLinearite(A, meta)) warnings.push('warn.linearity');
    if (meta.uncType === 'relative') warnings.push('warn.relative');
    if (!state.kVerified) warnings.push('warn.kDefault');
    return { errors: [], warnings, result: { ...A, meta, settings: s, date: new Date() } };
  }
  const rawStr = v => (state.lang === 'fr' ? String(v).replace('.', ',') : String(v));

  /* calculerResultat */
  function calculer(xRaw, methodC, confirmed) {
    try {
      return { ...Core.calculer(state.analysis, state.analysis.meta, xRaw, methodC, confirmed), time: new Date() };
    } catch (err) {
      throw new Error(err.code ? coreMessage(err.code, err.params) : err.message);
    }
  }

  /* ---------- Charts (SVG) ---------- */
  function niceTicks(min, max, count = 5) {
    const span = max - min || Math.abs(max) || 1;
    const raw = span / count, mag = 10 ** Math.floor(Math.log10(raw)), n = raw / mag;
    const step = (n < 1.5 ? 1 : n < 3 ? 2 : n < 7 ? 5 : 10) * mag;
    const out = [];
    // Graduation calculée par multiples entiers du pas (pas d'accumulation d'erreur : 0 reste 0).
    for (let i = Math.ceil(min / step); i * step <= max + step * 1e-6; i++) out.push(i === 0 ? 0 : +(i * step).toPrecision(12));
    return out;
  }
  function domain(vals, padFrac = 0.08) {
    let lo = Math.min(...vals), hi = Math.max(...vals);
    if (lo === hi) { const d = Math.abs(lo) * 0.1 || 1; lo -= d; hi += d; }
    const p = (hi - lo) * padFrac;
    return [lo - p, hi + p];
  }

  /* cfg: {height, lines:[{a,b,cls}], points:[{x,y,label}], bars:[{x,y,ok}], band, marker:{x,y}, yTitle, xTitle} */
  function renderChart(el, cfg) {
    const W = Math.max(280, Math.round(el.clientWidth || 520)), H = cfg.height || 260;
    const m = { l: 56, r: 14, t: 12, b: cfg.xTitle ? 40 : 26 };
    const xs = [...(cfg.points || []).map(p => p.x), ...(cfg.bars || []).map(p => p.x)];
    const ys = [...(cfg.points || []).map(p => p.y), ...(cfg.bars || []).map(p => p.y)];
    (cfg.lines || []).forEach(l => xs.length && ys.push(l.a * Math.min(...xs) + l.b, l.a * Math.max(...xs) + l.b));
    if (cfg.band != null) ys.push(cfg.band, -cfg.band);
    if (cfg.bars) ys.push(0);
    const [x0, x1] = domain(xs, cfg.bars ? 0.1 : 0.05), [y0, y1] = domain(ys);
    const px = v => m.l + (v - x0) / (x1 - x0) * (W - m.l - m.r);
    const py = v => H - m.b - (v - y0) / (y1 - y0) * (H - m.t - m.b);
    const yt = niceTicks(y0, y1, 4).filter(v => v >= y0 && v <= y1);
    const xt = niceTicks(x0, x1, Math.max(3, Math.min(7, Math.floor(W / 90)))).filter(v => v >= x0 && v <= x1);
    let s = `<svg viewBox="0 0 ${W} ${H}" role="img">`;
    s += '<g class="grid">' + yt.map(v => `<line x1="${m.l}" x2="${W - m.r}" y1="${py(v)}" y2="${py(v)}"/>`).join('') + '</g>';
    s += '<g class="axis">' + yt.map(v => `<text x="${m.l - 8}" y="${py(v) + 4}" text-anchor="end">${fmt(v, 4)}</text>`).join('');
    s += xt.map(v => `<text x="${px(v)}" y="${H - m.b + 16}" text-anchor="middle">${fmt(v, 4)}</text>`).join('') + '</g>';
    if (cfg.xTitle) s += `<text class="axis-title" x="${(m.l + W - m.r) / 2}" y="${H - 4}" text-anchor="middle">${esc(cfg.xTitle)}</text>`;
    if (cfg.band != null) {
      s += `<rect class="band" x="${m.l}" y="${py(cfg.band)}" width="${W - m.l - m.r}" height="${Math.max(0, py(-cfg.band) - py(cfg.band))}"/>`;
      s += `<line class="thr" x1="${m.l}" x2="${W - m.r}" y1="${py(cfg.band)}" y2="${py(cfg.band)}"/>`;
      s += `<line class="thr" x1="${m.l}" x2="${W - m.r}" y1="${py(-cfg.band)}" y2="${py(-cfg.band)}"/>`;
    }
    if (cfg.bars) {
      s += `<line class="zero" x1="${m.l}" x2="${W - m.r}" y1="${py(0)}" y2="${py(0)}"/>`;
      const sorted = cfg.bars.map(b => px(b.x)).sort((a, b) => a - b);
      const gap = sorted.slice(1).reduce((g, v, i) => Math.min(g, v - sorted[i]), Infinity);
      const bw = Math.max(4, Math.min(28, (Number.isFinite(gap) ? gap : 40) * 0.5));
      cfg.bars.forEach((b, i) => {
        const yA = py(Math.max(0, b.y)), yB = py(Math.min(0, b.y));
        s += `<rect class="${b.ok ? 'bar-ok' : 'bar-ko'}" data-i="${i}" x="${px(b.x) - bw / 2}" y="${yA}" width="${bw}" height="${Math.max(1, yB - yA)}" rx="2"/>`;
      });
    }
    (cfg.lines || []).forEach(l => {
      const a = Math.min(...xs), b = Math.max(...xs);
      s += `<path class="${l.cls}" d="M${px(a)},${py(l.a * a + l.b)}L${px(b)},${py(l.a * b + l.b)}"/>`;
    });
    if (cfg.marker) {
      s += `<line class="marker" x1="${px(cfg.marker.x)}" x2="${px(cfg.marker.x)}" y1="${m.t}" y2="${H - m.b}"/>`;
      s += `<circle class="marker-pt" cx="${px(cfg.marker.x)}" cy="${py(cfg.marker.y)}" r="5.5"/>`;
    }
    (cfg.points || []).forEach((p, i) => { s += `<circle class="s-pt" data-i="${i}" cx="${px(p.x)}" cy="${py(p.y)}" r="4.5"/>`; });
    s += '</svg>';
    el.innerHTML = s;

    if (cfg.interactive === false) return;
    const tip = document.createElement('div');
    tip.className = 'tooltip'; tip.hidden = true; el.append(tip);
    const svg = el.querySelector('svg');
    const items = cfg.points || cfg.bars;
    svg.addEventListener('mousemove', e => {
      const r = svg.getBoundingClientRect(), k = W / r.width;
      const mx = (e.clientX - r.left) * k;
      let best = -1, bd = Infinity;
      items.forEach((p, i) => { const d = Math.abs(px(p.x) - mx); if (d < bd) { bd = d; best = i; } });
      svg.querySelectorAll('.hot').forEach(n => n.classList.remove('hot'));
      if (best < 0 || bd > 40) { tip.hidden = true; return; }
      const p = items[best];
      svg.querySelector(`[data-i="${best}"]`)?.classList.add('hot');
      tip.innerHTML = `x = ${fmt(p.x)}<br>${esc(cfg.yLabel || 'y')} = ${fmt(p.y)}`;
      tip.style.left = `${px(p.x) / k}px`;
      tip.style.top = `${py(cfg.bars ? Math.max(0, p.y) : p.y) / k}px`;
      tip.hidden = false;
    });
    svg.addEventListener('mouseleave', () => { tip.hidden = true; svg.querySelectorAll('.hot').forEach(n => n.classList.remove('hot')); });
  }

  function modelChart(el, A, key, opts = {}) {
    const model = A[key];
    const lines = [{ a: model.a, b: model.b, cls: 's-fit' }];
    if (key === 'u') lines.push({ a: A.maj.a, b: A.maj.b, cls: 's-maj' });
    renderChart(el, {
      height: opts.height || 250, lines, interactive: opts.interactive,
      points: A.pts.map(p => ({ x: p.x, y: p[key] })),
      yLabel: key === 'c' ? 'C' : 'U', xTitle: t('col.indication') + (A.meta.unitI ? ` (${A.meta.unitI})` : ''),
      marker: opts.marker,
    });
  }
  function residualChart(el, A, key, opts = {}) {
    const model = A[key], thr = key === 'c' ? A.sC : A.sU, dec = key === 'c' ? A.decC : A.decU;
    renderChart(el, {
      height: opts.height || 150, band: thr, yLabel: t('chart.residual'), interactive: opts.interactive,
      bars: model.x.map((x, i) => ({ x, y: model.residu[i], ok: Math.abs(model.residu[i]) <= dec.seuil + TOL * Math.max(1, dec.seuil, model.residuMax) })),
    });
  }

  /* ---------- Rendering ---------- */
  function alertsHtml(list, kind) {
    const ico = { err: 'xcircle', warn: 'alert', ok: 'check', info: 'info' }[kind];
    return list.map(msg => `<div class="alert ${kind}">${icon(ico)}<span>${esc(msg)}</span></div>`).join('');
  }
  const pill = ok => `<span class="pill ${ok ? 'ok' : 'ko'}">${icon(ok ? 'check' : 'x', 13)}${t(ok ? 'dec.ok' : 'dec.ko')}</span>`;
  const eq = (sym, m) => `<bdi class="eq" dir="ltr">${sym} = ${fmt(m.a)} · I ${signed(m.b)}</bdi>`;
  const unit = u => (u ? ` <span class="k-unit">${esc(u)}</span>` : '');

  function renderSummary() {
    const rows = nonEmptyRows().map(r => r.map((v, j) => parseNum(v, j === 2)));
    const valid = rows.filter(r => r.every(Number.isFinite));
    const xs = valid.map(r => r[0]);
    const meanU = valid.length ? valid.reduce((s, r) => s + r[2], 0) / valid.length : NaN;
    const range = xs.length >= 2 ? `${fmt(Math.min(...xs))} → ${fmt(Math.max(...xs))}` : '—';
    $('dataSummary').innerHTML =
      `<span>${t('sum.points')}: <b>${rows.length}</b></span>` +
      `<span>${t('sum.range')}: <b dir="ltr">${range}</b></span>` +
      `<span>${t('sum.meanU')}: <b>${fmt(meanU)}</b></span>`;
  }

  function emptyState(el, h, p, btnKey, tab) {
    el.innerHTML = `<div class="e-ico">${icon('chart', 30)}</div><h2>${t(h)}</h2><p>${t(p)}</p>
      <button class="btn primary" type="button" data-go="${tab}">${t(btnKey)}</button>`;
  }

  function renderAnalysis() {
    const A = state.analysis;
    $('analysisEmpty').hidden = !!A; $('analysisContent').hidden = !A;
    if (!A) { emptyState($('analysisEmpty'), 'an.empty.h', 'an.empty.p', 'btn.goData', 'data'); return; }
    const okC = A.decC.ok, okU = A.decU.ok;
    const kind = okC && okU ? 'ok' : !okC && !okU ? 'ko' : 'mixed';
    $('verdict').className = `verdict ${kind}`;
    $('verdict').innerHTML = `<div class="v-ico">${icon(kind === 'ok' ? 'check' : kind === 'ko' ? 'xcircle' : 'alert', 24)}</div>
      <div><h2>${t('verdict.' + kind)}</h2><p>${t('verdict.sub', { n: A.pts.length, lo: fmt(A.lo), hi: fmt(A.hi) })}</p></div>`;
    $('kpis').innerHTML = [
      ['kpi.points', A.pts.length, ''],
      ['kpi.range', `${fmt(A.lo)} → ${fmt(A.hi)}`, A.meta.unitI],
      ['kpi.thrC', fmt(A.sC), A.meta.unitC],
      ['kpi.thrU', fmt(A.sU), A.meta.unitU],
    ].map(([k, v, u]) => `<div class="kpi"><div class="k-label">${t(k)}</div><div class="k-value">${v}${unit(u)}</div></div>`).join('');
    $('analysisAlerts').innerHTML = alertsHtml(state.warnings.map(w => t(w)), 'warn');

    $('decC').innerHTML = pill(okC); $('decU').innerHTML = pill(okU);
    $('eqC').innerHTML = eq('C', A.c);
    $('eqU').innerHTML = `${eq('U', A.u)}<span class="pill ${A.maj.usable ? 'neutral' : 'warn'}" title="${t('model.majorant')}">${t('chart.majorant')}: <bdi dir="ltr" class="eq">${fmt(A.maj.a)} · I ${signed(A.maj.b)}</bdi></span>`;
    const stats = (m, thr) => [
      ['st.r2', fmt(m.R2, 5)], ['st.maxRes', fmt(m.residuMax)], ['st.sres', fmt(m.sRes)], ['st.thr', fmt(thr)],
    ].map(([k, v]) => `<div><dt>${t(k)}</dt><dd>${v}</dd></div>`).join('');
    $('statsC').innerHTML = stats(A.c, A.sC); $('statsU').innerHTML = stats(A.u, A.sU);
    $('noteC').innerHTML = `${icon('info', 14)}<span>${t(A.decC.r2)}</span>`;
    $('noteU').innerHTML = `${icon('info', 14)}<span>${t(A.decU.r2)} ${t('maj.note', { r: fmt(A.u.residuMax) })}</span>`;
    drawAnalysisCharts();
  }
  function drawAnalysisCharts() {
    const A = state.analysis;
    if (!A || state.tab !== 'analysis') return;
    modelChart($('chartC'), A, 'c'); modelChart($('chartU'), A, 'u');
    residualChart($('resC'), A, 'c'); residualChart($('resU'), A, 'u');
  }

  function renderCalc() {
    const A = state.analysis;
    $('calcEmpty').hidden = !!A; $('calcContent').hidden = !A;
    if (!A) { emptyState($('calcEmpty'), 'calc.empty.h', 'calc.empty.p', 'btn.goData', 'data'); return; }
    const inp = $('c-input');
    inp.min = A.lo; inp.max = A.hi;
    if (inp.value === '') inp.value = +((A.lo + A.hi) / 2).toPrecision(10);
    $('c-lo').textContent = 'min ' + fmt(A.lo); $('c-hi').textContent = 'max ' + fmt(A.hi);
    liveCalc(); renderHistory();
  }
  /* Affichage métrologique : U à 2 chiffres significatifs arrondie vers le haut ; C et I + C avec
   * le même nombre de décimales que U prudente. Les valeurs non arrondies restent visibles. */
  function fixed(v, decimals) {
    const r = Number(v.toFixed(decimals));
    const locale = state.lang === 'fr' ? 'fr-FR' : 'en-US';
    return new Intl.NumberFormat(locale, { minimumFractionDigits: decimals, maximumFractionDigits: decimals, useGrouping: false })
      .format(r === 0 ? 0 : r);
  }
  function displayResult(R) {
    const ru = Core.arrondirIncertitude(R.uPrudent);
    const rf = R.uFitOk ? Core.arrondirIncertitude(R.uFit) : null;
    const dec = ru.decimals;
    return {
      C: (R.C > 0 ? '+' : '') + fixed(R.C, dec), corrected: fixed(R.corrected, dec),
      uPrudent: fixed(ru.value, ru.decimals), uFit: rf ? fixed(rf.value, rf.decimals) : null,
    };
  }
  const isExpired = m => !!m.validUntil && m.validUntil < new Date().toISOString().slice(0, 10);

  function renderResult() {
    const A = state.analysis, R = state.lastResult, el = $('calcResult');
    const m = A.meta;
    const expired = isExpired(m)
      ? `<div class="alert err" style="margin-bottom:12px">${icon('xcircle')}<span>${t('calc.expired', { d: esc(m.validUntil) })}</span></div>` : '';
    if (!R) { el.innerHTML = `${expired}<p class="help" style="font-size:13.5px">${t('calc.empty')}</p>`; return; }
    const uI = m.unitI || m.unitC, uU = m.uncType === 'relative' ? m.unitI : m.unitU;
    const D = displayResult(R);
    const k = esc(m.k || '—') + (state.kVerified ? '' : ` <span class="pill warn">${t('k.verify')}</span>`);
    el.innerHTML = `${expired}
      <div class="result-hero">
        <div class="r-label">${t('calc.corrected')}</div>
        <div class="r-value">${D.corrected} <small>± ${D.uPrudent} ${esc(uI)}</small></div>
        <div class="help" style="margin-top:4px">${t('calc.heroNote', { k })}</div>
      </div>
      <div class="r-grid r-grid-2">
        <div class="kpi"><div class="k-label">${t('calc.correction')} C(I)</div><div class="k-value">${D.C}${unit(m.unitC || uI)}</div></div>
        <div class="kpi"><div class="k-label">${t('calc.corrected')}</div><div class="k-value">${D.corrected}${unit(uI)}</div></div>
        <div class="kpi"><div class="k-label">${t('calc.uFit')} (k = ${esc(m.k || '—')})</div>
          <div class="k-value">${D.uFit ?? `<span style="color:var(--err);font-size:13px">${t('calc.uFitNeg')}</span>`}${D.uFit ? unit(uU) : ''}</div></div>
        <div class="kpi kpi-reco"><div class="k-label">${t('calc.uPrudent')} <span class="pill ok">${t('calc.recommended')}</span></div>
          <div class="k-value">${D.uPrudent}${unit(uU)}</div></div>
      </div>
      <dl class="stats" style="margin-top:12px">
        <div><dt>${t('f.certificate')}</dt><dd>${esc(m.certificate || '—')}</dd></div>
        <div><dt>${t('calc.validRange')}</dt><dd>${fmt(A.lo)} → ${fmt(A.hi)}</dd></div>
        <div><dt>${t('calc.resMaxC')}</dt><dd>${fmt(A.c.residuMax)}</dd></div>
        <div><dt>${t('calc.exact')}</dt><dd title="C = ${fmt(R.C)} ; U = ${fmt(R.uPrudent)}">C ${fmt(R.C, 6)} · Up ${fmt(R.uPrudent, 6)}</dd></div>
      </dl>
      <div class="toolbar" style="margin-top:12px">
        <button class="btn" type="button" id="copyResultBtn">${icon('doc')}<span>${t('btn.copy')}</span></button>
      </div>
      <details class="formulas">
        <summary>${t('calc.formulas')}</summary>
        <ul dir="ltr">
          <li>C(I) = a<sub>C</sub> · I + b<sub>C</sub> = ${fmt(A.c.a)} · I ${signed(A.c.b)}${R.methodC === 'interpolation' ? ` <i>(${t('method.interpolation')})</i>` : ''}</li>
          <li>I<sub>corr</sub> = I + C(I)</li>
          <li>U(I) = a<sub>U</sub> · I + b<sub>U</sub> = ${fmt(A.u.a)} · I ${signed(A.u.b)}</li>
          <li>U<sub>p</sub>(I) = U(I) + max|e<sub>U</sub>| = U(I) + ${fmt(A.u.residuMax)}</li>
          <li>e<sub>i</sub> = y<sub>i</sub> − (a · x<sub>i</sub> + b)</li>
        </ul>
        <p class="help">${t('calc.formulasNote')}</p>
      </details>
      <p class="sub-title">${t('model.correction')}</p>
      <div class="chart" id="calcChart"></div>
      <p class="note">${icon('info', 14)}<span>${t('calc.note')} · ${t('method.' + R.methodC)}</span></p>`;
    modelChart($('calcChart'), A, 'c', { height: 210, marker: { x: R.x, y: R.C } });
    $('copyResultBtn').addEventListener('click', () => copyResult(R, D, uI, uU));
  }
  function copyResult(R, D, uI, uU) {
    const m = state.analysis.meta;
    const txt = [
      `${t('calc.indication')} : ${fmt(R.x)} ${uI}`,
      `${t('calc.correction')} C(I) : ${D.C} ${m.unitC || uI}`,
      `${t('calc.corrected')} : ${D.corrected} ${uI}`,
      `${t('calc.uPrudent')} : ${D.uPrudent} ${uU} (k = ${m.k || '—'}${state.kVerified ? '' : ', ' + t('k.verify')})`,
      `${t('calc.uFit')} : ${D.uFit ?? t('calc.uFitNeg')} ${D.uFit ? uU : ''}`,
      `${t('f.certificate')} : ${m.certificate || '—'} · ${t('calc.validRange')} : ${fmt(state.analysis.lo)} → ${fmt(state.analysis.hi)}`,
    ].join('\n');
    navigator.clipboard?.writeText(txt).then(() => toast(t('toast.copied')), () => toast(t('err.copy')));
  }
  function historyTable(rows, compact = false) {
    if (!rows.length) return `<tbody><tr><td class="help" style="text-align:center;padding:18px">${t('calc.historyEmpty')}</td></tr></tbody>`;
    return `<thead><tr><th>#</th><th>${t('calc.indication')}</th><th>${t('calc.correction')}</th><th>${t('calc.corrected')}</th><th>${t('calc.uPrudent')}</th>${compact ? '' : `<th>${t('calc.method')}</th>`}</tr></thead><tbody>` +
      rows.map((r, i) => {
        const D = displayResult(r);
        return `<tr><td class="num-cell">${i + 1}</td><td class="num-cell">${fmt(r.x)}</td><td class="num-cell">${D.C}</td>
        <td class="num-cell"><b>${D.corrected}</b></td><td class="num-cell">${D.uPrudent} (${esc(r.nature)}, k = ${esc(r.k || '—')})</td>
        ${compact ? '' : `<td style="font-size:12px;color:var(--text-3)">${t('method.' + r.methodC)}</td>`}</tr>`;
      }).join('') +
      '</tbody>';
  }
  function renderHistory() {
    $('historyTable').innerHTML = historyTable(state.history);
    $('clearHistoryBtn').hidden = !state.history.length;
  }

  function renderReport() {
    const A = state.analysis;
    $('reportEmpty').hidden = !!A; $('paper').hidden = !A;
    $('reportActions').hidden = !A;
    if (!A) { emptyState($('reportEmpty'), 'rep.empty.h', 'rep.empty.p', 'btn.goData', 'data'); return; }
    const m = A.meta;
    const natureLbl = m.nature === 'U' ? t('nature.expanded') : m.nature === 'u' ? t('nature.standard') : t('nature.unknown');
    const dateStr = A.date.toLocaleString(state.lang === 'fr' ? 'fr-FR' : 'ar-DZ-u-nu-latn');
    const kv = [
      ['f.instrument', m.instrument], ['f.certificate', m.certificate], ['f.lab', m.lab], ['f.date', m.date],
      ['f.unitI', m.unitI], ['f.unitC', m.unitC], ['f.unitU', m.unitU], ['f.nature', natureLbl],
      ['sum.range', `${fmt(A.lo)} → ${fmt(A.hi)}`],
    ];
    const critLbl = A.settings.mode === 'fraction'
      ? `${t('mode.fraction')} (α = ${fmt(parseNum(A.settings.alphaC))} / ${fmt(parseNum(A.settings.alphaU))})`
      : t('mode.absolute');
    $('paper').innerHTML = `
      <div class="p-head">
        <div>
          <h1>${t('rep.title')}</h1>
          <div style="color:#64748b;font-size:13px;margin-top:4px">${esc(m.instrument || '')}${m.certificate ? ' · ' + esc(m.certificate) : ''}</div>
        </div>
        <div class="meta">${t('rep.generated')}<br>${esc(dateStr)}</div>
      </div>
      <h3>${t('rep.meta')}</h3>
      <div class="kv">${kv.map(([k, v]) => `<div><span>${t(k)}</span><b>${v ? esc(v) : '—'}</b></div>`).join('')}</div>

      <h3>${t('rep.models')}</h3>
      <div class="table-wrap"><table>
        <thead><tr><th>${t('rep.model')}</th><th>${t('rep.equation')}</th><th>R²</th><th>${t('st.maxRes')}</th><th>${t('st.thr')}</th><th>${t('rep.decision')}</th></tr></thead>
        <tbody>
          <tr><td>${t('model.correction')}</td><td>${eq('C', A.c)}</td><td class="num-cell">${fmt(A.c.R2, 5)}</td><td class="num-cell">${fmt(A.c.residuMax)}</td><td class="num-cell">${fmt(A.sC)}</td><td>${pill(A.decC.ok)}</td></tr>
          <tr><td>${t('model.uncertainty')}</td><td>${eq('U', A.u)}</td><td class="num-cell">${fmt(A.u.R2, 5)}</td><td class="num-cell">${fmt(A.u.residuMax)}</td><td class="num-cell">${fmt(A.sU)}</td><td>${pill(A.decU.ok)}</td></tr>
          <tr><td>${t('model.majorant')}</td><td>${eq('U', A.maj)}</td><td>—</td><td>—</td><td>—</td><td>${A.maj.usable ? '<span class="pill ok">OK</span>' : `<span class="pill warn">${icon('alert', 13)}</span>`}</td></tr>
        </tbody></table></div>
      <p style="font-size:12px;color:#64748b;margin:8px 0 0">${t('rep.criterion')}: ${esc(critLbl)} — e<sub>max</sub> ≤ ${t('st.thr')}</p>

      <h3>${t('rep.points')}</h3>
      <div class="table-wrap"><table>
        <thead><tr><th>#</th><th>${t('col.indication')}</th><th>${t('col.correction')}</th><th>${t('col.fitC')}</th><th>${t('col.resC')}</th><th>${t('col.uncertainty')}</th><th>${t('col.fitU')}</th><th>${t('col.resU')}</th></tr></thead>
        <tbody>${A.pts.map((p, i) => `<tr><td>${i + 1}</td><td class="num-cell">${fmt(p.x)}</td><td class="num-cell">${fmt(p.c)}</td><td class="num-cell">${fmt(A.c.ajuste[i])}</td><td class="num-cell">${fmt(A.c.residu[i])}</td><td class="num-cell">${fmt(p.u)}</td><td class="num-cell">${fmt(A.u.ajuste[i])}</td><td class="num-cell">${fmt(A.u.residu[i])}</td></tr>`).join('')}</tbody>
      </table></div>

      <h3>${t('rep.charts')}</h3>
      <div class="p-charts">
        <div><h4>${t('model.correction')}</h4><div class="legend"><span><i class="dot"></i>${t('chart.measured')}</span><span><i class="fit"></i>${t('chart.fit')}</span></div><div class="chart" id="pChartC"></div></div>
        <div><h4>${t('model.uncertainty')}</h4><div class="legend"><span><i class="dot"></i>${t('chart.measured')}</span><span><i class="fit"></i>${t('chart.fit')}</span><span><i class="maj"></i>${t('chart.majorant')}</span></div><div class="chart" id="pChartU"></div></div>
        <div><h4>${t('chart.residuals')} — C</h4><div class="chart" id="pResC"></div></div>
        <div><h4>${t('chart.residuals')} — U</h4><div class="chart" id="pResU"></div></div>
      </div>

      ${state.history.length ? `<h3>${t('rep.calcs')}</h3><div class="table-wrap"><table>${historyTable(state.history, true)}</table></div>` : ''}
      ${state.warnings.length ? `<h3>${t('rep.warnings')}</h3><ul style="font-size:13px;margin:0;padding-inline-start:20px">${state.warnings.map(w => `<li>${esc(t(w))}</li>`).join('')}</ul>` : ''}
      <div class="p-foot">${t('rep.foot')}<br>${t('an.disclaimer')}</div>`;
    const o = { interactive: false };
    modelChart($('pChartC'), A, 'c', { ...o, height: 230 }); modelChart($('pChartU'), A, 'u', { ...o, height: 230 });
    residualChart($('pResC'), A, 'c', { ...o, height: 140 }); residualChart($('pResU'), A, 'u', { ...o, height: 140 });
  }

  function renderTabs() {
    document.querySelectorAll('.tab').forEach(b => {
      const on = b.dataset.tab === state.tab;
      b.classList.toggle('active', on);
      b.setAttribute('aria-selected', on);
      b.classList.toggle('done', !on && !!state.analysis && b.dataset.tab === 'data');
    });
    document.querySelectorAll('.panel').forEach(p => p.classList.toggle('active', p.id === 'panel-' + state.tab));
  }
  function go(tab) {
    state.tab = tab;
    renderTabs();
    if (tab === 'analysis') renderAnalysis();
    if (tab === 'calc') renderCalc();
    if (tab === 'report') renderReport();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  /* ---------- Actions ---------- */
  state.warnings = [];
  function runAnalysis() {
    const res = analyser();
    if (res.errors.length) {
      state.analysis = null;
      $('dataAlerts').innerHTML = alertsHtml(res.errors, 'err');
      $('dataAlerts').scrollIntoView({ behavior: 'smooth', block: 'center' });
      renderTabs();
      return;
    }
    $('dataAlerts').innerHTML = '';
    state.analysis = res.result;
    state.warnings = res.warnings;
    state.history = []; state.lastResult = null;
    $('c-input').value = ''; $('c-confirm').checked = false;
    $('calcAlerts').innerHTML = '';
    persist();
    toast(t('toast.analyzed'));
    go('analysis');
  }
  function changed() {
    if (state.analysis) {
      state.analysis = null; state.history = []; state.lastResult = null;
      $('c-confirm').checked = false;
      renderTabs();
    }
    $('dataAlerts').innerHTML = '';
    renderSummary();
    persist();
  }

  /* Calcul instantané à la saisie ; le bouton ajoute le résultat affiché à l'historique. */
  function liveCalc() {
    if (!state.analysis) return;
    $('calcAlerts').innerHTML = '';
    try {
      state.lastResult = calculer($('c-input').value, $('c-methodC').value, $('c-confirm').checked);
    } catch (err) {
      state.lastResult = null;
      $('calcAlerts').innerHTML = alertsHtml([err.message], 'err');
    }
    renderResult();
  }
  function runCalc() {
    liveCalc();
    if (state.lastResult) { state.history.push(state.lastResult); renderHistory(); }
  }

  const EXAMPLE = [['0', '0,1', '0,2'], ['10', '0,2', '0,22'], ['20', '0,3', '0,24'], ['30', '0,4', '0,26']];

  function loadExample() {
    setRows(EXAMPLE.map(r => r.map(v => (state.lang === 'fr' ? v : v.replace(',', '.')))));
    $('m-instrument').value = state.lang === 'fr' ? 'Thermomètre numérique' : 'ميزان حرارة رقمي';
    $('m-certificate').value = 'CE-2026-0142';
    $('m-unitI').value = '°C'; $('m-unitC').value = '°C'; $('m-unitU').value = '°C';
    $('m-nature').value = 'U';
    $('m-k').value = '2'; $('m-uncType').value = 'absolute';
    state.kVerified = true; updateKPill(); // jeu d'exemple : k = 2 fait partie des données
    updateUnits(); changed();
  }

  /* Import CSV (io/importerPoints) */
  function importCsv(text) {
    const lines = String(text).replace(/^﻿/, '').split(/\r?\n/).filter(l => l.trim());
    if (lines.length < 2) throw new Error(t('err.csvEmpty'));
    const delim = lines[0].includes(';') ? ';' : lines[0].includes('\t') ? '\t' : ',';
    const split = l => l.split(delim).map(v => v.trim().replace(/^"(.*)"$/, '$1'));
    const head = split(lines[0]).map(h => h.toLowerCase());
    const idx = ['indication', 'correction', 'incertitude'].map(n => head.indexOf(n));
    if (idx.some(i => i < 0)) throw new Error(t('err.csvHeader'));
    const rows = lines.slice(1).map((l, i) => {
      const c = split(l);
      if (c.length < 3) throw new Error(t('err.csvCols', { line: i + 2 }));
      return idx.map(k => c[k] ?? '');
    });
    if (!rows.length) throw new Error(t('err.csvEmpty'));
    setRows(rows); changed();
    toast(t('toast.imported', { n: rows.length }));
  }
  function readFile(file, cb) {
    if (file.size > MAX_TEXT) { $('dataAlerts').innerHTML = alertsHtml([t('err.tooLarge')], 'err'); return; }
    const r = new FileReader();
    r.onload = () => {
      try { cb(String(r.result)); } catch (err) { $('dataAlerts').innerHTML = alertsHtml([err.message], 'err'); go('data'); }
    };
    r.onerror = () => { $('dataAlerts').innerHTML = alertsHtml([t('err.csvRead')], 'err'); };
    r.readAsText(file);
  }

  /* ---------- Import PDF (certificat) ---------- */
  // pdf.js 3.11.174 depuis cdnjs, version figée et intégrité SHA-512 imposée (SRI) :
  // le navigateur refuse d'exécuter un fichier modifié, même d'un seul octet.
  const PDFJS = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/';
  const SRI = {
    lib: 'sha512-q+4liFwdPC/bNdhUpZx6aXDx/h77yEQtn4I1slHydcbZK34nLaR3cAeYSJshoxIOq3mjEf7xJE8YWIUHMn+oCQ==',
    worker: 'sha512-BbrZ76UNZq5BhH7LL7pn9A4TKQpQeNCHOo65/akfelcIBbcVvYWOFQKPXIrykE3qZxYjmDX573oa4Ywsc7rpTw==',
  };
  const MAX_PDF = 20 * 1024 * 1024, MAX_TEXT = 2 * 1024 * 1024;
  let pdfjsReady = null;
  function loadPdfJs() {
    if (!pdfjsReady) {
      pdfjsReady = new Promise((resolve, reject) => {
        const s = document.createElement('script');
        s.src = PDFJS + 'pdf.min.js';
        s.integrity = SRI.lib;
        s.crossOrigin = 'anonymous';
        s.referrerPolicy = 'no-referrer';
        s.onload = async () => {
          const lib = window.pdfjsLib;
          try {
            // Le worker est vérifié par fetch(integrity) puis servi en blob: (même origine).
            const res = await fetch(PDFJS + 'pdf.worker.min.js', { integrity: SRI.worker, mode: 'cors', credentials: 'omit', referrerPolicy: 'no-referrer' });
            if (!res.ok) throw new Error('worker');
            lib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(new Blob([await res.arrayBuffer()], { type: 'text/javascript' }));
            resolve(lib);
          } catch { pdfjsReady = null; reject(new Error(t('err.pdfLib'))); }
        };
        s.onerror = () => { pdfjsReady = null; reject(new Error(t('err.pdfLib'))); };
        document.head.append(s);
      });
    }
    return pdfjsReady;
  }

  /* Texte du PDF regroupé en lignes (même ordonnée), de haut en bas. */
  async function pdfRows(buffer) {
    const lib = await loadPdfJs();
    let doc;
    try {
      doc = await lib.getDocument({ data: buffer, isEvalSupported: false, enableXfa: false, disableFontFace: true }).promise;
    } catch { throw new Error(t('err.pdfRead')); }
    const rows = [];
    for (let p = 1; p <= doc.numPages; p++) {
      const tc = await (await doc.getPage(p)).getTextContent();
      const items = tc.items.filter(i => i.str && i.str.trim())
        .map(i => ({ x: i.transform[4], y: i.transform[5], s: i.str }))
        .sort((a, b) => b.y - a.y || a.x - b.x);
      const pageRows = [];
      items.forEach(it => {
        const r = pageRows.find(row => Math.abs(row.y - it.y) <= 3);
        if (r) r.items.push(it); else pageRows.push({ y: it.y, items: [it] });
      });
      pageRows.forEach(r => rows.push(r.items.sort((a, b) => a.x - b.x).map(i => i.s).join('  ')));
    }
    return rows;
  }

  const normUnit = u => u.trim().replace(/^º/, '°').replace(/^%\s*hr$/i, '%hr');

  /* Repère les lignes « référence · équipement · erreur · ±U · k » et les regroupe par grandeur. */
  function parseCertificate(rows) {
    const series = [];
    let current = null;
    const NUM = /(±|\+\/-)?\s*([-−–+]?\d+(?:[.,]\d+)?)/g;
    rows.forEach(text => {
      const title = text.match(/\b(Temp[ée]rature|Humidit[ée]|Pression|Masse|Tension|Courant|Longueur|R[ée]sistance|Fr[ée]quence|Force|Couple|D[ée]bit|Vitesse)[^()]*\(([^)]{1,12})\)/i);
      if (title && !/±/.test(text)) {
        current = { title: text.replace(/\s+/g, ' ').trim(), unit: normUnit(title[2]), points: [], inconsistent: false };
        series.push(current);
        return;
      }
      const tokens = [...text.matchAll(NUM)].map(m => ({ pm: !!m[1], v: parseNum(m[2]) }));
      const iU = tokens.findIndex(tk => tk.pm);
      if (iU < 2) return;
      const nums = tokens.slice(0, iU).map(tk => tk.v).slice(-3);
      const U = tokens[iU].v;
      if (!nums.every(Number.isFinite) || !Number.isFinite(U)) return;
      const { ref, eq, err, ok } = Core.ligneCertificat(nums, U);
      if (!current) { current = { title: t('series') + ' 1', unit: '', points: [], inconsistent: false }; series.push(current); }
      current.points.push({ ref, eq, err, x: eq, c: -err, u: Math.abs(U), ok, k: tokens[iU + 1]?.v ?? NaN });
      if (!ok) current.inconsistent = true;
    });
    const full = rows.join('\n');
    const after = re => { const m = full.match(re); return m ? m[1].replace(/\s{2,}/g, ' ').trim() : ''; };
    let date = after(/Date d['’]?\s*[ée]talonnage\s*:?\s*(\d{4}-\d{2}-\d{2}|\d{2}[/.-]\d{2}[/.-]\d{4})/i) || after(/\b(\d{4}-\d{2}-\d{2})\b/);
    const dm = date.match(/^(\d{2})[/.-](\d{2})[/.-](\d{4})$/);
    if (dm) date = `${dm[3]}-${dm[2]}-${dm[1]}`;
    // Les champs Constructeur/Type sont souvent dans une autre colonne que leur libellé : on ne les devine pas.
    const meta = {
      certificate: after(/Certificat\s*n[º°o.]*\s*:?\s*([A-Z0-9][\w/\-.]*)/i),
      instrument: after(/Instrument\s+[ée]talonn[ée]\s*:?\s*([^\n]+)/i),
      lab: after(/Local d['’]?\s*[ée]talonnage\s*:?\s*(?:Installations\s+)?([^\n]+)/i),
      date,
      // Nature U seulement si le certificat parle explicitement d'incertitude élargie (jamais déduite de « k = 2 »).
      nature: /incerti\w*\s+[ée]largie|expanded\s+uncertainty/i.test(full) ? 'U' : '',
    };
    return { series: series.filter(s => s.points.length), meta, hasText: full.replace(/\s/g, '').length > 20 };
  }

  async function importPdf(file) {
    if (file.size > MAX_PDF) throw new Error(t('err.tooLarge'));
    toast(t('pdf.reading'));
    const rows = await pdfRows(await file.arrayBuffer());
    const parsed = parseCertificate(rows);
    if (!parsed.hasText) throw new Error(t('pdf.scanned'));
    if (!parsed.series.length) throw new Error(t('pdf.none'));
    showPdfDialog(parsed, file.name);
  }

  function showPdfDialog(parsed, fileName) {
    const dlg = $('pdfDialog'), m = parsed.meta;
    const metaLine = [m.instrument, m.certificate, m.date].filter(Boolean).map(esc).join(' · ');
    $('pdfBody').innerHTML = `
      <div class="dlg-head">
        <div><h2>${icon('doc')}<span>${t('pdf.title')}</span></h2>
        <p class="card-sub">${esc(fileName)}${metaLine ? ' — ' + metaLine : ''}</p>
        <p class="card-sub">${t('pdf.sub', { n: parsed.series.length })}</p></div>
        <button class="icon-btn" type="button" data-close aria-label="${t('btn.cancel')}">${icon('x')}</button>
      </div>
      <div class="alert info">${icon('info')}<span>${t('pdf.verify')}</span></div>
      ${parsed.series.map((s, i) => `
        <div class="series">
          <div class="series-head">
            <div><b>${esc(s.title)}</b> <span class="pill neutral">${t('pdf.points', { n: s.points.length })}</span></div>
            <button class="btn primary" type="button" data-series="${i}">${icon('check')}<span>${t('btn.loadSeries')}</span></button>
          </div>
          ${s.inconsistent ? `<div class="alert warn">${icon('alert')}<span>${t('pdf.inconsistent')}</span></div>` : ''}
          <div class="table-wrap"><table class="history">
            <thead><tr><th>${t('pdf.ref')}</th><th>${t('pdf.eq')} → ${t('col.indication')}</th><th>${t('pdf.err')}</th><th>${t('col.correction')}</th><th>${t('col.uncertainty')}</th></tr></thead>
            <tbody>${s.points.map(p => `<tr${p.ok ? '' : ' class="row-warn"'}><td class="num-cell">${p.ok ? '' : icon('alert', 13) + ' '}${fmt(p.ref)}</td><td class="num-cell"><b>${fmt(p.eq)}</b></td><td class="num-cell">${fmt(p.err)}</td><td class="num-cell"><b>${fmt(p.c)}</b></td><td class="num-cell"><b>${fmt(p.u)}</b></td></tr>`).join('')}</tbody>
          </table></div>
        </div>`).join('')}`;
    dlg.onclick = e => {
      if (e.target === dlg || e.target.closest('[data-close]')) { dlg.close(); return; }
      const b = e.target.closest('[data-series]');
      if (!b) return;
      const s = parsed.series[+b.dataset.series];
      if (s.inconsistent && !confirm(t('pdf.confirmInconsistent'))) return;
      setRows(s.points.map(p => [rawStr(p.x), rawStr(+p.c.toPrecision(10)), rawStr(p.u)]));
      const kind = s.title.split(/[\s(,]/)[0];
      $('m-instrument').value = [m.instrument, parsed.series.length > 1 ? kind : ''].filter(Boolean).join(' — ');
      $('m-certificate').value = m.certificate; $('m-lab').value = m.lab; $('m-date').value = m.date;
      ['unitI', 'unitC', 'unitU'].forEach(f => { $('m-' + f).value = s.unit; });
      if (m.nature) $('m-nature').value = m.nature;
      // k seulement s'il est imprimé, identique, sur chaque ligne de la série ; sinon 2 « à vérifier ».
      const ks = s.points.map(p => p.k);
      const kCert = ks.every(v => Number.isFinite(v) && Math.abs(v - ks[0]) < 1e-9) ? ks[0] : NaN;
      $('m-k').value = Number.isFinite(kCert) ? rawStr(kCert) : '2';
      state.kVerified = Number.isFinite(kCert); updateKPill();
      $('m-uncType').value = 'absolute';
      updateUnits(); changed();
      dlg.close();
      go('data');
      toast(t('toast.pdf', { n: s.points.length }));
    };
    dlg.showModal();
  }

  function importFile(file) {
    if (/\.pdf$/i.test(file.name) || file.type === 'application/pdf') {
      importPdf(file).catch(err => { $('dataAlerts').innerHTML = alertsHtml([err.message], 'err'); go('data'); });
    } else {
      readFile(file, importCsv);
    }
  }

  function download(name, content, type) {
    const blob = new Blob([content], { type });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = name;
    document.body.append(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }
  const slug = () => (readMeta().certificate || readMeta().instrument || 'etalonnage').replace(/[^\w\-]+/g, '_').slice(0, 40) || 'etalonnage';

  function snapshot() {
    return { schema: 1, app: 'AnalyseurEtalonnage-web', meta: readMeta(), kVerified: state.kVerified, points: rawRows(), settings: readSettings() };
  }
  /* Session ou stockage local : données non fiables, on n'accepte que des chaînes courtes et un nombre borné de points. */
  const MAX_POINTS = 500;
  const str = (v, max = 200) => (typeof v === 'string' || typeof v === 'number' ? String(v).slice(0, max) : '');
  function restore(s) {
    if (!s || typeof s !== 'object' || !Array.isArray(s.points) || s.points.length > MAX_POINTS) throw new Error(t('err.session'));
    const meta = s.meta && typeof s.meta === 'object' ? s.meta : {};
    META_FIELDS.forEach(f => { $('m-' + f).value = str(meta[f]); });
    if (!['', 'U', 'u'].includes($('m-nature').value)) $('m-nature').value = '';
    if (!['absolute', 'relative'].includes($('m-uncType').value)) $('m-uncType').value = 'absolute';
    // k : 2 par défaut, mais signalé « à vérifier » tant qu'il ne vient pas du certificat ou de l'utilisateur.
    state.kVerified = s.kVerified === true && $('m-k').value.trim() !== '';
    if (!$('m-k').value.trim()) { $('m-k').value = '2'; state.kVerified = false; }
    updateKPill();
    const st = s.settings && typeof s.settings === 'object' ? s.settings : {};
    ['alphaC', 'alphaU', 'limitC', 'limitU'].forEach(k => { if (st[k] != null) $('s-' + k).value = str(st[k], 40); });
    setMode(st.mode === 'absolute' ? 'absolute' : 'fraction');
    setRows(s.points.map(r => [0, 1, 2].map(i => str(Array.isArray(r) ? r[i] : '', 40))));
    updateUnits();
  }
  function persist() { storage.set({ ...snapshot(), lang: state.lang, theme: state.theme }); }

  function exportCsv() {
    const A = state.analysis;
    if (!A) return;
    const d = v => (Number.isFinite(v) ? String(+v.toPrecision(12)).replace('.', ',') : '');
    const lines = [
      ['Indication', 'Correction', 'Incertitude', 'C_ajustee', 'Residu_C', 'U_ajustee', 'Residu_U', 'U_majorante'].join(';'),
      ...A.pts.map((p, i) => [p.x, p.c, p.u, A.c.ajuste[i], A.c.residu[i], A.u.ajuste[i], A.u.residu[i], A.maj.a * p.x + A.maj.b].map(d).join(';')),
      '',
      ['Modele', 'a', 'b', 'R2', 'Residu_max', 's_res', 'Seuil', 'Decision'].join(';'),
      ['Correction', d(A.c.a), d(A.c.b), d(A.c.R2), d(A.c.residuMax), d(A.c.sRes), d(A.sC), A.decC.ok ? 'Acceptable' : 'Non representatif'].join(';'),
      ['Incertitude', d(A.u.a), d(A.u.b), d(A.u.R2), d(A.u.residuMax), d(A.u.sRes), d(A.sU), A.decU.ok ? 'Acceptable' : 'Non representatif'].join(';'),
      ['U_prudente (majorante)', d(A.maj.a), d(A.maj.b), '', '', '', '', A.maj.usable ? 'Utilisable' : 'Non utilisable'].join(';'),
    ];
    if (state.history.length) {
      lines.push('', ['Calcul_indication', 'Correction', 'Valeur_corrigee', 'U_modelisee', 'U_prudente', 'k', 'Nature', 'Methode_C'].join(';'));
      state.history.forEach(r => lines.push([d(r.x), d(r.C), d(r.corrected), r.uFitOk ? d(r.uFit) : 'non exploitable', d(r.uPrudent), r.k, r.nature, r.methodC].join(';')));
    }
    download(`${slug()}_analyse.csv`, '﻿' + lines.join('\r\n'), 'text/csv;charset=utf-8');
    toast(t('toast.csv'));
  }

  function toast(msg) {
    const el = document.createElement('div');
    el.className = 'toast'; el.innerHTML = `${icon('check')}<span>${esc(msg)}</span>`;
    $('toasts').append(el);
    setTimeout(() => { el.style.transition = 'opacity .3s'; el.style.opacity = '0'; setTimeout(() => el.remove(), 300); }, 2400);
  }

  /* ---------- Language & theme ---------- */
  function applyLang() {
    const html = document.documentElement;
    html.lang = state.lang; html.dir = state.lang === 'ar' ? 'rtl' : 'ltr';
    document.title = t('app.title');
    document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-title]').forEach(el => { el.title = t(el.dataset.i18nTitle); el.setAttribute('aria-label', el.title); });
    $('langBtn').textContent = state.lang === 'ar' ? 'FR' : 'ع';
    $('langBtn').title = state.lang === 'ar' ? 'Français' : 'العربية';
    $('pointsCard').dataset.drop = t('drop2');
    setMode(state.mode); renumber(); renderSummary();
    if (state.tab === 'analysis') renderAnalysis();
    if (state.tab === 'calc') renderCalc();
    if (state.tab === 'report') renderReport();
  }
  function isDark() {
    return state.theme ? state.theme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function applyTheme() {
    if (state.theme) document.documentElement.dataset.theme = state.theme;
    else delete document.documentElement.dataset.theme;
    $('themeBtn').innerHTML = icon(isDark() ? 'sun' : 'moon', 17);
  }

  /* ---------- Wiring ---------- */
  document.querySelectorAll('[data-ico]').forEach(el => { el.outerHTML = icon(el.dataset.ico); });
  document.querySelectorAll('.tab').forEach(b => b.addEventListener('click', () => go(b.dataset.tab)));
  document.addEventListener('click', e => { const g = e.target.closest('[data-go]'); if (g) go(g.dataset.go); });
  $('addRowBtn').addEventListener('click', () => { addRow(['', '', ''], true); changed(); });
  $('exampleBtn').addEventListener('click', loadExample);
  $('clearBtn').addEventListener('click', () => { if (confirm(t('confirm.clear'))) { setRows([]); changed(); } });
  $('analyzeBtn').addEventListener('click', runAnalysis);
  $('calcBtn').addEventListener('click', runCalc);
  $('c-input').addEventListener('keydown', e => { if (e.key === 'Enter') runCalc(); });
  $('clearHistoryBtn').addEventListener('click', () => { state.history = []; renderHistory(); });
  $('c-input').addEventListener('input', liveCalc);
  $('c-methodC').addEventListener('change', liveCalc);
  $('c-confirm').addEventListener('change', liveCalc);
  $('m-k').addEventListener('input', () => { state.kVerified = $('m-k').value.trim() !== ''; updateKPill(); });
  $('importBtn').addEventListener('click', () => $('csvFile').click());
  $('csvFile').addEventListener('change', e => { const f = e.target.files[0]; if (f) importFile(f); e.target.value = ''; });
  $('saveSessionBtn').addEventListener('click', () => {
    download(`${slug()}_session.json`, JSON.stringify(snapshot(), null, 2), 'application/json');
    toast(t('toast.saved'));
  });
  $('loadSessionBtn').addEventListener('click', () => $('sessionFile').click());
  $('sessionFile').addEventListener('change', e => {
    const f = e.target.files[0]; e.target.value = '';
    if (!f) return;
    readFile(f, txt => {
      let s;
      try { s = JSON.parse(txt); } catch { throw new Error(t('err.session')); }
      restore(s); changed(); toast(t('toast.loaded'));
    });
  });
  $('csvBtn').addEventListener('click', exportCsv);
  $('xlsxBtn').addEventListener('click', () => {
    const A = state.analysis;
    if (!A) return;
    const bytes = window.EtalonnageXlsx.build(A, A.meta, { kVerified: state.kVerified });
    download(window.EtalonnageXlsx.fileName(A.meta), bytes, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    toast(t('toast.excel'));
  });
  $('printBtn').addEventListener('click', () => window.print());

  const card = $('pointsCard');
  ['dragenter', 'dragover'].forEach(ev => card.addEventListener(ev, e => { e.preventDefault(); card.classList.add('drag'); }));
  ['dragleave', 'drop'].forEach(ev => card.addEventListener(ev, e => {
    e.preventDefault();
    if (ev === 'dragleave' && card.contains(e.relatedTarget)) return;
    card.classList.remove('drag');
  }));
  card.addEventListener('drop', e => { const f = e.dataTransfer.files[0]; if (f) importFile(f); });

  $('langBtn').addEventListener('click', () => { state.lang = state.lang === 'ar' ? 'fr' : 'ar'; applyLang(); persist(); });
  $('themeBtn').addEventListener('click', () => { state.theme = isDark() ? 'light' : 'dark'; applyTheme(); persist(); });
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener?.('change', applyTheme);

  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      if (state.tab === 'analysis') drawAnalysisCharts();
      if (state.tab === 'calc' && state.lastResult) renderResult();
      if (state.tab === 'report') renderReport();
    }, 120);
  });
  window.addEventListener('beforeprint', () => { if (state.analysis && state.tab !== 'report') go('report'); });

  /* ---------- Init ---------- */
  const saved = storage.get();
  if (saved) {
    state.lang = saved.lang === 'ar' ? 'ar' : 'fr';
    state.theme = saved.theme === 'dark' || saved.theme === 'light' ? saved.theme : null;
    try { restore(saved); } catch { setRows([]); }
  } else {
    setRows([]);
    setMode('fraction');
    state.kVerified = false; // k = 2 pré-rempli, à vérifier
  }
  updateKPill();
  applyTheme();
  applyLang();
  renderTabs();
})();
