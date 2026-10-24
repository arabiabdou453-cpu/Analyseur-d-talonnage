function fichiers = exporterFiguresPNG(dossier,T,analyse,metadata,options)
%EXPORTERFIGURESPNG Exporte les nuages et résidus en PNG haute résolution.
if nargin<5, options=parametresParDefaut(); end %#ok<NASGU>
if ~exist(dossier,'dir'), mkdir(dossier); end
noms={'Correction','Incertitude'}; fichiers=cell(2,1);
for k=1:2
    if k==1, m=analyse.correction; y=T.Correction; titre='INTERPOLATION (CORRECTION)'; unite=fieldOr(metadata,'uniteCorrection','');
    else, m=analyse.incertitude; y=T.Incertitude; titre='MODELISATION (INCERTITUDE)'; unite=fieldOr(metadata,'uniteIncertitude',''); end
    f=figure('Visible','off','Color','w','Name',titre); cleanup=onCleanup(@()closeIfValid(f));
    tiledlayout(f,2,1,'TileSpacing','compact');
    ax=nexttile; plot(ax,m.x,y,'ko','MarkerFaceColor',[0.1 0.35 0.55]); hold(ax,'on');
    xx=linspace(min(m.x),max(m.x),200)'; plot(ax,xx,m.a*xx+m.b,'-','Color',[0.1 0.45 0.75],'LineWidth',1.8);
    if k==2, plot(ax,xx,analyse.majorante.a*xx+analyse.majorante.b,'--','Color',[0.85 0.35 0.12],'LineWidth',1.8); legend(ax,{'Points certificat','Droite ajustée','Droite majorante'},'Location','best');
    else, legend(ax,{'Points certificat','Droite ajustée'},'Location','best'); end
    xlabel(ax,['Indication (' fieldOr(metadata,'uniteIndication','') ')']); ylabel(ax,['Valeur (' unite ')']); title(ax,{titre,'Méthode : régression linéaire globale'}); grid(ax,'on');
    ax2=nexttile; stem(ax2,m.x,m.residuSigne,'filled'); yline(ax2,0,'k-'); xlabel(ax2,'Indication'); ylabel(ax2,'Résidu signé'); title(ax2,'Résidus (mesuré − théorique)'); grid(ax2,'on');
    fichiers{k}=fullfile(dossier,[noms{k} '.png']);
    if exist(fichiers{k},'file')
        choix=questdlg(sprintf('Le fichier existe :\n%s\nVoulez-vous le remplacer ?',fichiers{k}),'Confirmation','Oui','Non','Non');
        if ~strcmp(choix,'Oui'), error('Etalonnage:ExportAnnule','Écrasement de figure annulé.'); end
    end
    exportgraphics(f,fichiers{k},'Resolution',180); clear cleanup
end
end
function v=fieldOr(s,n,d), if isfield(s,n)&&~isempty(s.(n)), v=s.(n); else, v=d; end, end
function closeIfValid(f), if isgraphics(f), close(f); end, end
