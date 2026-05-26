function [M,Md]=plotPreferenceDirections2D(pref, bounds)
% plotPreferenceDirections2D  Visualise preference directions and dominance
%   cone in 2-objective space.
%
%   plotPreferenceDirections2D(pref, bounds)
%
%   Draws three panels:
%     1. Preference ranges (GPP table) as coloured bands in objective space,
%        with the preference direction vectors v1, v2 as arrows.
%     2. Dominance cone vectors vd1, vd2 (columns of Md = dominanceCone(M)).
%     3. Dominance cone from a sample point: the region of points that the
%        sample dominates (in the transformed space).
%
%   Inputs
%   ------
%   pref   : (2 x (nranges+1)) GPP preference table — exactly 2 objectives.
%   bounds : (2 x 2) normalisation bounds [max; min].

assert(size(pref,1) == 2, 'plotPreferenceDirections2D: requires exactly 2 objectives.');

% --- Build preference directions and dominance cone ---
M  = prefToDirections(pref, bounds);
Md = dominanceCone(M);

nranges = size(pref, 2) - 1;

% --- Axis limits: slightly beyond last pref column ---
margin = 0.15 * (pref(:,end) - pref(:,1));
xLim   = [pref(1,1) - margin(1),  pref(1,end) + 2*margin(1)];
yLim   = [pref(2,1) - margin(2),  pref(2,end) + 2*margin(2)];

% --- Colours for preference ranges (grey scale: light=better, dark=worse) ---
bandColors = [0.90 0.90 0.90;   % range 1 — grey claro (mejor)
              0.80 0.80 0.80;   % range 2 — grey
              0.70 0.70 0.70;   % range 3 — grey
              0.50 0.50 0.50];  % range 4+ — grey oscuro (peor)
nColors = size(bandColors, 1);

% Arrow scale: fraction of axis range
arrowScale = 0.30 * min(diff(xLim), diff(yLim));

% Origin for arrows: lower-left corner of first range (ideal point)
origin = pref(:, 1);

% Sample point for dominance cone: centre of first range
samplePt = (pref(:,1) + pref(:,2)) / 2;
coneLen  = arrowScale * 2.5;

