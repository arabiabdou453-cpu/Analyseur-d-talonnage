function [lignes,info] = extraireTextePDF(chemin)
%EXTRAIRETEXTEPDF Reconstruit les lignes de texte d'un PDF sans toolbox.
% [lignes,info] = extraireTextePDF(chemin) renvoie une cellule colonne de
% lignes, ordonnées de haut en bas dans chaque flux de contenu. Lecteur
% minimal : flux non compressés ou FlateDecode, polices simples (WinAnsi /
% Latin-1), opérateurs de texte (Tj, TJ, ', ") et de position (Td, TD, Tm,
% T*, TL, cm, q/Q). Les largeurs de glyphes ne sont pas lues : la position
% des segments d'un même TJ est estimée (0,55 em par caractère).
% Les PDF numérisés, chiffrés ou à polices CID ne donnent pas de texte
% exploitable. Le fichier source n'est jamais modifié.
if ~isfile(chemin), error('Etalonnage:FichierIntrouvable','Fichier introuvable : %s',chemin); end
fid=fopen(chemin,'r');
if fid<0, error('Etalonnage:LectureImpossible','Impossible d’ouvrir le fichier : %s',chemin); end
octets=fread(fid,Inf,'*uint8')'; fclose(fid);
s=char(octets); % octet n -> caractère n (Latin-1)
if numel(s)<5 || ~strcmp(s(1:5),'%PDF-')
    error('Etalonnage:PDFInvalide','Le fichier n’est pas un PDF valide.');
end
if contains(s,'/Encrypt')
    error('Etalonnage:PDFChiffre','PDF chiffré ou protégé : extraction impossible. Saisissez les valeurs manuellement.');
end
debuts=regexp(s,'(?<!end)stream\r?\n','end');
fins=strfind(s,'endstream');
objets=regexp(s,'\d+\s+\d+\s+obj','start');
info=struct('methode','lecteur interne','nbFlux',numel(debuts),'nbFluxTexte',0);
lignes=cell(0,1);
for k=1:numel(debuts)
    st=debuts(k)+1; en=fins(find(fins>st,1));
    if isempty(en), continue; end
    en=en-1;
    while en>=st && (octets(en)==10 || octets(en)==13), en=en-1; end
    o=objets(find(objets<debuts(k),1,'last')); if isempty(o), o=1; end
    dico=s(o:debuts(k));
    if ~isempty(regexp(dico,'/Subtype\s*/Image|/Type\s*/XRef|/Type\s*/ObjStm|/Length1|/FontFile|/EmbeddedFile','once')), continue; end
    donnees=octets(st:en);
    if contains(dico,'/FlateDecode')
        donnees=decompresser(donnees);
        if isempty(donnees), continue; end
    elseif contains(dico,'/Filter')
        continue; % autres filtres non pris en charge
    end
    texte=char(donnees);
    if isempty(regexp(texte,'\<BT\>','once')) || isempty(regexp(texte,'T[Jj]','once')), continue; end
    info.nbFluxTexte=info.nbFluxTexte+1;
    lignes=[lignes; lignesFlux(texte)]; %#ok<AGROW>
end
end

