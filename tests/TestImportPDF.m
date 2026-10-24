classdef TestImportPDF < matlab.unittest.TestCase
    %TESTIMPORTPDF Extension import PDF : lecture du texte et repérage des tableaux.
    % Les lignes de référence reproduisent le texte reconstruit du certificat
    % anonymisé au format ISQ (enregistreur température / humidité).
    methods (Test)
        function tableauxCertificatISQ(testCase)
            [s,m]=analyserTexteCertificat(lignesISQ());
            testCase.verifyNumElements(s,2);
            testCase.verifyEqual(s(1).grandeur,'Température'); testCase.verifyEqual(s(1).unite,'°C');
            testCase.verifyEqual(s(1).donnees.Indication,[0;24.9;59.8],'AbsTol',1e-12);
            testCase.verifyEqual(s(1).donnees.Correction,[-0.08;0.12;0.26],'AbsTol',1e-12);
            testCase.verifyEqual(s(1).donnees.Incertitude,[0.27;0.42;0.63],'AbsTol',1e-12);
            testCase.verifyEqual(s(1).brut.Reference,[-0.08;25.02;60.043],'AbsTol',1e-12);
            testCase.verifyEqual(s(1).k,2);
            testCase.verifyEmpty(s(1).incoherences);
            testCase.verifyEqual(s(2).unite,'%hr');
            testCase.verifyEqual(s(2).donnees.Indication,[13.6;51.99;80.5],'AbsTol',1e-12);
            testCase.verifyEqual(s(2).donnees.Correction,[-1.84;-1.64;-0.65],'AbsTol',1e-12);
            testCase.verifyEqual(s(2).donnees.Incertitude,[1.7;1.8;2.4],'AbsTol',1e-12);
            testCase.verifyEqual(m.certificat,'00/XX/TEST0001');
            testCase.verifyEqual(m.identifiant,'ID-0001');
            testCase.verifyEqual(m.dateEtalonnage,'2026-07-15');
            testCase.verifyEqual(m.natureIncertitude,'Élargie U');
            testCase.verifySubstring(m.instrument,'Enregistreur');
        end
        function nombresHorsTableauIgnores(testCase)
            L={'Condition ambiante:  Température:  23,4 ºC  Humidité relative:  37,7 %hr'; ...
               'Résolution Temp.:  0,1°C'; 'Intervalle d''indication:  -20 à +70 °C'};
            s=analyserTexteCertificat(L);
            testCase.verifyEmpty(s);
        end
        function ordreEquipementPuisReference(testCase)
            s=analyserTexteCertificat({'Pression (bar)';'24,9  25,020  -0,12  ± 0,42'});
            testCase.verifyEqual(s.brut.Reference,25.02,'AbsTol',1e-12);
            testCase.verifyEqual(s.donnees.Indication,24.9,'AbsTol',1e-12);
            testCase.verifyEqual(s.donnees.Correction,0.12,'AbsTol',1e-12);
        end
        function incoherenceSignaleeSansCorrection(testCase)
            s=analyserTexteCertificat({'Température (°C)';'10,00  10,50  0,90  ± 0,3  2,00'});
            testCase.verifyEqual(s.incoherences,1);
            testCase.verifyEqual(s.donnees.Correction,-0.9,'AbsTol',1e-12); % valeur imprimée conservée
        end
        function kNonSuppose(testCase)
            [s,m]=analyserTexteCertificat({'Masse (g)';'1,000  1,002  0,002  ± 0,001';'2,000  2,003  0,003  ± 0,001'});
            testCase.verifyTrue(isnan(s.k));
            testCase.verifyEqual(m.natureIncertitude,'');
        end
        function signeMoinsUnicode(testCase)
            s=analyserTexteCertificat({'Tension (V)';['0,500  0,480  ' char(8722) '0,020  ' char(177) ' 0,01']});
            testCase.verifyEqual(s.donnees.Correction,0.02,'AbsTol',1e-12);
        end
        function lecturePDFNonCompresse(testCase)
            p=ecrirePDF(testCase,contenuTest(),false);
            L=extraireTextePDF(p);
            testCase.verifyEqual(L{1},'Température (ºC)');
            testCase.verifyEqual(L{2},['-0,080  0,0  0,08  ' char(177) ' 0,27  2,00']);
            [s,info]=importerCertificatPDF(p);
            testCase.verifyEqual(s.donnees.Correction,[-0.08;0.12],'AbsTol',1e-12);
            testCase.verifyEqual(info.methode,'lecteur interne');
        end
        function lecturePDFCompresse(testCase)
            p=ecrirePDF(testCase,contenuTest(),true);
            s=importerCertificatPDF(p);
            testCase.verifyEqual(s.donnees.Indication,[0;24.9],'AbsTol',1e-12);
        end
        function fichierNonPDF(testCase)
            p=[tempname '.pdf']; fid=fopen(p,'w'); fprintf(fid,'pas un pdf'); fclose(fid);
            testCase.addTeardown(@()delete(p));
            testCase.verifyError(@()importerCertificatPDF(p),'Etalonnage:PDFInvalide');
        end
        function pdfSansTableau(testCase)
            c='BT /F1 10 Tf 1 0 0 1 50 700 Tm (Rapport sans resultats) Tj ET';
            p=ecrirePDF(testCase,c,false);
            testCase.verifyError(@()importerCertificatPDF(p),'Etalonnage:PDFSansTableau');
        end
    end
