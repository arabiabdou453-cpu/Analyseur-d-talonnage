function exporterExcel(chemin,T,analyse,metadata,options)
%EXPORTEREXCEL Produit le classeur vivant spécifié via Excel COM sous Windows.
% Le classeur contient une feuille, des formules de calcul et deux graphiques XY.
if nargin<5, options=parametresParDefaut(); end
if ~ispc, error('Etalonnage:ExcelIndisponible','Microsoft Excel est nécessaire pour cet export avancé. Les autres fonctions restent disponibles.'); end
if exist(chemin,'file') && ~askOverwrite(chemin), error('Etalonnage:ExportAnnule','Écrasement annulé.'); end
xl=[]; wb=[]; ws=[]; cleanup=onCleanup(@closeExcel);
try, xl=actxserver('Excel.Application'); catch e
    error('Etalonnage:ExcelIndisponible','Microsoft Excel est nécessaire pour cet export avancé. Détail COM : %s',e.message);
end
xl.Visible=false; xl.DisplayAlerts=false;
wb=xl.Workbooks.Add;
% Conserver une seule feuille.
while wb.Worksheets.Count>1, wb.Worksheets.Item(wb.Worksheets.Count).Delete; end
ws=wb.Worksheets.Item(1); ws.Name='Interpolation & Modelisation';
n=height(T); firstC=6; lastC=5+n; labelsC=lastC+2; coeffC=lastC+3;
% Bloc correction, lignes exactes du modèle.
ws.Range('B2:F3').Merge; ws.Range('B2').Value='INTERPOLATION (CORRECTION)';
ws.Range('B4').Value='Méthode : régression linéaire globale';
ws.Range('B5:G5').Value={'indication d''instrument','Correction','Correction Theorique','residu absolu','residuelle max','residu signé'};
ws.Range(sprintf('B%d:B%d',firstC,lastC)).Value=num2cell(T.Indication);
ws.Range(sprintf('C%d:C%d',firstC,lastC)).Value=num2cell(T.Correction);
for r=firstC:lastC
    ws.Range(sprintf('D%d',r)).Formula=sprintf('=B%d*$B$%d+$C$%d',r,coeffC,coeffC);
    ws.Range(sprintf('E%d',r)).Formula=sprintf('=ABS(C%d-D%d)',r,r);
    ws.Range(sprintf('G%d',r)).Formula=sprintf('=C%d-D%d',r,r);
end
ws.Range(sprintf('F%d',firstC)).Formula=sprintf('=MAX(E%d:E%d)',firstC,lastC);
ws.Range(sprintf('F%d:F%d',firstC,lastC)).Merge;
ws.Range(sprintf('B%d:C%d',labelsC,labelsC)).Value={'a','b'};
ws.Range(sprintf('B%d',coeffC)).Formula=sprintf('=SLOPE(C%d:C%d,B%d:B%d)',firstC,lastC,firstC,lastC);
ws.Range(sprintf('C%d',coeffC)).Formula=sprintf('=INTERCEPT(C%d:C%d,B%d:B%d)',firstC,lastC,firstC,lastC);
% Trois lignes entièrement vides après les coefficients du premier bloc.
titleU=coeffC+4; headU=titleU+3; firstU=headU+1; lastU=firstU+n-1; labelsU=lastU+2; coeffU=lastU+3;
ws.Range(sprintf('B%d:F%d',titleU,titleU+1)).Merge; ws.Range(sprintf('B%d',titleU)).Value='MODELISATION (INCERTITUDE)';
ws.Range(sprintf('B%d:G%d',headU,headU)).Value={'indication d''instrument','Incertitude','Incertitude Theorique','residu absolu','residuelle max','residu signé'};
ws.Range(sprintf('B%d:B%d',firstU,lastU)).Value=num2cell(T.Indication);
ws.Range(sprintf('C%d:C%d',firstU,lastU)).Value=num2cell(T.Incertitude);
for r=firstU:lastU
    ws.Range(sprintf('D%d',r)).Formula=sprintf('=B%d*$B$%d+$C$%d',r,coeffU,coeffU);
    ws.Range(sprintf('E%d',r)).Formula=sprintf('=ABS(C%d-D%d)',r,r);
    ws.Range(sprintf('G%d',r)).Formula=sprintf('=C%d-D%d',r,r);
