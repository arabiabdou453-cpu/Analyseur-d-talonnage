function [series,info] = importerCertificatPDF(chemin)
%IMPORTERCERTIFICATPDF Extrait les tableaux de résultats d'un certificat PDF.
% [series,info] = importerCertificatPDF(chemin) renvoie une structure par
% grandeur détectée (titre, unité, données Indication/Correction/Incertitude,
% valeurs brutes Référence/Équipement/Erreur/U/k, k, incohérences) et info
% (source, méthode d'extraction, métadonnées, journal, lignes lues).
% Point d'extension prévu par le brief : l'import PDF reste facultatif, ne
% modifie pas le fichier source et ne remplace pas la vérification humaine.
% Lecteur interne d'abord; extractFileText (Text Analytics Toolbox) ensuite
% s'il est installé et que le lecteur interne ne trouve aucun tableau.
[~,~,ext]=fileparts(chemin);
if ~strcmpi(ext,'.pdf'), error('Etalonnage:FormatImport','Seuls les fichiers .pdf sont acceptés ici.'); end
lignes=extraireTextePDF(chemin); methode='lecteur interne';
[series,meta,journal]=analyserTexteCertificat(lignes);
if isempty(series) && ~isempty(which('extractFileText'))
    try
        lignesTA=cellstr(splitlines(string(extractFileText(chemin))));
        [s2,m2,j2]=analyserTexteCertificat(lignesTA);
        if ~isempty(s2), series=s2; meta=m2; journal=j2; lignes=lignesTA; methode='extractFileText (Text Analytics Toolbox)'; end
    catch
        % Toolbox absente ou en échec : on garde le diagnostic du lecteur interne.
    end
end
if isempty(series)
    if ~any(~cellfun(@isempty,regexp(lignes,'[A-Za-z]{3}','once')))
        error('Etalonnage:PDFSansTexte',['Aucun texte exploitable dans ce PDF (document numérisé ou polices non prises en charge). ' ...
            'Saisissez les valeurs manuellement ou utilisez le modèle CSV.']);
    end
    error('Etalonnage:PDFSansTableau',['Aucun tableau « référence | équipement | erreur | ±U » reconnu dans ce PDF. ' ...
        'Saisissez les valeurs manuellement ou utilisez le modèle CSV.']);
end
journal=[{sprintf('Import PDF (%s) : %d série(s) détectée(s). Correction = −Erreur (référence − indication).',methode,numel(series))} journal];
info=struct('source',chemin,'methode',methode,'meta',meta,'journal',{journal},'lignes',{lignes});
end
