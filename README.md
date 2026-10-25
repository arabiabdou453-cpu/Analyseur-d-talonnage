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

## Site web et application mobile

| Version | Adresse | Dossier | Tests |
|---|---|---|---|
| Site web | https://analyseur-etalonnage.vercel.app | `webapp/` | `webapp/tests.html` (servi localement, voir `webapp/start-server.bat`) |
| Application Flutter (Android / iOS, aperçu web) | https://analyseur-etalonnage-app.vercel.app | `mobile/` | `flutter test` dans `mobile/` |

Les deux versions partagent les mêmes règles métrologiques et les mêmes cas de test (dont le cas du cahier des charges : I = 50 → C = −0,1 ; valeur corrigée 49,9 ; U = 0,0766667 ; U prudente = 0,0848571 ; I = 120 et I = −5 bloqués) :

- régression linéaire par moindres carrés ordinaires, non pondérée ; résidu e = y − (a·x + b) ;
- n < 2 bloqué, n = 2 averti (droite exacte, non représentative) ;
- incertitude relative (% de la lecture) convertie en absolue avant régression, valeur d’origine conservée ;
- U prudente = U modélisée + résidu max (recommandée) ; U modélisée négative signalée « non exploitable », jamais remplacée par 0 ;
- affichage : U à 2 chiffres significatifs arrondie vers le haut, correction avec le même nombre de décimales ; valeurs stockées jamais arrondies ;
- hors étendue bloqué ; k = 2 pré-rempli mais « à vérifier » tant qu’il n’est pas lu sur le certificat ; alerte de linéarité ; bandeau si certificat expiré ;
- export Excel « Interpolation » / « Modélisation » avec vraies formules (SLOPE, INTERCEPT, RSQ, COUNT, MAX), valeurs en cache et graphique XY avec tendance.

Chaque `git push` sur `main` redéploie le site et l’application ; le déploiement de l’application exécute d’abord tous les tests et s’arrête au moindre échec.

## Structure

`app/` contient l’interface `uifigure` et ses callbacks. `core/` sépare normalisation, validation, régressions, décisions et calculateur. `io/` regroupe les imports CSV/Excel, l’export Excel COM, le rapport PDF, les PNG et les sessions. `config/` porte les paramètres par défaut; `examples/` fournit les jeux CSV et scripts de gabarit; `tests/` contient les tests `matlab.unittest`; `docs/` rassemble le mode d’emploi, les limites et la conformité.

## État de validation

Le code source et les tests sont livrés. MATLAB et Octave ne sont pas présents dans l’environnement de génération; les tests n’ont donc pas été exécutés. L’export COM doit être validé sur un poste Windows où Excel est installé. Cette livraison ne contient pas de `.mlapp` ni d’exécutable compilé.
