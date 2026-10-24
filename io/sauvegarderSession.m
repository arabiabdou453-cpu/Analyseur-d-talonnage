function sauvegarderSession(chemin,session)
%SAUVEGARDERSESSION Enregistre une session versionnée dans un MAT.
if ~isstruct(session), error('Etalonnage:SessionInvalide','La session doit être une structure.'); end
session.versionSchema=1; session.dateSauvegarde=datetime('now');
session.fichierFormat='AnalyseurEtalonnageSession';
save(chemin,'session','-v7');
end
