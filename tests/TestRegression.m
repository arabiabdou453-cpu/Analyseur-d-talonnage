classdef TestRegression < matlab.unittest.TestCase
    methods (Test)
        function casAExact(testCase)
            x=[0;10;20;30]; C=[.1;.2;.3;.4]; U=[.2;.22;.24;.26]; o=parametresParDefaut();
            c=ajusterDroite(x,C,o); u=ajusterDroite(x,U,o);
            testCase.verifyEqual(c.a,.01,'AbsTol',1e-12); testCase.verifyEqual(c.b,.1,'AbsTol',1e-12);
            testCase.verifyEqual(c.residuSigne,zeros(4,1),'AbsTol',1e-12); testCase.verifyEqual(c.R2,1,'AbsTol',1e-12);
            testCase.verifyEqual(u.a,.002,'AbsTol',1e-12); testCase.verifyEqual(u.b,.2,'AbsTol',1e-12);
            testCase.verifyEqual(.25*mean(U),.0575,'AbsTol',1e-12);
            T=table(x,C,U,'VariableNames',{'Indication','Correction','Incertitude'}); meta=struct('natureIncertitude','Élargie U','uniteIndication','u','uniteCorrection','u'); a=analyserEtalonnage(T,meta,o);
            testCase.verifyGreaterThanOrEqual(a.majorante.y,U-1e-12);
            r=calculerResultat(15,a,o,struct('confirme',true,'correction','regression','incertitude','majorante'));
            testCase.verifyEqual(r.correction,.25,'AbsTol',1e-12); testCase.verifyEqual(r.valeurCorrigee,15.25,'AbsTol',1e-12);
            testCase.verifyEqual(r.incertitude,.23,'AbsTol',1e-12);
            testCase.verifyError(@()calculerResultat(31,a,o,struct('confirme',true,'correction','regression','incertitude','majorante')),'Etalonnage:HorsEtendue');
        end
        function casBReference(testCase)
            x=[0;20;50;80;100]; C=[.4;.1;.8;.3;.2]; U=[.8;.3;.5;.7;.2]; o=parametresParDefaut();
            c=ajusterDroite(x,C,o); u=ajusterDroite(x,U,o);
            testCase.verifyEqual(c.a,-.0005882352941176471,'AbsTol',1e-12);
            testCase.verifyEqual(c.b,.3894117647058824,'AbsTol',1e-12);
            testCase.verifyEqual(c.residuMax,.44,'AbsTol',1e-12);
            testCase.verifyEqual(c.R2,.008058017727639,'AbsTol',1e-12);
            testCase.verifyEqual(c.sRes,.3107233811734211,'AbsTol',1e-12);
            testCase.verifyEqual(u.b+.2794117647058824,.911764705882353,'AbsTol',1e-12);
            testCase.verifyEqual(polyfit(x,C,1),[c.a c.b],'AbsTol',1e-12);
        end
        function casConstant(testCase)
            m=ajusterDroite([0;10;20],[.2;.2;.2],parametresParDefaut());
            testCase.verifyEqual(m.a,0,'AbsTol',1e-12); testCase.verifyTrue(isnan(m.R2));
            testCase.verifyEqual(m.sRes,0,'AbsTol',1e-12);
        end
        function validationEtSeuils(testCase)
            o=parametresParDefaut(); T=table([0;10],[.1;.2],[.2;.3],'VariableNames',{'Indication','Correction','Incertitude'});
            r=validerDonnees(T,struct(),o); testCase.verifyFalse(r.valide);
            T=table([10;10;10],[.1;.2;.3],[.2;.3;.4],'VariableNames',{'Indication','Correction','Incertitude'});
            r=validerDonnees(T,struct(),o); testCase.verifyFalse(r.valide);
            T=table([0;10;20],[.1;.2;.3],[.2;-.1;.4],'VariableNames',{'Indication','Correction','Incertitude'});
            r=validerDonnees(T,struct(),o); testCase.verifyFalse(r.valide);
        end
        function interpolationAuxPoints(testCase)
            m=ajusterDroite([0;10;20],[1;3;2],parametresParDefaut());
            testCase.verifyEqual(interpolationCorrection(10,m),3,'AbsTol',1e-12);
            testCase.verifyError(@()interpolationCorrection(21,m),'Etalonnage:HorsEtendue');
        end
        function sessionVersionnee(testCase)
            p=[tempname '.mat']; c=onCleanup(@()deleteIfExists(p));
            s=struct('donnees',table([0;1;2],[1;1;1],[.1;.2;.3],'VariableNames',{'Indication','Correction','Incertitude'}), ...
                'donneesOriginales',table([0;1;2],[1;1;1],[.1;.2;.3],'VariableNames',{'Indication','Correction','Incertitude'}), ...
                'metadata',struct(),'options',parametresParDefaut(),'modelesConfirmes',true);
            sauvegarderSession(p,s); z=chargerSession(p); testCase.verifyFalse(z.modelesConfirmes); clear c
        end
    end
end
function deleteIfExists(p), if exist(p,'file'), delete(p); end, end
