function resultats = runAllTests()
%RUNALLTESTS Exécute toute la suite matlab.unittest du projet.
racine=fileparts(fileparts(mfilename('fullpath'))); addpath(genpath(racine));
suite=testsuite(fullfile(racine,'tests'),'IncludeSubfolders',true);
resultats=run(suite); disp(table(resultats));
end
