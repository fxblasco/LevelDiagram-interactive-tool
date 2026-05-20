function M = prefToDirections(pref, bounds)
% prefToDirections  Build preference direction matrix M from a GPP table.
%
%   M = prefToDirections(pref, bounds)
%
%   Converts a GPP preference table into the matrix of preference directions
%   M whose columns are used as input to dominanceCone().
%
%   Strategy
%   --------
%   Each preference direction v_k is set to the GPP gradient in range k,
%   expressed in the normalised space:
%
%       v_k  =  [ 1/w_1k,  1/w_2k, ...,  1/w_nk ]
%
%   where w_ik = normalised width of range k for objective i.
%
%   This is the direction of steepest GPP ascent within the k-th range cell:
%   objectives with a narrow range (steep GPP slope) receive a larger
%   component, reflecting that small changes in those objectives have a
%   larger GPP impact.  v1 is derived from R1 (most preferred range).
%
%   When fewer explicit ranges than objectives are available, the remaining
%   columns fall back to the canonical unit vector least aligned with the
%   already-computed directions.
%
%   All columns are unit-normalised.  All components are positive by
%   construction (widths > 0).
%
%   Inputs
%   ------
%   pref   : (nobj x (nranges+1)) GPP preference table (original units).
%            Same format as gppl().
%   bounds : (2 x nobj) normalisation bounds [max; min].
%            Same format as ld.globalBounds.
%
%   Output
%   ------
%   M : (nobj x nobj) preference direction matrix.
%       Each column is a unit preference direction vector (all components >= 0).
%       Pass to dominanceCone() to obtain the dominance cone matrix Md.
%
%   Note: this function is experimental.  Use plotPreferenceDirections2D()
%   to visually verify that the resulting directions are geometrically
%   coherent with the original preference table.

[nobj, npref] = size(pref);
nranges       = npref - 1;

if nobj ~= 2
    warning('prefToDirections: designed and tested for nobj = 2. Use with care for higher dimensions.');
end

% --- Normalise pref ---
minb  = bounds(2, :)';
rangb = bounds(1, :)' - minb;
rangb(rangb == 0) = 1;
pref_norm = (pref - minb) ./ rangb;   % (nobj x npref)

% --- Range widths and GPP slopes in normalised space ---
widths = diff(pref_norm, 1, 2);        % (nobj x nranges), all >= 0
widths(widths <= 0) = 1e-6;            % guard against zero-width ranges
slopes = 1 ./ widths;                  % GPP gradient components per range

% --- Build M column by column ---
M = zeros(nobj, nobj);

% Canonical axes sorted by ascending alignment with the first direction
% (used as fallback when nranges < nobj)
canonIdx = 1;

for k = 1:nobj
    if k <= nranges
        % v_k = GPP gradient direction in range k (R1 first)
        vk = slopes(:, k);
    else
        % Fallback: canonical axis least aligned with already-built directions
        if k == 1
            % No direction yet; use first canonical axis
            vk       = zeros(nobj, 1);
            vk(1)    = 1;
            canonIdx = canonIdx + 1;
        else
            % Find canonical axis most independent from M(:,1:k-1)
            dots = max(abs(M(:, 1:k-1)), [], 2);  % max projection onto existing
            [~, sortedEi] = sort(dots, 'ascend');
            vk = zeros(nobj, 1);
            vk(sortedEi(canonIdx)) = 1;
            canonIdx = canonIdx + 1;
        end
    end
    M(:, k) = vk / norm(vk);
end
end
