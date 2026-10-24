function s = r2Text(v)
%R2TEXT Formate R² sans masquer le cas des données constantes.
if isnan(v)
    s='Non défini : données constantes';
else
    s=sprintf('%.8g',v);
end
end
