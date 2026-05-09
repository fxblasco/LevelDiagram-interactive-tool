function plotGPPScale(pref, etiqPref)
% plotGPPScale  Plot the GPP class function g(J_i) for each objective.
%
%   plotGPPScale(pref)
%   plotGPPScale(pref, etiqPref)
%
%   Produces a figure with one subplot per objective (all in a single row).
%   Each subplot shows the piecewise-linear GPP function, shaded regions for
%   each class range, and vertical boundary markers.
%
%   Inputs
%   ------
%   pref     : (nobj x (nranges+1)) preference table — same format as gppl.m.
%              Each row contains the class-range boundaries for one objective.
%   etiqPref : (optional) cell array of range labels.
%              Accepted lengths:
%                nranges       — labels for explicit ranges; the extrapolated
%                                range is labelled automatically as last + '+'.
%                nranges + 1   — labels for all ranges including extrapolated.
%              If omitted, {'R1','R2',...} is used.
%
%   Example
%   -------
%   pref = [0  1  3;    % J1: Desirable=[0,1], Tolerable=(1,3], Undesirable=(3,Inf)
%           0  5  8];   % J2: Desirable=[0,5], Tolerable=(5,8], Undesirable=(8,Inf)
%   plotGPPScale(pref, {'D','T','U'})

%% --- Input validation ---
[nobj, npref] = size(pref);
nranges       = npref - 1;
nreg_total    = nranges + 1;

% Check for non-monotonic or zero-width ranges
widths = diff(pref, 1, 2);   % [nobj x nranges]
if any(widths(:) < 0)
    error('plotGPPScale: pref contains non-monotonic bounds (decreasing values).');
end
if any(widths(:) == 0)
    [fi, ci] = find(widths == 0);
    warning('plotGPPScale: zero-width range in objective J%d between columns %d-%d. Replaced with a small value to avoid infinite slope.', ...
            fi(1), ci(1), ci(1)+1);
    widths(widths == 0) = 1e-6;
    for ii = 1:nobj
        for jj = 1:nranges
            pref(ii, jj+1) = pref(ii, jj) + widths(ii, jj);
        end
    end
end

% Build label array (same logic as gppl.m)
if nargin < 2 || isempty(etiqPref)
    etiqPref = arrayfun(@(k) sprintf('R%d', k), 1:nreg_total, 'UniformOutput', false);
else
    nLabels = length(etiqPref);
    if nLabels == nranges
        % Auto-label the extrapolated range
        etiqPref{nreg_total} = [etiqPref{nranges} '+'];
    elseif nLabels ~= nreg_total
        error('plotGPPScale: etiqPref must have %d labels (explicit ranges) or %d (including extrapolated). Got %d.', ...
              nranges, nreg_total, nLabels);
    end
end

%% --- Normalised scale (identical to gppl.m) ---
dx      = 1;
ntotal  = nranges + 1;
x_nodes = zeros(1, 2*ntotal + 1);
x_nodes(1) = 0;
x_nodes(2) = dx;
x_nodes(3) = nobj * x_nodes(2);
for ii = 4:length(x_nodes)
    if mod(ii, 2) == 0
        x_nodes(ii) = x_nodes(ii-1) + dx;
    else
        x_nodes(ii) = nobj * x_nodes(ii-1);
    end
end

%% --- Slopes (protected against zero-width division) ---
slopes = dx ./ widths;   % [nobj x nranges]

%% --- Region colours ---
regionColors = buildRegionColors(nreg_total);
boundColors  = zeros(nranges, 3);
for k = 1:nranges
    boundColors(k,:) = min(0.6 * (regionColors(k,:) + regionColors(k+1,:)) / 2, 1);
end

%% --- Figure layout: all objectives in a single row ---
nPts   = 500;
margin = 0.15;

figW = max(380 * nobj, 560);
figH = 370;
fig = figure('Name',     'GPP class functions', ...
             'Color',    'white', ...
             'Position', [80, 80, figW, figH]);
