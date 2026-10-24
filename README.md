# AnalyseurEtalonnage — MATLAB desktop

Application source en français pour analyser des données de certificat d’étalonnage, exploiter les modèles de correction/incertitude et produire des exports. Cible prévue : MATLAB R2021a sous Windows.

## Démarrage

```matlab
app = lancerApplication;
```

Import d’un certificat PDF : bouton « Importer certificat PDF » (voir le guide utilisateur). Les valeurs extraites sont affichées pour vérification avant tout chargement.

## Version web locale

يمكن استخدام نسخة الويب دون تثبيت MATLAB: افتح `webapp/index.html` في متصفح حديث (عربي / فرنسي، مظهر فاتح / داكن). المراحل: البيانات ← التحليل ← الحاسبة ← التقرير. اضغط «مثال» ثم «تحليل البيانات» لعرض النماذج والبواقي والرسوم. لاستيراد بياناتك، استخدم ملف CSV بالأعمدة `Indication;Correction;Incertitude` (سحب وإفلات أو لصق مباشر من Excel)، أو استورد **شهادة PDF** مباشرة: يستخرج التطبيق جداول (المرجع · الجهاز · الخطأ · ±U) ويحوّل الخطأ إلى تصحيح (C = −Erreur) مع نافذة مراجعة قبل التحميل. قراءة PDF تتطلب اتصالًا بالإنترنت (مكتبة pdf.js) ولا تعمل مع الشهادات الممسوحة ضوئيًا. يتيح التقرير الطباعة / PDF وتصدير CSV، ويمكن حفظ الجلسة وفتحها بصيغة JSON. تعمل النسخة محليًا داخل المتصفح ولا ترفع البيانات إلى أي خادم. (`webapp.html` هي النسخة الأولية السابقة.)

Consultez le [guide utilisateur](docs/GUIDE_UTILISATEUR.md), les [limites métrologiques](docs/LIMITES_METROLOGIQUES.md) et la [matrice de conformité F1–F14](docs/MATRICE_CONFORMITE.md).

## Structure

`app/` contient l’interface `uifigure` et ses callbacks. `core/` sépare normalisation, validation, régressions, décisions et calculateur. `io/` regroupe les imports CSV/Excel, l’export Excel COM, le rapport PDF, les PNG et les sessions. `config/` porte les paramètres par défaut; `examples/` fournit les jeux CSV et scripts de gabarit; `tests/` contient les tests `matlab.unittest`; `docs/` rassemble le mode d’emploi, les limites et la conformité.

## État de validation

Le code source et les tests sont livrés. MATLAB et Octave ne sont pas présents dans l’environnement de génération; les tests n’ont donc pas été exécutés. L’export COM doit être validé sur un poste Windows où Excel est installé. Cette livraison ne contient pas de `.mlapp` ni d’exécutable compilé.
