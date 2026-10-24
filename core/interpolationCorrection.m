function correction = interpolationCorrection(indication,modele)
%INTERPOLATIONCORRECTION Interpolation linéaire point par point, dans l'étendue.
% La méthode alternative ne valide pas le modèle d'incertitude.
if indication<min(modele.x) || indication>max(modele.x)
    error('Etalonnage:HorsEtendue','L’indication est hors de l’étendue autorisée.');
end
correction=interp1(modele.x,modele.mesure,indication,'linear');
end
