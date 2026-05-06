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
%             ld.globalBounds.  If omitted, uses min/max of pf.
%
%   dn      : (np x 1)  composed norm value for each point (preserves order)
%   offsets : (nI x 1)  Y-axis offset per hypercube band (offsets(1) = 0)
%
%   Objectives and preference table are normalized to [0,1] before computing
%   the composed norm, so dn values are consistent with the LD Y-axis.
%
% Example:
%   [dn, offsets] = composedNorm(pf, pref, ld.globalBounds);
%   ld.syncBy({dn});

if nargin < 3 || isempty(bounds)
    % No bounds provided: work on raw objective values (no normalization)
    pfNorm   = pf;
    prefNorm = pref;
else
    % Normalize pf and pref with provided bounds (same as LD's computeNorm)
    maxb  = bounds(1,:);
    minb  = bounds(2,:);
    range = maxb - minb;
    range(range == 0) = 1;
    pfNorm   = max(0, min(1, (pf   - minb) ./ range));      % clipped to [0,1]
    prefNorm = (pref - minb') ./ range';                     % not clipped
end

np = size(pfNorm, 1);
nI = size(prefNorm, 2);

hypercube = zeros(np, 1);
d         = zeros(np, 1);

for i = 1:np
    for x = nI:-1:1
        daux = norm(max(pfNorm(i,:) - prefNorm(:,x)', 0));
        if daux ~= 0 || x == 1
            hypercube(i) = x;
            d(i)         = daux;
            break;
        end
    end
end

dmax = zeros(nI, 1);
for x = 1:nI
    vals = d(hypercube == x);
    if ~isempty(vals)
        dmax(x) = max(vals);
    end
end
offsets = [0; cumsum(dmax(1:end-1))];

dn = d + offsets(hypercube);
end
