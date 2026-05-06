function showControlResponses(punto)
% showControlResponses  onSelect callback: simulate and plot closed-loop
%   responses for a selected controller.
%
%   Simulates impulse disturbance rejection for three plant gain values
%   (K = 0.5, 1, 2) to illustrate nominal and worst-case behaviour.
%   Designed to be registered with LevelDiagram.onSelect:
%     ld.onSelect(c1, @showControlResponses)
%
%   Requires MATLAB R2020b+ (tiledlayout).

MAX_POINTS = 6;
if punto.selectionSize > MAX_POINTS
    if punto.selectionIdx == 1
        warndlg(sprintf(['%d points selected.\n' ...
            'This callback only runs with %d or fewer points selected.'], ...
            punto.selectionSize, MAX_POINTS), ...
            'Too many points selected');
    end
    return;
end

% Controller order and gain values to evaluate
ordn = 3;
Ks   = [0.5,             1,               2            ];
lsK  = {'--',            '-',             '-.'         };
lwK  = [ 1.2,            2.2,              1.2         ];
colK = [0.85 0.33 0.10;   % K=0.5  orange
        0.13 0.47 0.71;   % K=1    blue  (nominal)
        0.17 0.63 0.17];  % K=2    green

% Build controller transfer function from selected parameters
x  = punto.parameters;
nc = x(1:ordn);
dc = [1, x(ordn+1:end)];
Gc = tf(nc, dc);

% --- First pass: check stability and find simulation horizon ---
tMax   = 0;
stable = false(1, numel(Ks));
Gbcps  = cell(1, numel(Ks));   % closed-loop output sensitivity
Gbcus  = cell(1, numel(Ks));   % closed-loop input sensitivity

for ki = 1:numel(Ks)
    [Guy, Gwy] = massSpringPlant(Ks(ki), 1, 1);
    Gba = Gc * Guy;
    [~, pbc, ~] = zpkdata(feedback(Gba, 1), 'v');
    if max(real(pbc)) >= 0; continue; end   % skip unstable

    stable(ki) = true;
    Gbcps{ki}  = Gwy * feedback(1, Gba);
    Gbcus{ki}  = -Gwy * feedback(Gc, Guy);

    [~, t_tmp] = impulse(Gbcps{ki});
    tMax = max(tMax, t_tmp(end));
end

if tMax == 0; return; end   % all configurations unstable

tCommon = linspace(0, tMax, 600)';

% --- Create figure ---
fig = figure('Name', sprintf('Control Responses — point %d', punto.index), ...
             'NumberTitle', 'off');
tl  = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Controller  #%d', punto.index), ...
    'FontSize', 11, 'FontWeight', 'bold');

axY = nexttile(tl, 1);
axU = nexttile(tl, 2);

hold(axY, 'on');  grid(axY, 'on');
hold(axU, 'on');  grid(axU, 'on');

ylabel(axY, 'y(t)');
title(axY,  'Impulse disturbance rejection');
xlabel(axU, 'Time (s)');
ylabel(axU, 'u(t)');

% --- Second pass: simulate, plot and compute metrics ---
te_nom    = NaN;  umax_nom   = NaN;
te_worst  = 0;    umax_worst = 0;

for ki = 1:numel(Ks)
    if ~stable(ki); continue; end

    K         = Ks(ki);
    isNominal = (K == 1);

    y = impulse(Gbcps{ki}, tCommon);
    u = impulse(Gbcus{ki}, tCommon);

    plot(axY, tCommon, y, lsK{ki}, 'Color', colK(ki,:), 'LineWidth', lwK(ki), ...
        'DisplayName', sprintf('K = %.1f%s', K, repmat('  (nominal)', isNominal)));
    plot(axU, tCommon, u, lsK{ki}, 'Color', colK(ki,:), 'LineWidth', lwK(ki), ...
        'HandleVisibility', 'off');

    % Settling time: last instant where |y| >= 0.1
    idx = find(abs(y) >= 0.1, 1, 'last');
    te  = tCommon(idx);
    umax = max(abs(u));

    if isNominal
        te_nom   = te;
        umax_nom = umax;
    else
        te_worst   = max(te_worst,   te);
        umax_worst = max(umax_worst, umax);
    end
end

% --- Annotate metrics ---
colNom   = colK(2,:);
colWorst = [0.5 0.5 0.5];

% Settling-time threshold band
yline(axY,  0.1, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');
yline(axY, -0.1, 'k:', 'LineWidth', 0.8, 'HandleVisibility', 'off');

if ~isnan(te_nom)
    xline(axY, te_nom,   '-', sprintf('te nom = %.1f', te_nom), ...
        'Color', colNom,   'LineWidth', 1.2, 'LabelOrientation', 'horizontal', ...
        'LabelVerticalAlignment', 'top', 'HandleVisibility', 'off');
end
if te_worst > 0
    xline(axY, te_worst, '--', sprintf('te worst = %.1f', te_worst), ...
        'Color', colWorst, 'LineWidth', 1.0, 'LabelOrientation', 'horizontal', ...
        'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
if ~isnan(umax_nom)
    yline(axU,  umax_nom, '-', sprintf('umax nom = %.2f', umax_nom), ...
        'Color', colNom,   'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left', ...
        'HandleVisibility', 'off');
    yline(axU, -umax_nom, '-', ...
        'Color', colNom,   'LineWidth', 1.2, 'HandleVisibility', 'off');
end
if umax_worst > 0
    yline(axU,  umax_worst, '--', sprintf('umax worst = %.2f', umax_worst), ...
        'Color', colWorst, 'LineWidth', 1.0, 'LabelHorizontalAlignment', 'right', ...
        'HandleVisibility', 'off');
    yline(axU, -umax_worst, '--', ...
        'Color', colWorst, 'LineWidth', 1.0, 'HandleVisibility', 'off');
end

legend(axY, 'Location', 'best', 'FontSize', 8);
linkaxes([axY, axU], 'x');
end

%% -----------------------------------------------------------------------
function [Guy, Gwy] = massSpringPlant(k, m1, m2)
% massSpringPlant  Transfer functions of the ACC mass-spring benchmark plant.
%
%   Returns the input-output (Guy) and disturbance-output (Gwy) transfer
%   functions of the two-mass system used in the ACC benchmark:
%     Guy : control input u -> output y
%     Gwy : disturbance w  -> output y
nuy = k / (m1*m2);
duy = conv([1 0 0], [1  0  (k*(m1+m2))/(m1*m2)]);
nwy = (1/m2) * [1  0  k/m1];
Guy = tf(nuy, duy);
Gwy = tf(nwy, duy);
end
