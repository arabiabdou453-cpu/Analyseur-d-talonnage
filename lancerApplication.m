function app = lancerApplication()
%LANCERAPPLICATION Lance l'analyseur depuis n'importe quel répertoire.
racine=fileparts(mfilename('fullpath'));
addpath(fullfile(racine,'app'),fullfile(racine,'core'),fullfile(racine,'io'),fullfile(racine,'config'));
app=AnalyseurEtalonnageApp();
end
