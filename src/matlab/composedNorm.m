function [dn, offsets] = composedNorm(pf, pref, bounds)
% composedNorm  Composed norm for each point in pf given a preference table.
%
%   [dn, offsets] = composedNorm(pf, pref)
%   [dn, offsets] = composedNorm(pf, pref, bounds)
%
%   pf      : (np x nobj)  Pareto front in original objective units
%   pref    : (nobj x nI)  preference table in original objective units —
%             each column is a hypercube vertex, ordered from most preferred
%             (col 1) to least preferred (col nI)
%   bounds  : (2 x nobj)   normalization bounds [max; min] — same format as
%             ld.globalBounds.  Si se omite, se normaliza respecto al rango
%             de la propia tabla de preferencias.
%
%   dn      : (np x 1)  composed norm value for each point
%   offsets : (nI x 1)  Y-axis offset per hypercube band (offsets(1) = 0)
%
%   Objectives and preference table are normalized before computing
%   the composed norm, so dn values are consistent with the LD Y-axis.
%
% Example:
%   [dn, offsets] = composedNorm(pf, pref);
%   ld.syncBy({dn});

if nargin < 3 || isempty(bounds)
    % Sin bounds: normalizar respecto al rango de la tabla de preferencias
    minb  = min(pref, [], 2)';
    maxb  = max(pref, [], 2)';
    range = maxb - minb;
    range(range == 0) = 1;
    pfNorm   = (pf   - minb) ./ range;
    prefNorm = (pref - minb') ./ range';
else
    % Con bounds externos: normalizar igual que LD (computeNorm)
    maxb  = bounds(1,:);
    minb  = bounds(2,:);
    range = maxb - minb;
    range(range == 0) = 1;
    pfNorm   = max(0, min(1, (pf   - minb) ./ range));      % clipped to [0,1]
    prefNorm = (pref - minb') ./ range';
end

% 
np = size(pfNorm, 1);
nI = size(prefNorm, 2);

hypercube = zeros(np, 1);
d         = zeros(np, 1);

% Asigna cada punto del frente al hipercubo de preferencia más externo al que pertenece, 
% y calcula la distancia al siguiente hipercubo usando asymmetricDist.
for i = 1:np
    for x = nI:-1:1
        %daux = norm(max(pfNorm(i,:) - prefNorm(:,x)', 0));
        daux = asymmetricDist(prefNorm(:,x)', pfNorm(i,:));
        if daux ~= 0 || x == 1
            hypercube(i) = x;
            d(i)         = daux;
            break;
        end
    end
end

% Formulación original (artículo de referencia): dmax depende de los puntos evaluados,
% por lo que los offsets varían entre conjuntos distintos y los valores de dn no son comparables.
% dmax = zeros(nI, 1);
% for x = 1:nI
%     vals = d(hypercube == x);
%     if ~isempty(vals)
%         dmax(x) = max(vals);
%     end
% end

% Formulación basada en la tabla de preferencias: los offsets dependen solo de pref,
% no de los puntos evaluados, por lo que dn es comparable entre distintos conjuntos de soluciones.
dmax = zeros(nI, 1);
% La distancia entre vertices de hipercubos consecutivos en el espacio normalizado.
for x = 1:nI-1
    dmax(x) = norm(prefNorm(:,x+1) - prefNorm(:,x));
end
offsets = [0; cumsum(dmax(1:end-1))];

dn = d + offsets(hypercube);
end
