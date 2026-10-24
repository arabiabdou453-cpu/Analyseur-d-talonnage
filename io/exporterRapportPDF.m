function exporterRapportPDF(chemin,T,analyse,metadata,options)
%EXPORTERRAPPORTPDF Génère un rapport d'analyse PDF avec MATLAB de base.
% Le document n'est pas un certificat d'étalonnage.
if nargin<5, options=parametresParDefaut(); end
[dossier,~,~]=fileparts(chemin); if isempty(dossier), dossier=pwd; end
if exist(chemin,'file') && ~askOverwrite(chemin), error('Etalonnage:ExportAnnule','Écrasement annulé.'); end
tmp=tempname(dossier); mkdir(tmp); cleanup=onCleanup(@()rmdirIfExists(tmp));
figs=exporterFiguresPNG(tmp,T,analyse,metadata,options);
f=figure('Visible','off','Color','w','Position',[100 100 900 1200]); c=onCleanup(@()closeIfValid(f));
annotation(f,'textbox',[.06 .88 .88 .1],'String','RAPPORT D’ANALYSE DES DONNÉES D’ÉTALONNAGE','FontSize',16,'FontWeight','bold','EdgeColor','none');
meta=sprintf('Instrument : %s\nIdentifiant : %s\nGrandeur : %s\nCertificat : %s\nDate : %s\nNature incertitude : %s\nk : %s\n', ...
    fieldOr(metadata,'instrument','—'),fieldOr(metadata,'identifiant','—'),fieldOr(metadata,'grandeur','—'),fieldOr(metadata,'certificat','—'),fieldOr(metadata,'dateEtalonnage','—'),fieldOr(metadata,'natureIncertitude','inconnue'),fieldOr(metadata,'k','inconnu'));
annotation(f,'textbox',[.06 .69 .42 .17],'String',meta,'FontSize',10,'Interpreter','none','EdgeColor',[.8 .8 .8]);
summary=sprintf(['Correction : a=%.12g, b=%.12g, e_max=%.6g, R2=%s, s_res=%.6g\nDécision : %s\nRemarque R2 : %s\n' ...
    'Incertitude : a=%.12g, b=%.12g, b_majorant=%.12g, e_max=%.6g, R2=%s, s_res=%.6g\n' ...
    'Décision : %s\nRemarque R2 : %s\nÉtendue : [%.8g, %.8g]\n\nLimites : enveloppe aux points fournis; aucune garantie entre points. Le seuil est un réglage de prototype, non une règle normative.'], ...
    analyse.correction.a,analyse.correction.b,analyse.correction.residuMax,r2txt(analyse.correction.R2),analyse.correction.sRes,analyse.decisionCorrection.message,analyse.decisionCorrection.remarqueR2, ...
    analyse.incertitude.a,analyse.incertitude.b,analyse.majorante.b,analyse.incertitude.residuMax,r2txt(analyse.incertitude.R2),analyse.incertitude.sRes,analyse.decisionIncertitude.message,analyse.decisionIncertitude.remarqueR2,analyse.etendue(1),analyse.etendue(2));
annotation(f,'textbox',[.52 .60 .42 .27],'String',summary,'FontSize',9,'Interpreter','none','EdgeColor',[.8 .8 .8]);
tabData=[T.Indication T.Correction analyse.correction.ajuste analyse.correction.residuSigne T.Incertitude analyse.incertitude.ajuste analyse.incertitude.residuSigne];
uitable(f,'Data',tabData,'ColumnName',{'Indication','C mesurée','C ajustée','Résidu C signé','U fournie','U ajustée','Résidu U signé'},'Units','normalized','Position',[.04 .37 .92 .24]);
annotation(f,'textbox',[.06 .08 .88 .23],'String',['Ce contrôle ne constitue pas à lui seul une validation métrologique complète.' newline ...
    'L’incertitude du certificat n’est pas automatiquement celle de la mesure future. Une incertitude type n’est pas convertie en incertitude élargie; k n’est jamais supposé.'], ...
    'FontSize',10,'Interpreter','none','EdgeColor','none');
exportgraphics(f,chemin,'ContentType','vector'); clear c
% Pages figures ajoutées au PDF dans l'ordre correction, incertitude.
for k=1:numel(figs)
    g=figure('Visible','off','Color','w'); cc=onCleanup(@()closeIfValid(g)); im=imread(figs{k}); image(im); axis off; axis image;
    exportgraphics(g,chemin,'Append',true,'ContentType','image'); clear cc
end
clear cleanup
end
function t=r2txt(v), if isnan(v), t='Non défini : données constantes'; else, t=sprintf('%.8g',v); end, end
function v=fieldOr(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=char(string(s.(n))); else, v=d; end, end
function tf=askOverwrite(p), a=questdlg(sprintf('Le fichier existe :\n%s\nVoulez-vous le remplacer ?',p),'Confirmation','Oui','Non','Non'); tf=strcmp(a,'Oui'); end
function closeIfValid(f), if isgraphics(f), close(f); end, end
function rmdirIfExists(p), if exist(p,'dir'), rmdir(p,'s'); end, end