end
ws.Range(sprintf('F%d',firstU)).Formula=sprintf('=MAX(E%d:E%d)',firstU,lastU);
ws.Range(sprintf('F%d:F%d',firstU,lastU)).Merge;
ws.Range(sprintf('B%d:C%d',labelsU,labelsU)).Value={'a','b'};
ws.Range(sprintf('B%d',coeffU)).Formula=sprintf('=SLOPE(C%d:C%d,B%d:B%d)',firstU,lastU,firstU,lastU);
ws.Range(sprintf('C%d',coeffU)).Formula=sprintf('=INTERCEPT(C%d:C%d,B%d:B%d)',firstU,lastU,firstU,lastU);
% Indicateurs et décisions; la variance nulle est traitée explicitement.
row=coeffU+2;
ws.Range(sprintf('B%d',row)).Value='R² correction';
ws.Range(sprintf('C%d',row)).Formula=sprintf('=IF(MAX(C%d:C%d)=MIN(C%d:C%d),"Non défini : données constantes",RSQ(C%d:C%d,B%d:B%d))',firstC,lastC,firstC,lastC,firstC,lastC,firstC,lastC);
ws.Range(sprintf('B%d',row+1)).Value='Écart-type résiduel correction';
ws.Range(sprintf('C%d',row+1)).Formula=sprintf('=STEYX(C%d:C%d,B%d:B%d)',firstC,lastC,firstC,lastC);
ws.Range(sprintf('B%d',row+2)).Value='R² incertitude';
ws.Range(sprintf('C%d',row+2)).Formula=sprintf('=IF(MAX(C%d:C%d)=MIN(C%d:C%d),"Non défini : données constantes",RSQ(C%d:C%d,B%d:B%d))',firstU,lastU,firstU,lastU,firstU,lastU,firstU,lastU);
ws.Range(sprintf('B%d',row+3)).Value='Écart-type résiduel incertitude';
ws.Range(sprintf('C%d',row+3)).Formula=sprintf('=STEYX(C%d:C%d,B%d:B%d)',firstU,lastU,firstU,lastU);
ws.Range(sprintf('B%d',row+4)).Value='b_majorant';
ws.Range(sprintf('C%d',row+4)).Formula=sprintf('=C%d+MAX(E%d:E%d)',coeffU,firstU,lastU);
if strcmp(options.modeSeuil,'fraction')
    ws.Range(sprintf('B%d',row+5)).Value='Seuil correction (fraction moyenne U)';
    ws.Range(sprintf('C%d',row+5)).Formula=sprintf('=%.15g*AVERAGE(C%d:C%d)',options.alphaCorrection,firstU,lastU);
    ws.Range(sprintf('B%d',row+6)).Value='Seuil incertitude (fraction moyenne U)';
    ws.Range(sprintf('C%d',row+6)).Formula=sprintf('=%.15g*AVERAGE(C%d:C%d)',options.alphaIncertitude,firstU,lastU);
else
    ws.Range(sprintf('B%d',row+5)).Value='Seuil correction (absolu)'; ws.Range(sprintf('C%d',row+5)).Value=options.seuilCorrection;
    ws.Range(sprintf('B%d',row+6)).Value='Seuil incertitude (absolu)'; ws.Range(sprintf('C%d',row+6)).Value=options.seuilIncertitude;
end
ws.Range(sprintf('B%d',row+7)).Value='Décision correction'; ws.Range(sprintf('C%d',row+7)).Formula=sprintf('=IF(F%d<=C%d,"Modèle acceptable selon le critère sur les résidus","Modèle non représentatif selon le critère sur les résidus")',firstC,row+5);
ws.Range(sprintf('B%d',row+8)).Value='Décision incertitude'; ws.Range(sprintf('C%d',row+8)).Formula=sprintf('=IF(F%d<=C%d,"Modèle acceptable selon le critère sur les résidus","Modèle non représentatif selon le critère sur les résidus")',firstU,row+6);
ws.Range(sprintf('B%d',row+10)).Value='Métadonnées';
metaRows={'Instrument',fieldOr(metadata,'instrument','');'Identifiant',fieldOr(metadata,'identifiant','');'Grandeur',fieldOr(metadata,'grandeur','');'Unité indication',fieldOr(metadata,'uniteIndication','');'Unité correction',fieldOr(metadata,'uniteCorrection','');'Unité incertitude',fieldOr(metadata,'uniteIncertitude','');'Certificat',fieldOr(metadata,'certificat','');'Date étalonnage',fieldOr(metadata,'dateEtalonnage','');'Nature incertitude',fieldOr(metadata,'natureIncertitude','inconnue');'Facteur k',fieldOr(metadata,'k','inconnu');'Conditions',fieldOr(metadata,'conditions','');'Procédure',fieldOr(metadata,'procedure','')};
ws.Range(sprintf('B%d:C%d',row+11,row+10+size(metaRows,1))).Value=metaRows;
ws.Range(sprintf('B%d',row+24)).Value='Modification des valeurs existantes : recalcul automatique. Ajout ou suppression de points : régénérer le classeur depuis l’application.';
ws.Range(sprintf('B%d',row+25)).Value='Les modifications dans Excel ne mettent pas automatiquement à jour la session MATLAB.';
ws.Range(sprintf('B%d',row+26)).Value='Le contrôle ne constitue pas à lui seul une validation métrologique complète.';
% Séries auxiliaires liées aux cellules pour dessiner la droite majorante.
for r=firstU:lastU
    ws.Range(sprintf('N%d',r)).Formula=sprintf('=B%d',r);
    ws.Range(sprintf('O%d',r)).Formula=sprintf('=N%d*$B$%d+$C$%d+MAX($E$%d:$E$%d)',r,coeffU,coeffU,firstU,lastU);
