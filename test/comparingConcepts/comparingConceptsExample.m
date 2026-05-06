%% Comparing Concepts — LevelDiagram feature demonstration
%
% Step-by-step script showing the main features of LevelDiagram when
% comparing multiple Pareto fronts (Concepts).
%
% NOTE: The objective and parameter values used here are randomly generated
% and do NOT represent a real control design problem. The controller names
% (PID, GPC, MPC) are used only to illustrate a typical multi-concept
% comparison workflow.
%
% Run each section with Ctrl+Enter to follow the workflow.

%% 1. Generate random candidate solutions and extract Pareto fronts
%
% A large pool of random candidates is generated for each controller family.
% dominance() filters out dominated solutions, so the resulting pf/ps pairs
% are proper Pareto fronts and sets — even though the data is synthetic.

rng(42)   % fix seed for reproducibility

% PID — 4 objectives, 3 parameters
[pf1, ps1] = dominance(rand(300,4)*100, rand(300,3));

% GPC — 4 objectives, 2 parameters
[pf2, ps2] = dominance(rand(250,4)*100, rand(250,2));

% MPC — 4 objectives, 4 parameters
[pf3, ps3] = dominance(rand(280,4)*100, rand(280,4));

fprintf('Pareto front sizes after dominance filtering:\n');
fprintf('  PID: %d solutions\n', size(pf1,1));
fprintf('  GPC: %d solutions\n', size(pf2,1));
fprintf('  MPC: %d solutions\n', size(pf3,1));

%% 2. Create Concept objects
%
% Each Concept wraps a Pareto front (objectives) and its corresponding
% Pareto set (parameters) with a name and optional axis labels.

c1 = Concept(pf1, ps1, 'PID');
c1.labels.objectives = {'IAE1','TV1','IAE2','TV2'};
c1.labels.parameters = {'Kp','Ti','Td'};

c2 = Concept(pf2, ps2, 'GPC');
c2.labels.objectives = {'IAE1','TV1','IAE2','TV2'};
c2.labels.parameters = {'N','Nu'};

c3 = Concept(pf3, ps3, 'MPC');
c3.labels.objectives = {'IAE1','TV1','IAE2','TV2'};
c3.labels.parameters = {'Np','Nc','Q','R'};

disp(c1); disp(c2); disp(c3)

%% 3. Build the Level Diagram and add concepts
%
% Global normalisation bounds are computed automatically and updated each
% time a new concept is added. The Y-axis (sync value) is the L2 norm by
% default.

ld = LevelDiagram('ld1');
ld.addConcept(c1);   % bounds = auto from c1
ld.addConcept(c2);   % bounds = union(c1, c2),  both recalculated
ld.addConcept(c3);   % bounds = union(c1,c2,c3), all recalculated
ld.setSyncLabel('L2 norm');
disp(ld)

%% 4. Draw the Level Diagram
ld.draw();

%% 5. Change the sync-axis label
%
% The label appears on the Y-axis of every subplot and in the Info Panel.
ld.setSyncLabel('L2 norm');
ld.setSyncLabel('f_{sync}');   % restore default label

%% 6. Set per-concept markers
ld.setMarker(c1, 'o');
ld.setMarker(c2, 's');
ld.setMarker(c3, '*');

%% 7. Colour coding
%
% Each concept can be coloured independently: by a scalar indicator, a
% per-point RGB matrix, or a fixed colour.

% Colour by the first objective value (default colormap)
ld.colorBy(c1, pf1(:,1));

% Colour by the second objective value with a custom colormap
ld.colorBy(c2, pf2(:,2), 'colormap', 'hot');
% Colour by the third objective value with a custom colormap, adding label
ld.colorBy(c3, pf3(:,1), 'colormap', 'cool','label','c3\_f1');

% Fixed colour (single RGB triplet applies to all points of a concept)
ld.colorBy(c1, [1 0.5 0.1]);   % orange

%% 8. Synchronisation — switching norms and external indicators
%
% The Y-axis can be any p-norm or an arbitrary external quality indicator.

% --- p-norm variants (applied to all concepts simultaneously) ---
ld.syncByNorm(1);
ld.setSyncLabel('L1 norm');

ld.syncByNorm(inf);
ld.setSyncLabel('L\infty norm');

ld.syncByNorm(2);
ld.setSyncLabel('L2 norm');

% --- Custom normalisation bounds ---
% Override the automatic bounds (rows: [max; min], one column per objective).
myBounds = [120 20 120 20;
              5  1   5  1];
ld.syncByNorm(2, myBounds);
ld.setSyncLabel('L2 norm (custom bounds)');

% Inspect current bounds and norm:
ld.globalBounds
ld.globalNorm

% Restore automatic bounds and recompute sync:
ld.resetBounds();

% Restore automatic bounds and switch norm at the same time:
ld.resetBounds();
ld.syncByNorm(1);

% --- External quality indicator ---
% Any external scalar per solution can drive the Y-axis.
% One vector per concept, passed as a cell array.
QI_pid = rand(c1.nind, 1);
QI_gpc = rand(c2.nind, 1);
QI_mpc = rand(c3.nind, 1);
ld.syncBy({QI_pid, QI_gpc, QI_mpc});
ld.setSyncLabel('Quality Indicator');

%% 9. Point-selection callbacks
%
% A function handle registered with onSelect is called every time a point
% is clicked in any figure. Different callbacks can be assigned per concept.

ld.onSelect(c1, @printPointInfo);   % print details for PID points
% ld.onSelect(c2, @myGPCCallback);  % different callback for GPC

ld.clearCallbacks(c1);              % remove callback for c1
% ld.clearCallbacks();              % remove all callbacks

%% 10. Export a selection to a new Concept
%
% After selecting points interactively (click or drag), export them.
% Uncomment after making a selection in the figures.

% subset1 = ld.exportSelection(c1, 'subset_PID');
% subset2 = ld.exportSelection(c2, 'subset_GPC');
% disp(subset1); disp(subset2)

%% 11. Marker sizes
%
% Fixed size (scalar), per-point vector, or derived from an objective value.

ld.setSize(c1, 80);                                         % fixed size
ld.setSize(c2, linspace(20, 200, c2.nind)');                % linearly increasing

% Scale size by first objective (larger = higher f1 value)
f3_min = min(pf3(:,1));  f3_max = max(pf3(:,1));
sizes_c3 = 20 + 250 * (pf3(:,1) - f3_min) / (f3_max - f3_min);
ld.setSize(c3, sizes_c3);

%% 12. Remove and re-add a concept
%
% Removing a concept updates bounds and sync for the remaining ones.

ld.removeConcept(c2);   % bounds and sync recalculated for c1 and c3

% Re-add when needed:
% ld.addConcept(c2);