% =====================================================================
fig = figure('Name', 'Preference directions (2D)', ...
             'Color', 'white', ...
             'Position', [60 60 900 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Preference directions and dominance cone (2D)', ...
      'FontSize', 13, 'FontWeight', 'bold');

% =====================================================================
% Panel 1 — Preference ranges + M vectors + Md vectors
% =====================================================================
ax1 = nexttile(tl);
hold(ax1, 'on');

% Draw GPP grid cells: colour by max(i,j), opacity by purity (i==j)
drawGPPGrid(ax1, pref, nranges, bandColors, nColors, 0.70, xLim, yLim);

% Draw M vectors as arrows from origin
colM = [0.13 0.47 0.71;   % v1 — blue
        0.85 0.33 0.10];  % v2 — orange
for k = 1:2
    v  = M(:, k) * arrowScale;
    quiver(ax1, origin(1), origin(2), v(1), v(2), 0, ...
           'Color', colM(k,:), 'LineWidth', 2.2, 'MaxHeadSize', 0.5);
    text(ax1, origin(1)+v(1)*1.12, origin(2)+v(2)*1.12, ...
         sprintf('v_{%d}', k), ...
         'Color', colM(k,:), 'FontSize', 11, 'FontWeight', 'bold');
end

% Draw Md vectors as arrows from origin
colMd = [0.17 0.63 0.17;   % vd1 — green
         0.49 0.18 0.56];  % vd2 — purple
for k = 1:2
    vd = Md(:,k) * arrowScale;
    quiver(ax1, origin(1), origin(2), vd(1), vd(2), 0, ...
           'Color', colMd(k,:), 'LineWidth', 2.2, 'MaxHeadSize', 0.5);
    text(ax1, origin(1)+vd(1)*1.12, origin(2)+vd(2)*1.12, ...
         sprintf('vd_{%d}', k), ...
         'Color', colMd(k,:), 'FontSize', 11, 'FontWeight', 'bold');
end

% Diagonal of first range (dashed line)
plot(ax1, [pref(1,1) pref(1,2)], [pref(2,1) pref(2,2)], ...
     'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');

formatAx(ax1, xLim, yLim, 'J_1', 'J_2', 'Preference ranges,  M  &  Md vectors');

% =====================================================================
% Panel 3 — Dominance cone from sample point
% =====================================================================
ax3 = nexttile(tl);
hold(ax3, 'on');

% Background: GPP grid cells (lighter for the cone panel)
drawGPPGrid(ax3, pref, nranges, bandColors, nColors, 0.35, xLim, yLim);

% Dominance cone from samplePt:
% The sample point dominates {samplePt + Md*t : t >= 0} — draw boundary rays
ray1 = samplePt + Md(:,1) * coneLen;
ray2 = samplePt + Md(:,2) * coneLen;
corner = samplePt + (Md(:,1) + Md(:,2)) * coneLen;

% Filled cone region (two rays + far corner)
fill(ax3, [samplePt(1) ray1(1) corner(1) ray2(1)], ...
          [samplePt(2) ray1(2) corner(2) ray2(2)], ...
     [0.85 0.85 0.95], 'EdgeColor', 'none', 'FaceAlpha', 0.55);

% Ray borders
plot(ax3, [samplePt(1) ray1(1)], [samplePt(2) ray1(2)], ...
     'b-', 'LineWidth', 1.8);
plot(ax3, [samplePt(1) ray2(1)], [samplePt(2) ray2(2)], ...
     'b-', 'LineWidth', 1.8);

% Sample point
scatter(ax3, samplePt(1), samplePt(2), 80, 'k', 'filled');
text(ax3, samplePt(1) - margin(1)*0.6, samplePt(2) - margin(2)*0.4, ...
     'A', 'FontSize', 11, 'FontWeight', 'bold');
text(ax3, samplePt(1) + margin(1)*0.2, samplePt(2) + margin(2)*1.5, ...
     'A dominates', 'FontSize', 9, 'Color', [0.2 0.2 0.7]);

formatAx(ax3, xLim, yLim, 'J_1', 'J_2', 'Dominance cone from point A');
end

% -------------------------------------------------------------------------
function drawGPPGrid(ax, pref, nranges, bandColors, nColors, alphaScale, xLim, yLim)
% drawGPPGrid  Draw per-objective GPP range cells on ax, covering the full plot.
%   Each cell (i,j) is coloured by blending the colours of range i and
%   range j: diagonal cells (i==j) get the pure range colour; off-diagonal
%   cells get the average of the two range colours, reflecting both
%   objectives simultaneously.
%   Labels appear in all cells showing (Ri,Rj).
xB = pref(1,:);
yB = pref(2,:);

% Extend boundaries to cover the full plot
xB_ext = [xLim(1), xB(2:end-1), xLim(2)];
yB_ext = [yLim(1), yB(2:end-1), yLim(2)];

for i = 1:nranges
    for j = 1:nranges
        ci = bandColors(min(i, nColors), :);
        cj = bandColors(min(j, nColors), :);
        fc = (ci + cj) / 2;          % colour blend of both ranges
        fill(ax, [xB_ext(i) xB_ext(i+1) xB_ext(i+1) xB_ext(i)], ...
                 [yB_ext(j) yB_ext(j)   yB_ext(j+1) yB_ext(j+1)], fc, ...
             'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 0.6, 'FaceAlpha', alphaScale);
    end
end
% Labels in all cells showing (Ri,Rj)
for i = 1:nranges
    for j = 1:nranges
        xCenter = (xB_ext(i) + xB_ext(i+1)) / 2;
        yCenter = (yB_ext(j) + yB_ext(j+1)) / 2;
        text(ax, xCenter, yCenter, sprintf('(R%d,R%d)', i, j), ...
             'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
             'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);
    end
end
end

% -------------------------------------------------------------------------
function formatAx(ax, xLim, yLim, xlab, ylab, ttl)
xlabel(ax, xlab, 'FontSize', 11);
ylabel(ax, ylab, 'FontSize', 11);
title(ax, ttl, 'FontSize', 10, 'FontWeight', 'bold');
xlim(ax, xLim);
ylim(ax, yLim);
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontSize', 10, 'Layer', 'top');
hold(ax, 'off');
end
