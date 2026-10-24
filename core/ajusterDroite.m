function modele = ajusterDroite(x,y,options)
%AJUSTERDROITE Ajuste une droite OLS y=a*x+b par formulation centrée.
% Les vecteurs sont en double. s_res=sqrt(SSE/(n-2)) est un indicateur
% d'ajustement, pas automatiquement une incertitude élargie.
if nargin<3, options=parametresParDefaut(); end
x=double(x(:)); y=double(y(:)); n=numel(x);
if n~=numel(y) || n<3 || ~isreal(x) || ~isreal(y) || any(~isfinite(x)) || any(~isfinite(y))
    error('Etalonnage:AjustementEntrees','Il faut au moins trois paires réelles, finies et de même longueur.');
end
xc=mean(x); yc=mean(y); dx=x-xc; dy=y-yc; Sxx=sum(dx.^2);
if Sxx <= eps(max(max(abs(x)),1))^2 * n
    error('Etalonnage:EtendueNulle','Les indications sont constantes ou numériquement dégénérées.');
end
a=sum(dx.*dy)/Sxx; b=yc-a*xc; ajuste=a*x+b; residu=y-ajuste;
SSE=sum(residu.^2); SST=sum(dy.^2);
tol=options.toleranceRelative*max(1,sum(y.^2));
if SST<=tol, R2=NaN; else, R2=1-SSE/SST; end
modele=struct('a',a,'b',b,'x',x,'mesure',y,'ajuste',ajuste,'residuSigne',residu, ...
    'residuAbsolu',abs(residu),'residuMax',max(abs(residu)),'SSE',SSE,'SST',SST, ...
    'R2',R2,'sRes',sqrt(SSE/(n-2)),'n',n,'variableConstante',SST<=tol);
end
