function analyse = analyserEtalonnage(T,metadata,options)
%ANALYSERETALONNAGE Analyse les modèles de correction et d'incertitude.
if nargin<2, metadata=struct(); end
if nargin<3 || isempty(options), options=parametresParDefaut(); end
v=validerDonnees(T,metadata,options);
if ~v.valide, error('Etalonnage:Validation','%s',strjoin(v.erreurs,newline)); end
U=T.Incertitude;
if strcmp(options.modeSeuil,'fraction')
    sC=options.alphaCorrection*mean(U); sU=options.alphaIncertitude*mean(U);
else
    sC=options.seuilCorrection; sU=options.seuilIncertitude;
end
c=ajusterDroite(T.Indication,T.Correction,options);
u=ajusterDroite(T.Indication,T.Incertitude,options);
bMaj=u.b+u.residuMax;
borne=[min(T.Indication) max(T.Indication)];
uBornes=u.a*borne+bMaj;
majorant=struct('a',u.a,'b',bMaj,'x',T.Indication,'y',u.a*T.Indication+bMaj, ...
    'bornes',uBornes,'utilisable',all(uBornes>=-options.toleranceRelative*max(1,max(abs(U)))), ...
    'residuMax',u.residuMax);
analyse=struct('correction',c,'incertitude',u,'majorante',majorant, ...
    'decisionCorrection',evaluerCritere(c,sC,options), ...
    'decisionIncertitude',evaluerCritere(u,sU,options), ...
    'seuilCorrection',sC,'seuilIncertitude',sU,'metadata',metadata,'validation',v, ...
    'etendue',borne,'dateAnalyse',datetime('now'));
end
