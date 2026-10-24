# Limites métrologiques et domaine d’emploi

- Les calculs sont des régressions linéaires ordinaires non pondérées. L’indication est traitée comme variable explicative sans modèle explicite de son incertitude.
- Les résidus et l’écart-type résiduel décrivent l’ajustement; `s_res` n’est pas automatiquement une incertitude élargie.
- La correction suit la convention `correction = référence − indication`; la valeur corrigée est `I + C(I)`.
- La majorante d’incertitude décale l’ordonnée à l’origine de la régression de l’incertitude d’un maximum de résidu absolu. Elle enveloppe les valeurs des points fournis (à la tolérance numérique près), mais ne garantit rien entre les points sans justification.
- L’incertitude fournie dans le certificat n’est pas un budget complet d’incertitude d’utilisation. Les contributions ne sont pas combinées arbitrairement.
- Une incertitude de type `u` n’est pas convertie en incertitude élargie. Aucune division par k n’est effectuée; k n’est jamais supposé égal à 2.
- Le seuil initial de 25 % de la moyenne des incertitudes est un paramètre du prototype uniquement, et non une prescription de GUM, ISO/IEC 17025 ou FD X 07-014.
- Un R² faible est une remarque informative, pas une règle universelle de rejet. Pour des données constantes, le R² est indéfini et ne rejette pas seul l’ajustement.
- L’acceptabilité selon un seuil de résidus n’est pas une validation métrologique complète, une accréditation, une déclaration de conformité, ni une décision automatique de périodicité.
- L’interpolation point par point des corrections est une méthode distincte, activée explicitement et limitée à l’étendue fournie. Elle ne valide pas l’incertitude.
- Les unités ne font l’objet d’aucune conversion automatique. Des unités indication/correction incompatibles bloquent le calcul de la valeur corrigée.
- L’import PDF est une aide à la saisie, pas une extraction universelle : il ne lit que les PDF contenant du texte et les tableaux « référence | équipement | erreur | ±U », sans OCR. Les valeurs extraites doivent être comparées au certificat original avant analyse.

La référence FD X 07-014 n’est pas interprétée ici; le logiciel n’implémente pas de règle normative et ne revendique pas de conformité GUM ou ISO/IEC 17025.
