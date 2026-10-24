function [series,meta,journal] = analyserTexteCertificat(lignes)
%ANALYSERTEXTECERTIFICAT Repère les tableaux de résultats d'un certificat.
% [series,meta,journal] = analyserTexteCertificat(lignes) lit des lignes de
% texte (cellule ou string) et ne retient que les lignes de résultat de la
% forme : valeur de référence | valeur de l'équipement | erreur | ±U | (k).
% Les autres nombres du document sont ignorés. Une ligne de titre du type
% « Température (ºC) » ouvre une nouvelle série.
% Convention : Erreur = indication - référence ; Correction = -Erreur.
% Le signe imprimé de l'erreur est conservé; k n'est renseigné que s'il est
% imprimé sur chaque ligne de la série.
lignes=cellstr(string(lignes(:)));
pm=char(177); moins=[char(8722) char(8211)];
grandeurs='(Temp[ée]rature|Humidit[ée]|Pression|Masse|Tension|Courant|Longueur|R[ée]sistance|Fr[ée]quence|Force|Couple|D[ée]bit|Vitesse)';
series=struct('titre',{},'grandeur',{},'unite',{},'donnees',{},'brut',{},'k',{},'incoherences',{});
journal={}; courant=0; brutes={};
for q=1:numel(lignes)
    L=strtrim(lignes{q});
    titre=regexpi(L,[grandeurs '[^()]*\(([^)]{1,12})\)'],'tokens','once');
    if ~isempty(titre) && ~contains(L,pm)
        courant=numel(series)+1;
        series(courant).titre=regexprep(L,'\s+',' '); series(courant).grandeur=normaliserGrandeur(titre{1});
        series(courant).unite=normaliserUnite(titre{2}); brutes{courant}=zeros(0,5); %#ok<AGROW>
        continue;
    end
    jetons=regexp(L,['(?<pm>' pm '|\+/-)?\s*(?<v>[-+' moins ']?\d+(?:[.,]\d+)?)'],'names');
    if isempty(jetons), continue; end
    estPM=~cellfun(@isempty,{jetons.pm});
    iU=find(estPM,1);
    if isempty(iU) || iU<3, continue; end
    v=cellfun(@nombre,{jetons.v});
    avant=v(max(1,iU-3):iU-1); U=abs(v(iU));
    if numel(v)>iU, kLigne=v(iU+1); else, kLigne=NaN; end
    if any(~isfinite(avant)) || ~isfinite(U), continue; end
    coherent=true;
    if numel(avant)==3
        a=avant(1); b=avant(2); c=avant(3); tol=max(0.03,0.15*abs(c));
        if abs(b-a-c)<=tol, ref=a; eq=b; err=c;
        elseif abs(a-b-c)<=tol, eq=a; ref=b; err=c;
        else, ref=a; eq=b; err=c; coherent=false;
        end
    else
        % Erreur non imprimée : recalculée mais signalée (colonnes possiblement mélangées).
        ref=avant(1); eq=avant(2); err=eq-ref; coherent=false;
        journal{end+1}=sprintf('Ligne PDF %d : erreur absente, recalculée comme équipement − référence.',q); %#ok<AGROW>
    end
    if courant==0
        courant=1; series(1).titre='Série 1'; series(1).grandeur=''; series(1).unite=''; brutes{1}=zeros(0,5);
    end
    brutes{courant}(end+1,:)=[ref eq err U kLigne];
    if ~coherent
        series(courant).incoherences(end+1)=size(brutes{courant},1);
    end
end
garder=true(1,numel(series));
for s=1:numel(series)
    B=brutes{s};
    if isempty(B), garder(s)=false; continue; end
    series(s).brut=table(B(:,1),B(:,2),B(:,3),B(:,4),B(:,5),'VariableNames',{'Reference','Equipement','Erreur','Incertitude','k'});
    series(s).donnees=table(B(:,2),-B(:,3),B(:,4),'VariableNames',{'Indication','Correction','Incertitude'});
    k=B(:,5);
    if all(isfinite(k)) && all(abs(k-k(1))<1e-9), series(s).k=k(1); else, series(s).k=NaN; end
    if isempty(series(s).incoherences), series(s).incoherences=zeros(1,0); end
    if ~isempty(series(s).incoherences)
        journal{end+1}=sprintf('%s : erreur imprimée incohérente avec équipement − référence aux points %s.', ...
            series(s).titre,mat2str(series(s).incoherences)); %#ok<AGROW>
    end
end
series=series(garder);
meta=lireMetadonnees(lignes);
end

function x = nombre(t)
t=strrep(strrep(strrep(t,char(8722),'-'),char(8211),'-'),',','.');
x=str2double(t);
end

function u = normaliserUnite(u)
u=strtrim(u);
u=strrep(u,char(186),char(176)); % º -> °
if strcmpi(u,'%hr') || strcmpi(u,'% hr'), u='%hr'; end
end

function g = normaliserGrandeur(g)
g=lower(g); g(1)=upper(g(1));
end

function meta = lireMetadonnees(lignes)
meta=struct('instrument','','identifiant','','certificat','','dateEtalonnage','', ...
    'natureIncertitude','','conditions','');
texte=strjoin(lignes',newline);
meta.certificat=valeur(texte,['Certificat\s*n.{0,2}\s*:?\s*([A-Z0-9][\w/\-.]*)']);
instrument=valeur(texte,'Instrument\s+[ée]talonn[ée]\s*:?\s*([^\n]+)');
details=strjoin(nonVides({valeur(texte,'Constructeur\s*:?\s*([^\n]+)'),valeur(texte,'\nType\s*:?\s*([^\n]+)')}),' ');
meta.instrument=strjoin(nonVides({instrument,details}),' — ');
meta.identifiant=valeur(texte,'N.{0,2}\s*ident\.?\s*:?\s*([^\n]+)');
d=valeur(texte,'Date\s*d.?\s*[ée]talonnage\s*:?\s*(\d{4}-\d{2}-\d{2}|\d{2}[/.\-]\d{2}[/.\-]\d{4})');
m=regexp(d,'^(\d{2})[/.\-](\d{2})[/.\-](\d{4})$','tokens','once');
if ~isempty(m), d=sprintf('%s-%s-%s',m{3},m{2},m{1}); end
meta.dateEtalonnage=d;
meta.conditions=valeur(texte,'Condition\w*\s+ambiante\w*\s*:?\s*([^\n]+)');
% Nature U seulement si le certificat parle explicitement d'incertitude élargie.
if ~isempty(regexpi(texte,'Incerti\w*\s+[ée]largie','once')), meta.natureIncertitude='Élargie U'; end
end

function v = valeur(texte,motif)
t=regexpi(texte,motif,'tokens','once');
if isempty(t), v=''; else, v=strtrim(regexprep(t{1},'\s{2,}',' ')); end
end

function c = nonVides(c)
c=c(~cellfun(@isempty,c));
end
