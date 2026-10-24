# Guide utilisateur — Analyse des données d’étalonnage

## Prérequis et installation

Cette livraison est un projet source MATLAB, pas un fichier `.mlapp` ni un exécutable. Elle vise MATLAB R2021a sous Windows. Aucune toolbox statistique n’est requise pour les calculs principaux. L’export Excel avancé requiert Windows et Microsoft Excel; l’application, l’analyse, les sessions MAT et les sorties graphiques/PDF restent indépendantes d’Excel. MATLAB Compiler est facultatif et n’est pas nécessaire pour lancer le code dans MATLAB.

Décompressez le dossier du projet dans un emplacement où vous avez le droit d’écrire. N’installez pas le projet dans `Program Files`. Ouvrez MATLAB, puis exécutez depuis n’importe quel répertoire :

```matlab
app = lancerApplication;
```

Le lanceur ajoute au chemin MATLAB les répertoires `app`, `core`, `io` et `config` relativement à lui-même; il n’utilise pas le Workspace de base comme stockage métier.

## Premier traitement

1. Dans « Données et modèles », saisissez les métadonnées utiles. Laissez la nature de l’incertitude « Inconnue » si le certificat ne permet pas de la déterminer; ne renseignez pas k par supposition.
2. Saisissez les trois colonnes ou choisissez « Importer Excel/CSV ». Les données importées apparaissent dans le tableau pour contrôle avant analyse.
3. « Charger l’exemple » renseigne un jeu exact de quatre points.
4. Vérifiez les données; corrigez explicitement toute erreur. Aucun texte invalide n’est remplacé par zéro.
5. Le réglage initial est 25 % de la moyenne des incertitudes fournies, un paramètre de prototype sans statut normatif. Vous pouvez sélectionner les seuils absolus.
6. Confirmez la procédure de validation utilisée, puis analysez. Un changement des données ou métadonnées invalide les résultats antérieurs.
7. Examinez les deux graphes, coefficients, R² et résidus. Si les points ne sont pas triés, le tri ne se fait qu’après confirmation et conserve les lignes entières.
8. Confirmez indépendamment les modèles de correction et d’incertitude pour l’exploitation. Le calculateur refuse une indication hors étendue et ne bascule jamais automatiquement d’une méthode à l’autre.
9. Exportez PDF/PNG, sauvegardez la session MAT ou demandez l’export Excel avancé.

## Imports et exports

Schéma d’import : `Indication;Correction;Incertitude`. Pour CSV, le séparateur conseillé est le point-virgule avec virgule décimale. Ne mélangez pas plusieurs conventions dans le même fichier. L’import Excel lit une feuille; en cas de classeur à plusieurs feuilles, l’utilisateur sélectionne la feuille. Le fichier source n’est jamais modifié. La session conserve les données brutes, les données numériques normalisées et le journal des transformations.

### Import d’un certificat PDF (extension)

Le bouton « Importer certificat PDF » lit un certificat PDF **contenant du texte** (PDF généré par le laboratoire, pas un scan) :

1. Choisissez le fichier `.pdf`. Le lecteur interne reconstruit les lignes de texte sans toolbox; si aucun tableau n’est trouvé et que Text Analytics Toolbox est installée, `extractFileText` est essayé ensuite.
2. Seules les lignes de résultat « valeur de référence | valeur de l’équipement | erreur | ±U | (k) » sont retenues, regroupées par grandeur à partir des titres du type « Température (ºC) » ou « Humidité (%hr) ». Les autres nombres du document sont ignorés.
3. Si plusieurs grandeurs sont détectées, choisissez la série à analyser (une analyse par grandeur).
4. Un aperçu affiche chaque point : référence, équipement, erreur imprimée, puis Correction = −Erreur et U. Rien n’est chargé sans votre accord.
5. Le tableau et les métadonnées trouvées (instrument, identifiant, certificat, date, conditions, unités) sont remplis. La nature « Élargie U » n’est retenue que si le certificat mentionne explicitement une incertitude élargie; k n’est renseigné que s’il est imprimé sur chaque ligne de la série.
6. Comparez chaque valeur au certificat original, puis vérifiez et analysez comme pour une saisie manuelle.

Si l’erreur imprimée ne correspond pas à « équipement − référence » (arrondi toléré), la valeur imprimée est conservée et le point est signalé. Un PDF numérisé, chiffré ou à polices non standard produit un message clair : saisissez alors les valeurs manuellement ou utilisez le modèle CSV. Le fichier PDF n’est jamais modifié; la session conserve les valeurs brutes (référence, équipement, erreur, U, k) et le journal d’import.

Les figures PNG sont exportées en haute résolution. Le rapport PDF est un rapport d’analyse, jamais un certificat d’étalonnage; il contient données, métadonnées, coefficients, résidus, décisions et limites. Les sessions `.mat` conservent les données, métadonnées, paramètres et méthodes; après réouverture, l’analyse doit être recalculée et les modèles reconfirmés.

Le classeur Excel avancé utilise une instance COM dédiée. Il ne ferme pas les sessions Excel personnelles. Les modifications des cellules de données existantes recalculent les formules; l’ajout/suppression de points nécessite de régénérer le classeur. Une édition dans Excel ne met pas à jour la session MATLAB.

## Tests

Dans MATLAB, depuis le dossier du projet :

```matlab
addpath(genpath(pwd)); runAllTests
```

Les résultats attendus sont fixés indépendamment dans `tests/TestRegression.m`. Les tests Excel COM nécessitent Windows + Excel et sont conditionnels. Aucun résultat MATLAB n’est revendiqué si MATLAB n’a pas été exécuté.

## App Designer

La source de l’interface se trouve dans `app/AnalyseurEtalonnageApp.m`. Cette classe exécutable emploie `uifigure`, `uitable`, `uiaxes`, onglets et mises en page redimensionnables; elle est une alternative source au fichier `.mlapp`, pas un `.mlapp` déguisé. Pour la reconstruire graphiquement dans App Designer, créez une application à onglets reprenant les champs, tableau, boutons et axes de cette classe, puis reliez les callbacks aux fonctions pur calcul du dossier `core/`. Gardez le moteur indépendant de l’interface.

## Compilation optionnelle

MATLAB Compiler n’était pas disponible pendant la production; aucune compilation n’a été faite. Si Compiler est installé, ouvrez MATLAB depuis le dossier racine et vérifiez `which mcc`, puis exécutez cette commande de départ :

```matlab
addpath(genpath(pwd));
if ~exist('build','dir'), mkdir('build'); end
mcc -m -v lancerApplication.m -a app -a core -a io -a config -a examples -d build
```

Validez l’artefact produit sur le poste cible avant distribution. L’exécutable nécessite le MATLAB Runtime correspondant à la version exacte de MATLAB Compiler utilisée. Une exécution dans MATLAB ne demande pas ce Runtime séparé. Dans les deux cas, l’export Excel COM reste dépendant d’Excel Windows. Aucune compatibilité compilée de cette voie n’est garantie sans test réel.
