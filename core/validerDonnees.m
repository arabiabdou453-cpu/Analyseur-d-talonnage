function rapport = validerDonnees(T, metadata, options)
%VALIDERDONNEES Contrôle les points, unités, seuils et métadonnées.
if nargin < 2 || isempty(metadata), metadata = struct(); end
if nargin < 3 || isempty(options), options = parametresParDefaut(); end
rapport = struct('valide',false,'erreurs',{{}},'avertissements',{{}},'trieRecommande',false,'ordreTri',[]);
attendus={'Indication','Correction','Incertitude'};
if ~istable(T) || ~all(ismember(attendus,T.Properties.VariableNames))
    rapport.erreurs={'Etalonnage:Schema: table requise avec Indication, Correction, Incertitude.'}; return;
end
n=height(T);
if n<3, rapport.erreurs{end+1}='Etalonnage:PointsInsuffisants: au moins trois points sont requis.'; end
for j=1:numel(attendus)
    v=T.(attendus{j});
    if ~isnumeric(v) || ~isreal(v)
        rapport.erreurs{end+1}=sprintf('Etalonnage:ValeurInvalide: colonne %s doit être réelle et numérique.',attendus{j});
    elseif any(~isfinite(v))
        r=find(~isfinite(v),1); rapport.erreurs{end+1}=sprintf('Ligne %d, colonne %s : valeur non finie.',r,attendus{j});
    end
end
X=T.Indication; U=T.Incertitude;
if isnumeric(U) && isreal(U)
    if any(U<0), r=find(U<0,1); rapport.erreurs{end+1}=sprintf('Ligne %d, colonne Incertitude : valeur négative interdite.',r); end
    if any(U==0), rapport.avertissements{end+1}='Une ou plusieurs incertitudes sont nulles; confirmez ces valeurs.'; end
end
if isnumeric(X) && isreal(X) && all(isfinite(X))
    [vals,~,g]=unique(X);
    counts=accumarray(g,1);
    dup=find(counts>1,1);
    if ~isempty(dup)
        rr=find(X==vals(dup)); rapport.erreurs{end+1}=sprintf('Deux indications identiques ont été détectées aux lignes %d et %d.',rr(1),rr(2));
    end
    if n>=2
        e=max(X)-min(X); scale=max(abs(X));
        if e==0 || e<=eps(max(scale,1))*max(1,n)
            rapport.erreurs{end+1}='Etalonnage:EtendueNulle: étendue nulle ou numériquement dégénérée.';
        end
        if any(diff(X)<=0)
            rapport.trieRecommande=true; [~,rapport.ordreTri]=sort(X);
            rapport.avertissements{end+1}='Les indications ne sont pas strictement croissantes; un tri explicite est recommandé.';
        end
    end
end
if isfield(options,'modeSeuil') && strcmp(options.modeSeuil,'absolu')
    s=[options.seuilCorrection options.seuilIncertitude];
    if any(~isfinite(s)) || any(s<0), rapport.erreurs{end+1}='Etalonnage:SeuilInvalide: les seuils doivent être finis et non négatifs.'; end
elseif isfield(options,'modeSeuil') && strcmp(options.modeSeuil,'fraction')
    alpha=[options.alphaCorrection options.alphaIncertitude];
    if any(~isfinite(alpha)) || any(alpha<0), rapport.erreurs{end+1}='Etalonnage:FractionSeuilInvalide: les fractions doivent être finies et non négatives.'; end
end
if isfield(metadata,'uniteIndication') && isfield(metadata,'uniteCorrection') && ...
        ~isempty(metadata.uniteIndication) && ~isempty(metadata.uniteCorrection) && ...
        ~strcmp(strtrim(char(string(metadata.uniteIndication))),strtrim(char(string(metadata.uniteCorrection))))
    rapport.avertissements{end+1}='Unités indication/correction différentes : le calcul I+C est bloqué sans conversion documentée.';
end
rapport.valide=isempty(rapport.erreurs);
if n==3, rapport.avertissements{end+1}='Trois points seulement : la validation reste limitée.'; end
end
