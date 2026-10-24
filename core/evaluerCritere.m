function decision = evaluerCritere(modele,seuil,options)
%EVALUERCRITERE Décision e_max <= seuil avec tolérance numérique documentée.
if nargin<3, options=parametresParDefaut(); end
if ~isscalar(seuil) || ~isfinite(seuil) || seuil<0
    error('Etalonnage:SeuilInvalide','Le seuil doit être un scalaire fini et non négatif.');
end
tol=options.toleranceRelative*max([1 abs(seuil) modele.residuMax]);
ok=modele.residuMax <= seuil+tol;
if ok, texte='Modèle acceptable selon le critère sur les résidus';
else, texte='Modèle non représentatif selon le critère sur les résidus'; end
if modele.variableConstante, r2='Non défini : données constantes';
elseif modele.R2<0.5, r2='R² faible : remarque informative, sans règle universelle de rejet';
else, r2=''; end
decision=struct('acceptable',ok,'seuil',seuil,'residuMax',modele.residuMax,'tolerance',tol, ...
    'message',texte,'remarqueR2',r2,'avertissement','Ce contrôle ne constitue pas à lui seul une validation métrologique complète.');
end
