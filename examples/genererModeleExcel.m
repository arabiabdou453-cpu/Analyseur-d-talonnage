function genererModeleExcel(dossier)
%GENERERMODELEEXCEL Génère un classeur vierge de saisie.
if nargin<1, dossier=fileparts(mfilename('fullpath')); end
creerModelesImport(dossier);
end