end

function L = lignesISQ()
pm=char(177);
L={'Certificat nº  00/XX/TEST0001  Page  2  de 2'
   'Température (ºC)'
   'Valeur de   Valeur de   d''élargi.'
   'Erreur  Incertitde élargie'
   ['-0,080  0,0  0,08  ' pm ' 0,27  2,00']
   ['25,020  24,9  -0,12  ' pm ' 0,42  2,00']
   ['60,043  59,8  -0,26  ' pm ' 0,63  2,00']
   'Humidité (%hr), à 23°C'
   ['11,76  13,60  1,84  ' pm ' 1,7  2,00']
   ['50,34  51,99  1,64  ' pm ' 1,8  2,00']
   ['79,85  80,50  0,65  ' pm ' 2,4  2,00']
   'Instrument étalonné :  Enregistreur de température et humidité'
   'Constructeur:  TESTO'
   'Type:  174 H'
   'Nº ident.:  ID-0001'
   'Date d''étalonnage:  2026-07-15'
   'Condition ambiante:  Température:  23,4 ºC  Humidité relative:  37,7 %hr'};
end

function c = contenuTest()
% Titre et deux lignes; la première dans un seul TJ à plusieurs colonnes.
% \351 = é, \272 = º, \261 = ± (WinAnsi).
c=['BT /F1 9 Tf 14 TL 1 0 0 1 50 700 Tm (Temp\351rature \(\272C\)) Tj T* ' ...
   '[(-0,080)-6000(0,0)-5000(0,08)-4000(\261 0,27)-3000(2,00)] TJ ' ...
   '0 -14 Td (25,020) Tj 60 0 Td (24,9) Tj 50 0 Td (-0,12) Tj 45 0 Td (\261 0,42) Tj 40 0 Td (2,00) Tj ET'];
end

function p = ecrirePDF(testCase,contenu,compresser)
octets=uint8(contenu);
if compresser
    bo=java.io.ByteArrayOutputStream(); dz=java.util.zip.DeflaterOutputStream(bo);
    dz.write(typecast(octets,'int8')); dz.close();
    octets=typecast(bo.toByteArray()','uint8'); filtre=' /Filter /FlateDecode';
else
    filtre='';
end
entete=uint8(sprintf('%%PDF-1.4\n4 0 obj\n<< /Length %d%s >>\nstream\n',numel(octets),filtre));
fin=uint8(sprintf('\nendstream\nendobj\n%%%%EOF\n'));
p=[tempname '.pdf']; fid=fopen(p,'w'); fwrite(fid,[entete octets fin],'uint8'); fclose(fid);
testCase.addTeardown(@()delete(p));
end
