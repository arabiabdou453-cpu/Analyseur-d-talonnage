function creerModelesImport(dossier)
%CREERMODELESIMPORT Crée un gabarit Excel vierge avec les en-têtes requis.
if nargin<1, dossier=pwd; end
f=fullfile(dossier,'modele_import.xlsx');
T=cell2table(cell(0,3),'VariableNames',{'Indication','Correction','Incertitude'});
writetable(T,f,'Sheet','Donnees');
fprintf('Modèle de saisie créé : %s\n',f);
end
