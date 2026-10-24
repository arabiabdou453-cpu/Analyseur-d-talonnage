classdef AnalyseurEtalonnageApp < handle
    %ANALYSEURETALONNAGEAPP Interface MATLAB autonome, compatible App Designer.
    properties
        UIFigure
        Tabs
        DataTab
        UseTab
        DataTable
        Meta
        Status
        AxC
        AxU
        ResidualTable
        ModelSummary
        InputI
        ResultLabel
        MethodDrop
        UncDrop
        CalcButton
        ExportButtons
        ConfirmCheck
        Analyse
        Options
        DonneesOriginales
        Donnees
        NormalisationJournal={}
        Confirme=false
        ConfirmeCorrection=false
        ConfirmeIncertitude=false
        State='Vide'
    end
    methods
        function app=AnalyseurEtalonnageApp()
            app.Options=parametresParDefaut();
            app.Donnees=table([],[],[],'VariableNames',{'Indication','Correction','Incertitude'});
            app.DonneesOriginales=app.Donnees;
            app.buildUI(); app.updateStatus('Vide — chargez ou saisissez des données.');
        end
        function delete(app)
            if ~isempty(app.UIFigure) && isgraphics(app.UIFigure), delete(app.UIFigure); end
        end
    end
    methods (Access=private)
        function buildUI(app)
            app.UIFigure=uifigure('Name','Analyse des données d’étalonnage','Position',[60 60 1320 850], ...
                'Color',[0.96 0.97 0.98]);
            root=uigridlayout(app.UIFigure,[1 1]); root.Padding=[12 12 12 12];
            app.Tabs=uitabgroup(root); app.DataTab=uitab(app.Tabs,'Title','Données et modèles'); app.UseTab=uitab(app.Tabs,'Title','Exploitation et exports');
            g=uigridlayout(app.DataTab,[4 1]); g.RowHeight={190,42,'1x',46}; g.Padding=[10 10 10 10];
            metaPanel=uipanel(g,'Title','Instrument et certificat'); mg=uigridlayout(metaPanel,[3 6]); mg.RowHeight={32,32,32};
            labels={'Instrument','Identifiant','Grandeur','Unité indication','Unité correction','Unité incertitude','Certificat','Date étalonnage','Nature incertitude','Facteur k','Conditions','Procédure'};
            keys={'instrument','identifiant','grandeur','uniteIndication','uniteCorrection','uniteIncertitude','certificat','dateEtalonnage','natureIncertitude','k','conditions','procedure'};
            app.Meta=struct();
            for q=1:12
                col=mod(q-1,6)+1; row=floor((q-1)/6)+1;
                if row>3, row=3; col=mod(q-1,6)+1; end
                box=uigridlayout(mg,[1 2]); box.Layout.Row=row; box.Layout.Column=col; box.ColumnWidth={90,'1x'}; box.Padding=[0 0 0 0];
                uilabel(box,'Text',labels{q},'FontSize',10);
                if strcmp(keys{q},'natureIncertitude')
                    app.Meta.(keys{q})=uidropdown(box,'Items',{'Inconnue','Élargie U','Type u'},'Value','Inconnue','ValueChangedFcn',@(~,~)app.invalidate('Métadonnées modifiées : relancez l’analyse.'));
                else
                    app.Meta.(keys{q})=uieditfield(box,'text','Placeholder',labels{q},'ValueChangedFcn',@(~,~)app.invalidate('Métadonnées modifiées : relancez l’analyse.'));
                end
            end
            actions=uigridlayout(g,[1 8]); actions.ColumnWidth=repmat({'1x'},1,8);
            uibutton(actions,'Text','Nouveau','ButtonPushedFcn',@(~,~)app.newData());
            uibutton(actions,'Text','Importer Excel/CSV','ButtonPushedFcn',@(~,~)app.importData());
            uibutton(actions,'Text','Importer certificat PDF','ButtonPushedFcn',@(~,~)app.importPDF());
            uibutton(actions,'Text','Charger l’exemple','ButtonPushedFcn',@(~,~)app.loadExample());
            uibutton(actions,'Text','Ajouter une ligne','ButtonPushedFcn',@(~,~)app.addRow());
            uibutton(actions,'Text','Supprimer la ligne','ButtonPushedFcn',@(~,~)app.removeRow());
            uibutton(actions,'Text','Vérifier les données','ButtonPushedFcn',@(~,~)app.validateData());
            uibutton(actions,'Text','Analyser','FontWeight','bold','ButtonPushedFcn',@(~,~)app.analyseData());
            body=uigridlayout(g,[1 2]); body.ColumnWidth={'0.92x','1.08x'};
            left=uigridlayout(body,[3 1]); left.RowHeight={'1x',130,34};
            app.DataTable=uitable(left,'ColumnName',{'Indication','Correction','Incertitude'},'ColumnEditable',[true true true], ...
                'ColumnFormat',{'numeric','numeric','numeric'},'CellEditCallback',@(~,~)app.invalidate('Les données ont changé : relancez l’analyse.'));
            p=uipanel(left,'Title','Paramètres de décision'); pg=uigridlayout(p,[3 4]); pg.RowHeight={30,30,30};
            uilabel(pg,'Text','Mode des seuils'); mode=uidropdown(pg,'Items',{'Fraction de la moyenne','Seuil absolu'},'Value','Fraction de la moyenne','ValueChangedFcn',@(~,e)app.changeMode(e));
            uilabel(pg,'Text','Fraction correction'); aC=uieditfield(pg,'numeric','Value',.25,'Limits',[0 Inf],'ValueChangedFcn',@(~,~)app.setFractions());
            uilabel(pg,'Text','Fraction incertitude'); aU=uieditfield(pg,'numeric','Value',.25,'Limits',[0 Inf],'ValueChangedFcn',@(~,~)app.setFractions());
            uilabel(pg,'Text','Seuil correction'); sC=uieditfield(pg,'numeric','Value',0,'ValueChangedFcn',@(~,~)app.setAbsolute());
            uilabel(pg,'Text','Seuil incertitude'); sU=uieditfield(pg,'numeric','Value',0,'ValueChangedFcn',@(~,~)app.setAbsolute());
            uilabel(pg,'Text','Procédure de validation confirmée'); proc= uicheckbox(pg,'Text','Oui','Value',false,'ValueChangedFcn',@(~,e)app.setProcedure(e));
            app.Meta.alphaCorrection=aC; app.Meta.alphaIncertitude=aU; app.Meta.seuilCorrection=sC; app.Meta.seuilIncertitude=sU; app.Meta.modeSeuil=mode; app.Meta.procedureConfirmee=proc;
            app.Status=uilabel(left,'Text','État : Vide','FontColor',[.2 .3 .4]);
            right=uigridlayout(body,[3 1]); right.RowHeight={115,'1x','1x'};
            app.ModelSummary=uilabel(right,'Text','Les coefficients et résidus apparaîtront après analyse.','WordWrap','on');
            axpanel=uigridlayout(right,[1 2]); app.AxC=uiaxes(axpanel); app.AxU=uiaxes(axpanel);
            app.ResidualTable=uitable(right,'ColumnName',{'Indication','Correction mesurée','Ajustée C','Résidu signé C','Incertitude mesurée','Ajustée U','Résidu signé U'});
            footer=uigridlayout(g,[1 2]); footer.ColumnWidth={'1x','1x'};
            uilabel(footer,'Text','Les seuils sont des réglages de prototype, pas des règles normatives.');
            uibutton(footer,'Text','Confirmer les modèles pour exploitation','ButtonPushedFcn',@(~,~)app.confirmModels());
            app.buildUseTab();
            app.DataTable.Data=zeros(0,3);
        end
        function buildUseTab(app)
            g=uigridlayout(app.UseTab,[5 1]); g.RowHeight={60,90,55,'1x',60}; g.Padding=[20 20 20 20];
            uilabel(g,'Text','Calculateur métrologique','FontSize',22,'FontWeight','bold');
            row=uigridlayout(g,[1 6]); row.ColumnWidth={180,'1x',170,'1x',150,120};
            uilabel(row,'Text','Indication à traiter'); app.InputI=uieditfield(row,'numeric','Value',0);
            uilabel(row,'Text','Correction active'); app.MethodDrop=uidropdown(row,'Items',{'Régression linéaire globale','Interpolation point par point'},'Value','Régression linéaire globale');
            uilabel(row,'Text','Incertitude active'); app.UncDrop=uidropdown(row,'Items',{'Droite majorante','Droite ajustée'},'Value','Droite majorante');
            app.CalcButton=uibutton(g,'Text','Calculer','FontWeight','bold','Enable','off','ButtonPushedFcn',@(~,~)app.calculate());
            app.ResultLabel=uilabel(g,'Text','Aucun calcul. Confirmez d’abord les modèles.','WordWrap','on','FontSize',14);
            exports=uigridlayout(g,[1 5]);
            b1=uibutton(exports,'Text','Excel avancé','Enable','off','ButtonPushedFcn',@(~,~)app.exportExcel());
            b2=uibutton(exports,'Text','Rapport PDF','Enable','off','ButtonPushedFcn',@(~,~)app.exportPDF());
            b3=uibutton(exports,'Text','Figures PNG','Enable','off','ButtonPushedFcn',@(~,~)app.exportPNG());
            app.ExportButtons=[b1 b2 b3];
            uibutton(exports,'Text','Sauver session','ButtonPushedFcn',@(~,~)app.saveSession());
            uibutton(exports,'Text','Ouvrir session','ButtonPushedFcn',@(~,~)app.openSession());
        end
        function meta=readMetadata(app)
            k=fieldnames(app.Meta); meta=struct();
            for i=1:numel(k), h=app.Meta.(k{i}); if isprop(h,'Value'), meta.(k{i})=h.Value; end, end
            if isfield(meta,'natureIncertitude'), meta.natureIncertitude=char(meta.natureIncertitude); end
        end
        function collectTable(app)
            d=app.DataTable.Data;
            if isempty(d), app.Donnees=table([],[],[],'VariableNames',{'Indication','Correction','Incertitude'}); return; end
            if iscell(d), d=cell2mat(d); end
            if size(d,2)~=3, error('Etalonnage:Colonnes','Le tableau doit contenir trois colonnes.'); end
            app.Donnees=table(d(:,1),d(:,2),d(:,3),'VariableNames',{'Indication','Correction','Incertitude'});
        end
        function updateStatus(app,msg)
            app.Status.Text=['État : ' app.State ' — ' msg];
        end
        function invalidate(app,msg)
            app.Confirme=false; app.ConfirmeCorrection=false; app.ConfirmeIncertitude=false; app.Analyse=[]; app.State='Données chargées';
            if ~isempty(app.CalcButton) && isgraphics(app.CalcButton), app.CalcButton.Enable='off'; end
            if ~isempty(app.ExportButtons) && all(isgraphics(app.ExportButtons)), set(app.ExportButtons,'Enable','off'); end
            app.ResultLabel.Text=msg; app.updateStatus(msg);
        end
        function newData(app)
            app.Donnees=table([],[],[],'VariableNames',{'Indication','Correction','Incertitude'}); app.DonneesOriginales=app.Donnees; app.DataTable.Data=zeros(0,3); app.NormalisationJournal={};
            keys={'instrument','identifiant','grandeur','uniteIndication','uniteCorrection','uniteIncertitude','certificat','dateEtalonnage','k','conditions','procedure'};
            for q=1:numel(keys), app.Meta.(keys{q}).Value=''; end
            app.Meta.natureIncertitude.Value='Inconnue'; app.Options=parametresParDefaut();
            app.Meta.alphaCorrection.Value=.25; app.Meta.alphaIncertitude.Value=.25;
            app.Meta.seuilCorrection.Value=0; app.Meta.seuilIncertitude.Value=0;
            app.Meta.modeSeuil.Value='Fraction de la moyenne'; app.Meta.procedureConfirmee.Value=false;
            app.invalidate('Nouveau jeu de données.');
        end
        function addRow(app)
            d=app.DataTable.Data; if isempty(d), d=zeros(0,3); end; if iscell(d), d=cell2mat(d); end
            d(end+1,:)=[NaN NaN NaN]; app.DataTable.Data=d; app.invalidate('Ligne ajoutée. Renseignez les trois valeurs.');
        end
        function removeRow(app)
            d=app.DataTable.Data; if isempty(d), return; end
            [idx,ok]=listdlg('PromptString','Sélectionnez la ligne à supprimer','SelectionMode','single','ListString',cellstr(string((1:size(d,1))')));
            if ok, d(idx,:)=[]; app.DataTable.Data=d; app.invalidate('Ligne supprimée explicitement.'); end
        end
        function loadExample(app)
            app.Donnees=table([0;10;20;30],[.1;.2;.3;.4],[.2;.22;.24;.26], ...
                'VariableNames',{'Indication','Correction','Incertitude'});
            app.DataTable.Data=[app.Donnees.Indication app.Donnees.Correction app.Donnees.Incertitude];
            app.invalidate('Exemple chargé. Vérifiez puis analysez.');
        end
        function importData(app)
            [f,p]=uigetfile({'*.csv;*.xlsx;*.xls','CSV ou Excel'},'Importer des points'); if isequal(f,0), return; end
            try
                [t,info]=importerPoints(fullfile(p,f)); app.DonneesOriginales=info.donneesBrutes; app.Donnees=t; app.NormalisationJournal=info.journal;
                app.DataTable.Data=[t.Indication t.Correction t.Incertitude]; app.invalidate('Import affiché. Vérifiez avant analyse.');
            catch e, uialert(app.UIFigure,e.message,'Erreur d’import'); end
        end
        function importPDF(app)
            [f,p]=uigetfile({'*.pdf','Certificat PDF (*.pdf)'},'Importer un certificat PDF'); if isequal(f,0), return; end
            d=uiprogressdlg(app.UIFigure,'Title','Import PDF','Message','Lecture du certificat…','Indeterminate','on');
            try
                [series,info]=importerCertificatPDF(fullfile(p,f)); close(d);
            catch e
                close(d); uialert(app.UIFigure,e.message,'Import PDF impossible'); return;
            end
            idx=1;
            if numel(series)>1
                noms=arrayfun(@(s)sprintf('%s — %d points',s.titre,height(s.donnees)),series,'UniformOutput',false);
                [idx,ok]=listdlg('PromptString','Plusieurs tableaux détectés. Choisissez la série à analyser :', ...
                    'SelectionMode','single','ListString',noms,'ListSize',[420 140]);
                if ~ok, return; end
            end
            s=series(idx); b=s.brut;
            % Aperçu avant chargement : le contenu importé est affiché avant validation (F3).
            apercu=arrayfun(@(i)sprintf('%d)  réf. %.6g | équip. %.6g | erreur %.6g  →  C = %.6g ; U = %.6g', ...
                i,b.Reference(i),b.Equipement(i),b.Erreur(i),s.donnees.Correction(i),b.Incertitude(i)),(1:height(b))','UniformOutput',false);
            msg=[{sprintf('%s (%s) — %s',s.titre,s.unite,f)} {''} apercu' {''} ...
                {'Convention : Correction = −Erreur (référence − indication).'}];
            if ~isempty(s.incoherences)
                msg=[msg {sprintf('Attention : erreur imprimée incohérente aux points %s.',mat2str(s.incoherences))}];
            end
            msg=[msg {'Comparez chaque valeur au certificat original avant l’analyse.'}];
            choix=uiconfirm(app.UIFigure,strjoin(msg,newline),'Vérifier l’import PDF', ...
                'Options',{'Charger dans le tableau','Annuler'},'DefaultOption',1,'CancelOption',2);
            if ~strcmp(choix,'Charger dans le tableau'), return; end
            app.DonneesOriginales=b; app.Donnees=s.donnees; app.NormalisationJournal=info.journal;
            app.DataTable.Data=[s.donnees.Indication s.donnees.Correction s.donnees.Incertitude];
            m=info.meta;
            champs={'instrument','identifiant','certificat','dateEtalonnage','conditions'};
            for q=1:numel(champs), if ~isempty(m.(champs{q})), app.Meta.(champs{q}).Value=m.(champs{q}); end, end
            if ~isempty(s.grandeur), app.Meta.grandeur.Value=s.grandeur; end
            if ~isempty(s.unite)
                app.Meta.uniteIndication.Value=s.unite; app.Meta.uniteCorrection.Value=s.unite; app.Meta.uniteIncertitude.Value=s.unite;
            end
            if ~isempty(m.natureIncertitude), app.Meta.natureIncertitude.Value=m.natureIncertitude; end
            % k seulement s'il est imprimé sur chaque ligne de la série; jamais supposé.
            if isfinite(s.k), app.Meta.k.Value=sprintf('%g',s.k); else, app.Meta.k.Value=''; end
            app.invalidate('Import PDF affiché. Comparez chaque valeur au certificat avant analyse.');
        end
        function validateData(app)
            try, app.collectTable(); [~,j]=normaliserDonnees(app.Donnees); app.NormalisationJournal=[app.NormalisationJournal j]; r=validerDonnees(app.Donnees,app.readMetadata(),app.Options);
                if r.valide, app.State='Données valides'; msg=strjoin([j r.avertissements],newline); else, msg=strjoin(r.erreurs,newline); end
                app.updateStatus(msg); uialert(app.UIFigure,msg,'Vérification');
            catch e, uialert(app.UIFigure,e.message,'Données invalides'); end
        end
        function changeMode(app,e)
            if strcmp(e.Value,'Fraction de la moyenne')
                app.Options.modeSeuil='fraction';
            else
                app.Options.modeSeuil='absolu';
                app.Options.seuilCorrection=app.Meta.seuilCorrection.Value;
                app.Options.seuilIncertitude=app.Meta.seuilIncertitude.Value;
            end
            app.invalidate('Mode de seuil modifié : relancez l’analyse.');
        end
        function setFractions(app)
            app.Options.alphaCorrection=app.Meta.alphaCorrection.Value; app.Options.alphaIncertitude=app.Meta.alphaIncertitude.Value; app.invalidate('Seuils modifiés.');
        end
        function setAbsolute(app)
            app.Options.seuilCorrection=app.Meta.seuilCorrection.Value; app.Options.seuilIncertitude=app.Meta.seuilIncertitude.Value; app.invalidate('Seuils modifiés.');
        end
        function setProcedure(app,e), app.Options.procedureConfirmee=e.Value; app.invalidate('Confirmation de procédure modifiée.'); end
        function analyseData(app)
            try
                app.collectTable(); [donneesNormalisees,j]=normaliserDonnees(app.Donnees); app.Donnees=donneesNormalisees; app.NormalisationJournal=[app.NormalisationJournal j];
                r=validerDonnees(app.Donnees,app.readMetadata(),app.Options);
                if ~r.valide, error('Etalonnage:Validation','%s',strjoin(r.erreurs,newline)); end
                if r.trieRecommande
                    choix=uiconfirm(app.UIFigure,'Les points ne sont pas triés. Trier ensemble les lignes selon l’indication ?','Tri explicite','Options',{'Trier','Annuler'},'DefaultOption',2);
                    if strcmp(choix,'Trier'), app.Donnees=sortrows(app.Donnees,'Indication'); app.DataTable.Data=[app.Donnees.Indication app.Donnees.Correction app.Donnees.Incertitude]; else, return; end
                end
                app.Analyse=analyserEtalonnage(app.Donnees,app.readMetadata(),app.Options); app.Confirme=false; app.ConfirmeCorrection=false; app.ConfirmeIncertitude=false; app.State='Analysé';
                if ~isempty(app.ExportButtons) && all(isgraphics(app.ExportButtons)), set(app.ExportButtons,'Enable','on'); end
                app.plotResults(); app.updateStatus([app.Analyse.decisionCorrection.message ' / ' app.Analyse.decisionIncertitude.message]);
                app.Tabs.SelectedTab=app.DataTab;
            catch e, uialert(app.UIFigure,e.message,'Analyse impossible'); end
        end
        function plotResults(app)
            a=app.Analyse; t=app.Donnees;
            md=app.readMetadata(); xx=linspace(a.etendue(1),a.etendue(2),100);
            plot(app.AxC,t.Indication,t.Correction,'ko','MarkerFaceColor',[.16 .42 .58]); hold(app.AxC,'on'); plot(app.AxC,xx,a.correction.a*xx+a.correction.b,'-','LineWidth',1.5); hold(app.AxC,'off'); grid(app.AxC,'on'); title(app.AxC,sprintf('INTERPOLATION (CORRECTION) — Méthode : régression linéaire globale\ny = %.6g x %+.6g ; R² = %s',a.correction.a,a.correction.b,r2Text(a.correction.R2))); xlabel(app.AxC,['Indication (' char(string(md.uniteIndication)) ')']); ylabel(app.AxC,['Correction (' char(string(md.uniteCorrection)) ')']); legend(app.AxC,{'Points certificat','Régression linéaire'},'Location','best');
            plot(app.AxU,t.Indication,t.Incertitude,'ko','MarkerFaceColor',[.16 .42 .58]); hold(app.AxU,'on'); plot(app.AxU,xx,a.incertitude.a*xx+a.incertitude.b,'-','LineWidth',1.5); plot(app.AxU,xx,a.majorante.a*xx+a.majorante.b,'--','LineWidth',1.5); hold(app.AxU,'off'); grid(app.AxU,'on'); title(app.AxU,sprintf('MODELISATION (INCERTITUDE) — %s\ny = %.6g x %+.6g ; R² = %s',char(md.natureIncertitude),a.incertitude.a,a.incertitude.b,r2Text(a.incertitude.R2))); xlabel(app.AxU,['Indication (' char(string(md.uniteIndication)) ')']); ylabel(app.AxU,['Incertitude (' char(string(md.uniteIncertitude)) ')']); legend(app.AxU,{'Points','Ajustée','Majorante'},'Location','best');
            app.ModelSummary.Text=sprintf(['Correction : a=%.12g ; b=%.12g ; e_max=%.8g ; R²=%s ; s_res=%.8g\nDécision : %s — %s\n' ...
                'Incertitude : a=%.12g ; b=%.12g ; b_majorant=%.12g ; e_max=%.8g ; R²=%s ; s_res=%.8g\nDécision : %s — %s\n' ...
                's_res est un indicateur d’ajustement, pas automatiquement une incertitude élargie.'], ...
                a.correction.a,a.correction.b,a.correction.residuMax,r2Text(a.correction.R2),a.correction.sRes,a.decisionCorrection.message,a.decisionCorrection.remarqueR2, ...
                a.incertitude.a,a.incertitude.b,a.majorante.b,a.incertitude.residuMax,r2Text(a.incertitude.R2),a.incertitude.sRes,a.decisionIncertitude.message,a.decisionIncertitude.remarqueR2);
            app.ResidualTable.Data=[t.Indication a.correction.mesure a.correction.ajuste a.correction.residuSigne t.Incertitude a.incertitude.ajuste a.incertitude.residuSigne];
        end
        function confirmModels(app)
            if isempty(app.Analyse), uialert(app.UIFigure,'Analysez d’abord des données valides.','Modèles absents'); return; end
            if ~app.Options.procedureConfirmee, uialert(app.UIFigure,'Confirmez la procédure de validation utilisée avant exploitation.','Confirmation requise'); return; end
            app.ConfirmeCorrection=app.Analyse.decisionCorrection.acceptable;
            if ~app.ConfirmeCorrection
                choix=uiconfirm(app.UIFigure,'Le critère sur les résidus de correction n’est pas satisfait. Confirmer malgré tout selon une procédure explicitement documentée ?','Confirmation du modèle de correction','Options',{'Confirmer explicitement','Refuser'},'DefaultOption',2);
                app.ConfirmeCorrection=strcmp(choix,'Confirmer explicitement');
            end
            app.ConfirmeIncertitude=app.Analyse.decisionIncertitude.acceptable;
            if ~app.Analyse.majorante.utilisable
                app.ConfirmeIncertitude=false;
                uialert(app.UIFigure,'La droite majorante est négative à une borne de l’étendue; son utilisation est bloquée.','Modèle d’incertitude non exploitable');
            elseif ~app.ConfirmeIncertitude
                choix=uiconfirm(app.UIFigure,'Le critère sur les résidus d’incertitude n’est pas satisfait. Confirmer malgré tout selon une procédure explicitement documentée ?','Confirmation du modèle d’incertitude','Options',{'Confirmer explicitement','Refuser'},'DefaultOption',2);
                app.ConfirmeIncertitude=strcmp(choix,'Confirmer explicitement');
            end
            app.Confirme=app.ConfirmeCorrection && app.ConfirmeIncertitude;
            if app.Confirme
                app.State='Confirmé'; app.CalcButton.Enable='on';
                app.updateStatus('Correction et incertitude confirmées indépendamment.');
            else
                app.State='Analysé'; app.CalcButton.Enable='off';
                if app.ConfirmeCorrection, txtC='oui'; else, txtC='non'; end
                if app.ConfirmeIncertitude, txtU='oui'; else, txtU='non'; end
                app.updateStatus(sprintf('Correction confirmée : %s ; incertitude confirmée : %s. Le calculateur exige les deux modèles.',txtC,txtU));
            end
        end
        function calculate(app)
            try
                if isempty(app.Analyse) || ~app.Confirme, error('Etalonnage:ModelesNonConfirmes','Les modèles ne sont pas analysés et confirmés.'); end
                method='regression'; if strcmp(app.MethodDrop.Value,'Interpolation point par point'), method='interpolation'; end
                um='majorante'; if strcmp(app.UncDrop.Value,'Droite ajustée'), um='ajustee'; end
                m=struct('confirme',true,'correction',method,'incertitude',um);
                r=calculerResultat(app.InputI.Value,app.Analyse,app.Options,m);
                app.ResultLabel.Text=sprintf(['Correction estimée : %.12g\nValeur corrigée I+C(I) : %.12g\nIncertitude estimée : %.12g (%s)\n' ...
                    'Méthode correction : %s\nMéthode incertitude : %s\nÉtendue autorisée : [%.8g ; %.8g]\nCertificat : %s — nature : %s — k : %s\n%s'], ...
                    r.correction,r.valeurCorrigee,r.incertitude,app.Meta.uniteIncertitude.Value,r.methodeCorrection,r.methodeIncertitude,r.etendue(1),r.etendue(2),app.Meta.certificat.Value,app.Meta.natureIncertitude.Value,app.Meta.k.Value,r.statut);
            catch e, uialert(app.UIFigure,e.message,'Calcul refusé'); end
        end
        function exportExcel(app)
            if isempty(app.Analyse), uialert(app.UIFigure,'Analysez les données avant export.','Export indisponible'); return; end
            [f,p]=uiputfile('*.xlsx','Exporter le classeur Excel'); if isequal(f,0), return; end
            try, exporterExcel(fullfile(p,f),app.Donnees,app.Analyse,app.readMetadata(),app.Options); catch e, uialert(app.UIFigure,e.message,'Export Excel'); end
        end
        function exportPDF(app)
            if isempty(app.Analyse), uialert(app.UIFigure,'Analysez les données avant export.','Export indisponible'); return; end
            [f,p]=uiputfile('*.pdf','Exporter le rapport d’analyse'); if isequal(f,0), return; end
            try, exporterRapportPDF(fullfile(p,f),app.Donnees,app.Analyse,app.readMetadata(),app.Options); catch e, uialert(app.UIFigure,e.message,'Export PDF'); end
        end
        function exportPNG(app)
            if isempty(app.Analyse), uialert(app.UIFigure,'Analysez les données avant export.','Export indisponible'); return; end
            p=uigetdir(pwd,'Choisir le dossier de figures'); if isequal(p,0), return; end
            try, files=exporterFiguresPNG(p,app.Donnees,app.Analyse,app.readMetadata(),app.Options); uialert(app.UIFigure,strjoin(files,newline),'Figures créées'); catch e, uialert(app.UIFigure,e.message,'Export PNG'); end
        end
        function saveSession(app)
            [f,p]=uiputfile('*.mat','Sauvegarder la session'); if isequal(f,0), return; end
            try
                app.collectTable(); s=struct('donneesOriginales',app.DonneesOriginales,'donnees',app.Donnees,'normalisationJournal',app.NormalisationJournal,'metadata',app.readMetadata(),'options',app.Options,'methodes',struct('correction',app.MethodDrop.Value,'incertitude',app.UncDrop.Value),'statut',app.State,'modelesConfirmes',app.Confirme,'correctionConfirmee',app.ConfirmeCorrection,'incertitudeConfirmee',app.ConfirmeIncertitude);
                sauvegarderSession(fullfile(p,f),s);
            catch e, uialert(app.UIFigure,e.message,'Sauvegarde impossible'); end
        end
        function openSession(app)
            [f,p]=uigetfile('*.mat','Ouvrir une session'); if isequal(f,0), return; end
            try
                s=chargerSession(fullfile(p,f)); app.Donnees=s.donnees; app.DonneesOriginales=s.donneesOriginales;
                if isfield(s,'normalisationJournal'), app.NormalisationJournal=s.normalisationJournal; else, app.NormalisationJournal={}; end
                metaKeys={'instrument','identifiant','grandeur','uniteIndication','uniteCorrection','uniteIncertitude','certificat','dateEtalonnage','natureIncertitude','k','conditions','procedure'};
                for q=1:numel(metaKeys)
                    key=metaKeys{q};
                    if isfield(s.metadata,key) && isfield(app.Meta,key)
                        if strcmp(key,'natureIncertitude')
                            app.Meta.(key).Value=char(s.metadata.(key));
                        else
                            app.Meta.(key).Value=char(string(s.metadata.(key)));
                        end
                    end
                end
                app.Options=s.options; app.DataTable.Data=[s.donnees.Indication s.donnees.Correction s.donnees.Incertitude];
                app.Meta.alphaCorrection.Value=s.options.alphaCorrection; app.Meta.alphaIncertitude.Value=s.options.alphaIncertitude;
                if strcmp(s.options.modeSeuil,'fraction')
                    app.Meta.modeSeuil.Value='Fraction de la moyenne';
                else
                    app.Meta.modeSeuil.Value='Seuil absolu';
                    app.Meta.seuilCorrection.Value=s.options.seuilCorrection; app.Meta.seuilIncertitude.Value=s.options.seuilIncertitude;
                end
                app.Meta.procedureConfirmee.Value=s.options.procedureConfirmee;
                if isfield(s,'methodes')
                    app.MethodDrop.Value=s.methodes.correction;
                    app.UncDrop.Value=s.methodes.incertitude;
                end
                app.Confirme=false; app.ConfirmeCorrection=false; app.ConfirmeIncertitude=false; app.Analyse=[]; app.State='Données chargées'; app.invalidate('Session restaurée; relancez validation, analyse et confirmation.');
            catch e, uialert(app.UIFigure,e.message,'Session incompatible'); end
        end
    end
end
