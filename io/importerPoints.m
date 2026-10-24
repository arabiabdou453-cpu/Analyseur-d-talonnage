function [T,info] = importerPoints(chemin,options)
%IMPORTERPOINTS Importe Indication, Correction, Incertitude sans modifier la source.
if nargin<2, options=struct(); end %#ok<NASGU>
[~,~,ext]=fileparts(chemin); info=struct('source',chemin,'feuille','','journal',{{}},'donneesBrutes',table());
if strcmpi(ext,'.xlsx') || strcmpi(ext,'.xls')
    feuilles=sheetnames(chemin);
    if numel(feuilles)>1
        [idx,ok]=listdlg('PromptString','Choisir la feuille de données :','SelectionMode','single','ListString',feuilles);
        if ~ok, error('Etalonnage:ImportAnnule','Import annulé par l’utilisateur.'); end
        feuille=feuilles{idx};
    else, feuille=feuilles{1}; end
    brut=readtable(chemin,'Sheet',feuille,'VariableNamingRule','preserve'); info.feuille=feuille;
elseif strcmpi(ext,'.csv')
    texte=fileread(chemin);
    if isempty(texte), error('Etalonnage:CSVVide','Le fichier CSV est vide.'); end
    lignes=regexp(texte,'\r?\n','split'); entete=lignes{1};
    nbSemi=sum(entete==';'); nbComma=sum(entete==',');
    if nbSemi>0, delim=';';
    elseif nbComma>=2, delim=',';
    else, error('Etalonnage:CSVAmbigu','Séparateur CSV non déterminé. Utilisez le modèle à trois colonnes.'); end
    opts=detectImportOptions(chemin,'Delimiter',delim,'VariableNamingRule','preserve');
    opts.VariableNamingRule='preserve'; brut=readtable(chemin,opts);
else
    error('Etalonnage:FormatImport','Formats acceptés : .csv, .xlsx et .xls.');
end
info.donneesBrutes=brut;
[T,info.journal]=normaliserDonnees(brut,struct());
end
