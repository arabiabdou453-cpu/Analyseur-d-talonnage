# Matrice de conformité au brief F1–F14

| Critère | État dans cette livraison | Limite ou note |
|---|---|---|
| F1 — Métadonnées | Partiel | Champs instrument, identifiant, grandeur, unités, certificat, date, nature U/u/inconnue, k, conditions et procédure dans l’interface, sessions et exports. Le calcul I+C compare les unités textuellement; aucune conversion dimensionnelle automatique. |
| F2 — Tableau de données | Partiel | Tableau éditable, ajout/suppression explicites, invalidation après modification. Les cellules non numériques sont rejetées; l’interface n’offre pas encore toutes les distinctions UX par cellule demandées. |
| F3 — Import | Partiel | Import CSV/XLS/XLSX, choix de feuille et aperçu; conversion virgule décimale/moins Unicode via le normaliseur. La demande d’arbitrage des formats CSV ambigus reste simplifiée et nécessite un fichier à séparateur clair. |
| F4 — Validation | Partiel | Au moins trois points, valeurs finies, U≥0, doublons, étendue et proposition de tri explicite. Les unités sont contrôlées pour bloquer I+C; la robustesse de conversion CSV dépend aussi de l’import MATLAB. |
| F5 — Régression correction | Partiel | OLS centrée, résidus signés/absolus, résidu max, R², s_res, test de référence. s_res est décrit comme indicateur d’ajustement. |
| F6 — Régression incertitude | Partiel | Droite ajustée, majorante par décalage b+e_max, test d’enveloppe aux points et blocage si négative aux bornes. |
| F7 — Décisions | Partiel | Seuils fraction/absolu, tolérance, décisions séparées, remarque R² et avertissement métrologique. La procédure est confirmée par une case de l’interface; la décision d’acceptation reste explicitement assumée par l’utilisateur. |
| F8 — Graphiques | Partiel | Nuages, droite ajustée et majorante, diagnostics résiduels dans figures exportées. L’interface affiche tableaux et nuages; les résidus ne sont pas un sous-onglet dédié. |
| F9 — Calculateur | Partiel | Hors étendue, confirmation, unités incompatibles et incertitude non exploitable bloquent le calcul; correction et incertitude restent choisies séparément. L’interface peut encore mieux présenter certains avertissements selon les métadonnées. |
| F10 — Interpolation alternative | Couvert au niveau du moteur | Méthode distincte, choix explicite dans le calculateur, bornée à l’étendue; ne modifie pas la validation du modèle U. |
| F11 — Export Excel | Partiel, non vérifié en exécution | Export COM dédié avec formules, majorante et graphiques XY liés. Excel/Windows n’étaient pas disponibles ici; aucune garantie de compatibilité COM sans essai réel. Ajouter/supprimer des points exige de régénérer le classeur. |
| F12 — PDF et PNG | Partiel, non vérifié en exécution | Fonctions d’export et rapport d’analyse, non certificat. MATLAB et rendu PDF n’étaient pas disponibles ici; accents/pagination restent à vérifier sur MATLAB R2021a. |
| F13 — Sessions | Partiel | MAT versionné, données originales et normalisées, métadonnées, paramètres, méthodes, statut, horodatage; confirmation et analyse invalidées à la réouverture. |
| Extension — Import PDF | Ajouté, non vérifié en exécution MATLAB | `io/extraireTextePDF.m` (lecteur interne sans toolbox), `io/analyserTexteCertificat.m` (repérage des lignes référence/équipement/erreur/±U), `io/importerCertificatPDF.m`, bouton « Importer certificat PDF » avec choix de série et aperçu obligatoire. Correction = −Erreur; k et nature U jamais supposés. Algorithme vérifié hors MATLAB sur le certificat ISQ réel (anonymisé dans les tests); tests `tests/TestImportPDF.m`. Pas d’OCR ni de garantie sur tous les formats de certificat. |
| F14 — Distribution | Partiel | Lanceur relatif au projet, guide et procédure Compiler optionnelle. Aucun `.mlapp`, exécutable ni test de compilation n’est revendiqué. |

**Validation environnementale** : ni MATLAB ni Octave n’étaient installés dans l’environnement de production. Les tests `matlab.unittest`, l’interface R2021a et les exports Excel COM/PDF n’ont donc pas été exécutés. Le code doit être essayé sur la version cible avant tout usage opérationnel.
