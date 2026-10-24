function session = chargerSession(chemin)
%CHARGERSESSION Charge les données et paramètres; les résultats stockés ne sont pas fiables.
s=load(chemin,'session');
if ~isfield(s,'session') || ~isstruct(s.session) || ~isfield(s.session,'versionSchema')
    error('Etalonnage:SessionIncompatible','Fichier de session absent ou incompatible.');
end
session=s.session;
if session.versionSchema~=1 || ~isfield(session,'donnees') || ~isfield(session,'metadata') || ~isfield(session,'options')
    error('Etalonnage:SessionIncompatible','Version de session non prise en charge ou champs obligatoires absents.');
end
if isfield(session,'analyse'), session=rmfield(session,'analyse'); end
session.modelesConfirmes=false;
end