tl = tiledlayout(fig, 1, nobj, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:nobj

    nexttile(tl);
    hold on;

    % J range to display
    rangeJ = pref(i, end) - pref(i, 1);
    if rangeJ < 1e-6; rangeJ = 1; end
    J_min  = pref(i, 1)   - margin * 0.3 * rangeJ;
    J_max  = pref(i, end) + margin * rangeJ;
    J_vals = linspace(J_min, J_max, nPts);

    % GPP curve
    gppVals = evalGPPCurve(J_vals, pref(i,:), slopes(i,:), x_nodes, nranges);

    % Y-axis limits
    y_lo = min(gppVals) - 0.5;
    y_hi = max(gppVals) + 0.5;

    % Shaded regions
    regBounds = [J_min, pref(i, 2:end), J_max];
    for r = 1:nreg_total
        fill([regBounds(r) regBounds(r+1) regBounds(r+1) regBounds(r)], ...
             [y_lo y_lo y_hi y_hi], ...
             regionColors(r,:), 'EdgeColor', 'none', 'FaceAlpha', 0.50);
    end

    % Vertical boundary lines
    for k = 1:nranges
        lineStyle = '-';
        if k == nranges; lineStyle = '--'; end
        xline(pref(i, k+1), lineStyle, ...
              'Color',                    boundColors(k,:), ...
              'LineWidth',                1.5, ...
              'Label',                    sprintf('%s|%s', etiqPref{k}, etiqPref{k+1}), ...
              'LabelVerticalAlignment',   'bottom', ...
              'LabelHorizontalAlignment', 'center', ...
              'FontSize', 8, 'FontWeight', 'bold');
    end

    % GPP curve (drawn on top of shading)
    plot(J_vals, gppVals, 'k-', 'LineWidth', 2.2);

    % Nodes at preference boundaries
    for r = 1:nranges
        Jnode = pref(i, r);
        gNode = evalGPPCurve(Jnode, pref(i,:), slopes(i,:), x_nodes, nranges);
        scatter(Jnode, gNode, 55, 'k', 'filled');
    end

    % Region labels
    for r = 1:nreg_total
        if r == 1
            x_mid = (J_min + pref(i, 2)) / 2;
        elseif r <= nranges
            x_mid = (pref(i, r) + pref(i, r+1)) / 2;
        else
            x_mid = pref(i, end) + margin * 0.5 * rangeJ;
        end
        relWidth = (regBounds(r+1) - regBounds(r)) / rangeJ;
        if relWidth > 0.03
            textColor = regionColors(r,:) * 0.55;
            text(x_mid, y_hi * 0.88, etiqPref{r}, ...
                 'FontSize', 10, 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'center', ...
                 'Color', textColor);
        end
    end

    % Axes formatting
    xlabel(sprintf('J_%d', i), 'FontSize', 11);
    ylabel(sprintf('g(J_%d)', i), 'FontSize', 10);
    title(sprintf('J_%d  [%s]', i, num2str(pref(i,:), '%.2g  ')), ...
          'FontSize', 10, 'FontWeight', 'bold');
    ylim([y_lo, y_hi]);
    xlim([J_min, J_max]);
    grid on; box on;
    set(gca, 'FontSize', 10, 'Layer', 'top');
    hold off;
end

title(tl, 'Class function per objective', ...
      'FontSize', 13, 'FontWeight', 'bold');
end

% -------------------------------------------------------------------------
function gpp = evalGPPCurve(J_vals, pref_i, slopes_i, x_nodes, nranges)
% Evaluate the piecewise-linear GPP function for one objective.
gpp = zeros(size(J_vals));
for k = 1:numel(J_vals)
    Jval = J_vals(k);
    seg  = find(pref_i(2:end) < Jval, 1, 'last');
    if isempty(seg); seg = 0; end
    if seg < nranges
        r      = seg + 1;
        x_base = x_nodes(2*seg + 1);
        gpp(k) = slopes_i(r) * (Jval - pref_i(r)) + x_base;
    else
        x_base = x_nodes(2*nranges + 1);
        gpp(k) = slopes_i(nranges) * (Jval - pref_i(nranges+1)) + x_base;
    end
end
end

% -------------------------------------------------------------------------
function C = buildRegionColors(n)
% Returns n RGB colours for the class-range shading (green → yellow → red).
anchors = [0.80 0.95 0.80;   % green  (most desirable)
           0.95 0.95 0.70;   % yellow
           0.95 0.78 0.70;   % orange-red
           0.78 0.88 0.95;   % blue
           0.90 0.80 0.95;   % purple
           0.85 0.85 0.85];  % grey   (least desirable)
if n <= size(anchors, 1)
    C = anchors(1:n, :);
else
    t_ref = linspace(0, 1, size(anchors, 1));
    t_new = linspace(0, 1, n);
    C = interp1(t_ref, anchors, t_new, 'linear');
    C = min(max(C, 0), 1);
end
end
