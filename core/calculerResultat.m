function resultat = calculerResultat(indication,analyse,options,methodes)
%CALCULERRESULTAT Calcule seulement dans l'étendue avec modèles confirmés.
if nargin<3 || isempty(options), options=parametresParDefaut(); end
if nargin<4 || isempty(methodes), methodes=struct('confirme',false,'correction','regression','incertitude','majorante'); end
if ~isfield(methodes,'confirme') || ~methodes.confirme
    error('Etalonnage:ModelesNonConfirmes','Les modèles doivent être confirmés explicitement avant exploitation.');
end
if ~isscalar(indication) || ~isfinite(indication), error('Etalonnage:IndicationInvalide','L’indication doit être un nombre fini.'); end
if indication<analyse.etendue(1) || indication>analyse.etendue(2)
    error('Etalonnage:HorsEtendue','L’indication saisie est hors de l’étendue autorisée.');
end
switch methodes.correction
    case 'regression', C=analyse.correction.a*indication+analyse.correction.b;
    case 'interpolation'
        C=interp1(analyse.correction.x,analyse.correction.mesure,indication,'linear');
    otherwise, error('Etalonnage:MethodeInconnue','Méthode de correction non reconnue.');
end
if ~analyse.majorante.utilisable
    error('Etalonnage:IncertitudeNonExploitable','Le modèle d’incertitude donne une valeur négative dans l’étendue et ne peut pas être utilisé.');
end
switch methodes.incertitude
    case 'majorante'
        U=analyse.majorante.a*indication+analyse.majorante.b;
        uBornes=analyse.majorante.a*analyse.etendue+analyse.majorante.b;
    case 'ajustee'
        U=analyse.incertitude.a*indication+analyse.incertitude.b;
        uBornes=analyse.incertitude.a*analyse.etendue+analyse.incertitude.b;
    otherwise, error('Etalonnage:MethodeInconnue','Méthode d’incertitude non reconnue.');
end
if ~isfinite(U) || U<0 || any(uBornes<0), error('Etalonnage:IncertitudeNegative','Le modèle actif donne une incertitude négative dans l’étendue ou au point calculé.'); end
meta=analyse.metadata;
if ~isfield(meta,'natureIncertitude') || strcmpi(strtrim(char(string(meta.natureIncertitude))),'Inconnue')
    error('Etalonnage:NatureIncertitudeInconnue','La nature de l’incertitude doit être confirmée avant de présenter un résultat complet.');
end
if isfield(meta,'uniteIndication') && isfield(meta,'uniteCorrection') && ...
        ~isempty(meta.uniteIndication) && ~strcmp(strtrim(meta.uniteIndication),strtrim(meta.uniteCorrection))
    error('Etalonnage:UnitesIncompatibles','Le calcul I+C est bloqué : unités indication/correction incompatibles.');
end
resultat=struct('indication',indication,'correction',C,'valeurCorrigee',indication+C, ...
    'incertitude',U,'methodeCorrection',methodes.correction,'methodeIncertitude',methodes.incertitude, ...
    'etendue',analyse.etendue,'metadata',meta,'statut','Calcul dans l’étendue; interprétation métrologique à confirmer.');
end