end
ws.Columns.Item('N:O').Hidden=true;
ws.Columns.Item('B:G').AutoFit;
ws.Range('B2:F3').Interior.Color=rgb(29,64,91); ws.Range('B2:F3').Font.Color=rgb(255,255,255); ws.Range('B2:F3').Font.Bold=true;
ws.Range('B5:G5').Font.Bold=true; ws.Range(sprintf('B%d:G%d',headU,headU)).Font.Bold=true;
ws.Range(sprintf('B%d:C%d',firstC,lastC)).Interior.Color=rgb(255,248,220);
ws.Range(sprintf('B%d:C%d',firstU,lastU)).Interior.Color=rgb(255,248,220);
ws.Range(sprintf('D%d:G%d',firstC,lastC)).Interior.Color=rgb(230,241,248);
ws.Range(sprintf('D%d:G%d',firstU,lastU)).Interior.Color=rgb(230,241,248);
% Graphiques XY natifs ancrés en H, avec tendance linéaire, équation et R².
addChart(ws,firstC,lastC,['Correction (' fieldOr(metadata,'uniteCorrection','') ')'],ws.Range('H2').Top,false,firstU,lastU,fieldOr(metadata,'uniteIndication',''));
addChart(ws,firstU,lastU,['Incertitude (' fieldOr(metadata,'uniteIncertitude','') ')'],ws.Range(sprintf('H%d',titleU)).Top,true,firstU,lastU,fieldOr(metadata,'uniteIndication',''));
xl.CalculateFullRebuild; wb.SaveAs(chemin,51); wb.Close(false); ws=[]; wb=[]; xl.Quit; xl=[]; clear cleanup
    function closeExcel()
        try, ws=[]; catch, end
        try, if ~isempty(wb), wb.Close(false); end, catch, end
        wb=[];
        try, if ~isempty(xl), xl.Quit; end, catch, end
        xl=[];
    end
end
function addChart(ws,first,last,name,top,withMajorant,firstU,lastU,xUnit)
chartObj=ws.ChartObjects.Add(ws.Range('H2').Left,top,480,260); chart=chartObj.Chart; chart.ChartType=-4169; chart.HasTitle=true; chart.ChartTitle.Text=name;
s=chart.SeriesCollection.NewSeries; s.Name=name; s.XValues=ws.Range(sprintf('B%d:B%d',first,last)); s.Values=ws.Range(sprintf('C%d:C%d',first,last)); s.ChartType=-4169;
trend=s.Trendlines.Add(4); trend.DisplayEquation=true; trend.DisplayRSquared=true;
if withMajorant
    sm=chart.SeriesCollection.NewSeries; sm.Name='Droite majorante'; sm.XValues=ws.Range(sprintf('N%d:N%d',firstU,lastU)); sm.Values=ws.Range(sprintf('O%d:O%d',firstU,lastU)); sm.ChartType=-4169; sm.MarkerStyle=-4142;
end
chart.Axes(1).HasTitle=true; chart.Axes(1).AxisTitle.Text=['Indication (' xUnit ')']; chart.Axes(2).HasTitle=true; chart.Axes(2).AxisTitle.Text=name;
end
function tf=askOverwrite(p)
a=questdlg(sprintf('Le fichier existe :\n%s\nVoulez-vous le remplacer ?',p),'Confirmation','Oui','Non','Non'); tf=strcmp(a,'Oui');
end
function v=fieldOr(s,n,d)
if isfield(s,n)&&~isempty(s.(n)), v=char(string(s.(n))); else, v=d; end
end
function c=rgb(r,g,b), c=r+256*g+65536*b; end
