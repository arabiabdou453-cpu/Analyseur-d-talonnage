function resultats = runTests()
%RUNTESTS Point d'entrée racine pour l'ensemble de la suite.
racine=fileparts(mfilename('fullpath')); addpath(genpath(racine)); resultats=runAllTests();
end