function out = decompresser(donnees)
% Décompression zlib par la JVM de MATLAB; flux tronqué : on garde la partie lisible.
out=uint8([]);
try
    z=java.util.zip.InflaterInputStream(java.io.ByteArrayInputStream(typecast(donnees,'int8')));
    o=java.io.ByteArrayOutputStream();
    copieur=com.mathworks.mlwidgets.io.InterruptibleStreamCopier.getInterruptibleStreamCopier();
    copieur.copyStream(z,o); z.close();
    out=typecast(o.toByteArray()','uint8');
catch
    try
        z=java.util.zip.InflaterInputStream(java.io.ByteArrayInputStream(typecast(donnees,'int8')));
        tampon=zeros(1,4096,'uint8'); n=0;
        try
            b=z.read();
            while b>=0
                n=n+1; if n>numel(tampon), tampon(2*end)=0; end
                tampon(n)=b; b=z.read();
            end
        catch
        end
        out=tampon(1:n);
    catch
    end
end
end

function lignes = lignesFlux(texte)
% Interprète un flux de contenu et regroupe le texte par ordonnée.
motif=['\((?:\\[\s\S]|[^\\()]|\((?:\\[\s\S]|[^\\()])*\))*\)|<<|>>|<[0-9A-Fa-f\s]*>|\[|\]|' ...
    '/[^\s/\[\]()<>{}%]*|[+-]?(?:\d+\.?\d*|\.\d+)|%[^\r\n]*|[A-Za-z''"*][A-Za-z0-9''"*]*'];
jetons=regexp(texte,motif,'match');
ctm=eye(3); pile={}; Tm=eye(3); Tlm=eye(3); TL=0; fs=1;
ops={}; tableau=[]; dansTableau=false;
X=zeros(0,1); Y=zeros(0,1); T=cell(0,1);
for q=1:numel(jetons)
    j=jetons{q}; c=j(1);
    if c=='%' || strcmp(j,'<<') || strcmp(j,'>>'), continue; end
    if c=='('
        ajouter({decoderLitteral(j)}); continue;
    elseif c=='<'
        ajouter({decoderHexa(j)}); continue;
    elseif c=='['
        tableau={}; dansTableau=true; continue;
    elseif c==']'
        ops{end+1}=struct('tableau',{tableau}); dansTableau=false; tableau=[]; continue; %#ok<AGROW>
    elseif c=='/'
        ajouter(j); continue;
    elseif any(c=='+-.0123456789')
        ajouter(str2double(j)); continue;
    end
    n=cell2mat(ops(cellfun(@(v)isnumeric(v)&&isscalar(v),ops)));
    switch j
        case 'q', pile{end+1}=ctm; %#ok<AGROW>
        case 'Q', if ~isempty(pile), ctm=pile{end}; pile(end)=[]; end
        case 'cm', if numel(n)>=6, ctm=matrice(n(end-5:end))*ctm; end
        case 'BT', Tm=eye(3); Tlm=eye(3);
        case 'Tf', if ~isempty(n), fs=n(end); end
        case 'TL', if ~isempty(n), TL=n(end); end
        case 'Td', if numel(n)>=2, deplacer(n(end-1),n(end)); end
        case 'TD', if numel(n)>=2, TL=-n(end); deplacer(n(end-1),n(end)); end
        case 'Tm', if numel(n)>=6, Tlm=matrice(n(end-5:end)); Tm=Tlm; end
        case 'T*', deplacer(0,-TL);
        case 'Tj', emettreDernier();
        case {'''','"'}, deplacer(0,-TL); emettreDernier();
        case 'TJ'
            idx=find(cellfun(@isstruct,ops),1,'last');
            if ~isempty(idx), emettreTableau(ops{idx}.tableau); end
    end
    ops={};
end
if isempty(T), lignes=cell(0,1); return; end
[~,ordre]=sortrows([-Y X (1:numel(Y))']); X=X(ordre); Y=Y(ordre); T=T(ordre);
lignes=cell(0,1); i=1;
while i<=numel(Y)
    jFin=i; while jFin<numel(Y) && abs(Y(jFin+1)-Y(i))<=2.5, jFin=jFin+1; end
    [~,o2]=sortrows([X(i:jFin) (i:jFin)']);
    morceaux=T(i-1+o2);
    ligne=strtrim(strjoin(morceaux','  '));
    ligne=ligne(ligne>=32 & ligne<=126 | ligne>=160 & ligne<=255);
    if ~isempty(strtrim(ligne)), lignes{end+1,1}=strtrim(ligne); end %#ok<AGROW>
    i=jFin+1;
end

    function ajouter(v)
        if dansTableau, tableau{end+1}=v; else, ops{end+1}=v; end
    end
    function deplacer(tx,ty)
        Tlm=[1 0 0;0 1 0;tx ty 1]*Tlm; Tm=Tlm;
    end
    function emettre(txt,dx)
        M=[1 0 0;0 1 0;dx*fs 0 1]*Tm*ctm;
        X(end+1,1)=M(3,1); Y(end+1,1)=M(3,2); T{end+1,1}=txt;
    end
    function emettreDernier()
        idx=find(cellfun(@iscell,ops),1,'last');
        if ~isempty(idx), emettre(ops{idx}{1},0); end
    end
    function emettreTableau(elements)
        % Un TJ peut porter plusieurs colonnes séparées par de grands décalages.
        avance=0; debut=0; seg='';
        for e=1:numel(elements)
            v=elements{e};
            if isnumeric(v)
                if v<-1000 && ~isempty(strtrim(seg))
                    emettre(seg,debut); seg=''; avance=avance-v/1000; debut=avance;
                else
                    avance=avance-v/1000; if isempty(seg), debut=avance; end
                end
            elseif iscell(v)
                if isempty(seg), debut=avance; end
                seg=[seg v{1}]; avance=avance+numel(v{1})*0.55; %#ok<AGROW>
            end
        end
        if ~isempty(strtrim(seg)), emettre(seg,debut); end
    end
end

function M = matrice(v)
M=[v(1) v(2) 0; v(3) v(4) 0; v(5) v(6) 1];
end

function out = decoderLitteral(j)
j=j(2:end-1); out=blanks(0); i=1; n=numel(j);
echap=struct('n',char(10),'r',char(13),'t',char(9),'b',char(8),'f',char(12));
while i<=n
    c=j(i);
    if c=='\' && i<n
        d=j(i+1);
        if any(d=='01234567')
            m=regexp(j(i+1:min(n,i+3)),'^[0-7]{1,3}','match','once');
            out(end+1)=char(mod(base2dec(m,8),256)); i=i+1+numel(m); %#ok<AGROW>
            continue;
        elseif isfield(echap,d)
            out(end+1)=echap.(d); %#ok<AGROW>
        elseif d==char(13) || d==char(10)
            if d==char(13) && i+2<=n && j(i+2)==char(10), i=i+1; end
        else
            out(end+1)=d; %#ok<AGROW>
        end
        i=i+2;
    else
        out(end+1)=c; i=i+1; %#ok<AGROW>
    end
end
end

function out = decoderHexa(j)
h=regexprep(j(2:end-1),'\s','');
if isempty(h), out=''; return; end
if mod(numel(h),2), h(end+1)='0'; end
out=char(hex2dec(reshape(h,2,[])'))';
end
