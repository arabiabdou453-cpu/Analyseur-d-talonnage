function [T, journal] = normaliserDonnees(Tbrut, options)
%NORMALISERDONNEES Normalise les trois colonnes numériques sans perdre l'origine.
% [T,journal] = normaliserDonnees(Tbrut,options) accepte une table ou une
% table convertible en Indication, Correction, Incertitude. Les valeurs sont
% conservées en double; texte, cellule vide, complexe, NaN et Inf sont rejetés.
if nargin < 2, options = struct(); end %#ok<NASGU>
if ~istable(Tbrut)
    error('Etalonnage:TypeDonnees','Les données doivent être fournies dans une table MATLAB.');
end
noms = Tbrut.Properties.VariableNames;
attendus = {'Indication','Correction','Incertitude'};
for k = 1:numel(attendus)
    if ~any(strcmpi(noms,attendus{k}))
        error('Etalonnage:ColonneManquante','Colonne manquante : %s.',attendus{k});
    end
end
journal = {};
T = table();
for k = 1:numel(attendus)
    idx = find(strcmpi(noms,attendus{k}),1);
    v = Tbrut.(noms{idx});
    if isnumeric(v)
        if ~isreal(v)
            r=find(imag(v)~=0,1); error('Etalonnage:ValeurComplexe','Ligne %d, colonne %s : valeur complexe interdite.',r,attendus{k});
        end
        v = double(v(:));
    elseif iscell(v) || isstring(v) || ischar(v) || iscategorical(v)
        if ischar(v), v = cellstr(v); end
        if iscategorical(v), v = cellstr(v); end
        v = string(v(:));
        nums = zeros(numel(v),1);
        for r = 1:numel(v)
            s = char(strtrim(v(r)));
            s = strrep(s,char(160),' '); s = strrep(s,char(8239),' ');
            s = strrep(s,'−','-'); s = strrep(s,'–','-');
            if strcmp(attendus{k},'Incertitude') && startsWith(strtrim(s),'±')
                s = strtrim(s(2:end)); journal{end+1} = sprintf('Ligne %d : signe ± retiré dans Incertitude.',r); %#ok<AGROW>
            end
            s = strrep(s,' ','');
            if contains(s,',') && ~contains(s,'.'), s = strrep(s,',','.'); end
            if isempty(s), error('Etalonnage:CelluleVide','Ligne %d, colonne %s : cellule vide.',r,attendus{k}); end
            nums(r) = str2double(s);
            if ~isfinite(nums(r)), error('Etalonnage:ValeurInvalide','Ligne %d, colonne %s : valeur non numérique ou non finie.',r,attendus{k}); end
        end
        v = nums;
        journal{end+1} = sprintf('Colonne %s convertie depuis du texte.',attendus{k}); %#ok<AGROW>
    else
        error('Etalonnage:TypeColonne','Type non pris en charge pour la colonne %s.',attendus{k});
    end
    if any(~isfinite(v)), r=find(~isfinite(v),1); error('Etalonnage:ValeurInvalide','Ligne %d, colonne %s : valeur non finie.',r,attendus{k}); end
    T.(attendus{k}) = v;
end
if height(T) ~= height(Tbrut), error('Etalonnage:Dimensions','Les colonnes n''ont pas la même longueur.'); end
end
