function v = gppl(J, pref)
% gppl  Global Physical Programming index (piecewise-linear version).
%
%   v = gppl(J, pref)
%
%   Computes the GPP index to rank Pareto-front solutions according to
%   decision-maker preferences expressed as class ranges.
%   Inspired by Messac (1996) Physical Programming; the piecewise-linear
%   normalisation used here follows Reynoso-Meza et al. (2014).
%
%   Reference:
%     Reynoso-Meza, G., Sanchis, J., Blasco, X., Garcia-Nieto, S. (2014).
%     Physical programming for preference driven evolutionary
%     multi-objective optimization. Applied Soft Computing, 24, 341-362.
%     https://doi.org/10.1016/j.asoc.2014.07.009
%
%   Inputs
%   ------
%   J    : (ns x nobj) matrix of objective values. Each row is a solution.
%   pref : (nobj x (nranges+1)) preference table.
%          Each row contains the class-range boundaries for one objective:
%            col 1          -> lower bound of the most desirable range
%            col 2..nranges -> boundaries between consecutive ranges (D|T, T|I, ...)
%          The last range is extrapolated automatically using the slope of
%          the preceding range, so no trailing Inf column is needed.
%
%          Example — 2 explicit ranges (Desirable, Tolerable) per objective:
%            pref = [0  1  3;    % J1: D=[0,1], T=(1,3], I=(3,Inf)
%                    0  5  8;    % J2: D=[0,5], T=(5,8], I=(8,Inf)
%                    0  5 15;    % J3: D=[0,5], T=(5,15], I=(15,Inf)
%                    0 12 25];   % J4: D=[0,12], T=(12,25], I=(25,Inf)
%
%   Output
%   ------
%   v : (ns x 1) GPP index for each solution. Lower is better.
%
%   Notes
%   -----
%   - The normalised scale enforces the OVO rule: a balanced solution
%     (all objectives in T) is preferred over one with any objective in I,
%     even if the rest are in D.
%   - Values below pref(i,1) yield a negative contribution for objective i
%     (interpreted as "better than the most desirable bound").
%   - Values beyond the last column of pref are extrapolated linearly
%     using the slope of the last defined range, so solutions in the
%     undesirable region receive distinct penalties (avoids the zero-slope
%     artefact that would arise from an explicit Inf boundary).

[nobj, npref] = size(pref);
nranges = npref - 1;
ns      = size(J, 1);
dx      = 1;

% Normalised scale: alternating range endpoints and OVO jumps.
% One extra range (the extrapolated one) is appended so the OVO jump
% after the last explicit range is still enforced.
ntotal = nranges + 1;
x = zeros(1, 2*ntotal + 1);
x(1) = 0;
x(2) = dx;
x(3) = nobj * x(2);
for k = 4:length(x)
    if mod(k, 2) == 0
        x(k) = x(k-1) + dx;
    else
        x(k) = nobj * x(k-1);
    end
end

% Slope for each objective in each explicitly defined range.
m = dx ./ diff(pref, 1, 2);   % [nobj x nranges]

% --- Fully vectorized computation ---

% seg_mat(i,k): number of upper bounds exceeded by J(k,i), capped at nranges.
% pref(:,2:end) [nobj x nranges] vs J' [nobj x ns] — compare via 3-D broadcast.
seg_mat = squeeze(sum(permute(pref(:,2:end),[1,2,3]) < permute(J',[1,3,2]), 2));
if ns == 1, seg_mat = seg_mat(:); end   % squeeze collapses [nobj x 1] correctly
seg_mat = min(seg_mat, nranges);        % [nobj x ns]

row_idx = repmat((1:nobj)', 1, ns);     % [nobj x ns]
col_seg = seg_mat + 1;                  % 1-based range index

% Pref lower bound of the active range: pref(i, seg+1).
pref_start = pref(sub2ind([nobj, npref], row_idx, col_seg));

% Slope of the active range: m(i, min(seg,nranges-1)+1).
% Extrapolation reuses the last range slope.
slopes_ext = [m, m(:,end)];            % [nobj x nranges+1]
slope_mat  = slopes_ext(sub2ind([nobj, nranges+1], row_idx, min(col_seg, nranges)));

% Normalised-scale base of the active range: x(2*seg+1).
x_node     = x(2*(0:nranges)+1);       % [1 x nranges+1]
x_base_mat = x_node(col_seg);          % [nobj x ns]

% Aggregate over objectives.
v = sum(slope_mat .* (J' - pref_start) + x_base_mat, 1)';
