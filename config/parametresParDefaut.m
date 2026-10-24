function options = parametresParDefaut()
%PARAMETRESPARDEFAUT Paramètres initiaux de l'analyse d'étalonnage.
% options contient le mode de seuil, ses fractions initiales, une tolérance
% numérique relative et la version du format de session.
options = struct();
options.modeSeuil = 'fraction';
options.alphaCorrection = 0.25;
options.alphaIncertitude = 0.25;
options.seuilCorrection = NaN;
options.seuilIncertitude = NaN;
options.toleranceRelative = 1e-10;
options.versionSchema = 1;
options.procedureConfirmee = false;
end
