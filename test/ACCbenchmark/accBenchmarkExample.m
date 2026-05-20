%% ACC Benchmark — Level Diagram step-by-step example
%
% Example from:
%   Blasco, X., Reynoso-Meza, G., Sánchez Pérez, E.A., Sánchez Pérez, J.V. (2016).
%   Asymmetric distances to improve n-dimensional Pareto fronts graphical analysis.
%   Information Sciences, 340-341, 228-249.
%   http://dx.doi.org/10.1016/j.ins.2015.12.039
%
% The Pareto front was obtained with evMOGA on the ACC benchmark problem
% (6 objectives, 6 controller parameters).
%
% Objectives:
%   f1 - Robust stability margin
%   f2 - Maximum control effort (worst case)
%   f3 - Worst-case settling time
%   f4 - Noise sensitivity
%   f5 - Nominal control effort
%   f6 - Nominal settling time
%
% Run this script section by section (Ctrl+Enter) to follow the workflow.

%% 1. Load data
% Pareto front (pf) and Pareto set (ps) from the ACC benchmark optimisation.
load accbench6_ev.mat
pf = ParetoFront;
ps = ParetoSet;

%% 2. Define preferences
% Preference table: one row per objective, columns are class-range boundaries.
%   col 1      : lower bound of the most desirable range
%   col 2..end : boundaries between ranges (HD|D, D|T, T|U, U|HU)
% Range labels: HD = Highly Desirable, D = Desirable, T = Tolerable,
%               U = Undesirable,       HU = Highly Undesirable
pref = [-10 -0.01 -0.005 -0.001 -0.0005 -0.0001;   % f1
          0  0.85    0.9      1     1.5       2;     % f2
          0    14     20     30      35      40;     % f3
          0   0.5    0.9    1.2     1.4     1.5;    % f4
          0   0.5    0.7      1     1.5       2;     % f5
          0    10     11     15      20      25];    % f6
etiqPref = {'HD','D','T','I','U','HU'};

%% 3. Compute GPP index
% Global Physical Programming index ranks solutions according to preferences.
% Lower GPP value = better solution.
% Reference: Reynoso-Meza et al. (2014) https://doi.org/10.1016/j.asoc.2014.07.009

vgpp = gppl(pf, pref);                        % GPP index only
[vgpp, etiquetas] = gppl(pf, pref, etiqPref); % GPP index + per-solution labels

%% 4. Build the Level Diagram
c1 = Concept(pf, ps, 'accBenchmark');
c1.labels.objectives = {'f1-Robust Stab.','f2-Max. u','f3-Worst te', ...
                         'f4-Noise Sens.','f5-Nom. u','f6-Nom. te'};
c1.labels.parameters = {'x1','x2','x3','x4','x5','x6'};
disp(c1)

ld = LevelDiagram('ld1');
ld.addConcept(c1);
disp(ld)
ld.draw();
ld.setSyncLabel('L2 norm');

%% 5. Colour by asymmetric distance to the tolerable point
% Asymmetric distance measures how far each solution is from dominating
% the target point p_des. Zero means the solution already dominates it.
% See Fig. 17-18 in Blasco et al. (2016).
p_des = pref(:,3)';                                       % tolerable boundary vertex
da    = asymmetricDist(p_des, pf);
ld.colorBy(c1, da, 'colormap', 'hot', 'label', 'Asym. dist. to tolerable point');

% Synch by asymmetric distance from tolerable vertex. 
ld.syncBy({da});
ld.setSyncLabel('Asym dist from Tolerable Vertex');

%% 6. Colour by GPP index (log scale for better colour contrast)
ld.colorBy(c1, log10(vgpp), 'colormap', 'hot', 'label', 'log10(GPP)');

% Register callback: clicking a point prints its GPP details in the console.
ld.onSelect(c1, @displayGPPInfo);


% 6b. Colour by solutions increasing x5 
ld.colorBy(c1, ps(:,5), 'colormap', 'hot', 'label', 'x5');


%% 8. Highlight solutions that already dominate the tolerable point (da == 0)
% Extract them as a separate concept and display them with a larger marker.
mask       = da == 0;
subset_da0 = c1.extractSubset(mask);
ld.addConcept(subset_da0);
ld.setSize(subset_da0, 120)

ld.removeConcept(subset_da0);   % remove subset when done



%% 9. Switch synchronisation norm
ld.syncByNorm(inf);
ld.setSyncLabel('L\infty norm');

% ld.syncByNorm(1);  ld.setSyncLabel('L1 norm');
% ld.syncByNorm(2);  ld.setSyncLabel('L2 norm');

%% 10. Synchronise by Composed Norm
% composedNorm assigns each solution to the innermost preference hypercube
% it does not dominate, then measures distance within that hypercube.

[dcn, offsets] = composedNorm(pf, pref);
ld.syncBy({dcn});
ld.setSyncLabel('Composed Norm');

% Colour by composed norm value.
ld.colorBy(c1, dcn, 'colormap', 'jet', 'label', 'Composed Norm');

%% 11. Overlay preference bands on the figures
figObj = findobj(groot, 'Type', 'figure', 'Name', 'Objectives - ld1');
figPar = findobj(groot, 'Type', 'figure', 'Name', 'Parameters - accBenchmark');

% Draw Preference Bands
drawPrefBands(figObj, 'obj', pref, offsets, etiqPref);
drawPrefBands(figPar, 'par',       offsets, etiqPref);

%% 12. Clear bands and redraw
% Closing all figures and calling draw() again removes the preference bands.
close all
ld.draw()
ld.colorBy(c1, dcn, 'colormap', 'jet', 'label', 'Composed Norm');

%% 13. Show control responses on point selection
% Clicking a point simulates the closed-loop response and plots y(t) and u(t).
ld.onSelect(c1, @showControlResponses)
