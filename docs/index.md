# LDTool — Level Diagram Toolbox

Interactive MATLAB toolbox for visualising and analysing multi-objective Pareto fronts using the **Level Diagram** technique.

## Installation

```matlab
addpath('src/matlab')
```

## Quick start

```matlab
% 1. Wrap Pareto data in Concept objects
c1 = Concept(pf1, ps1, 'PID');
c1.labels.objectives = {'IAE', 'TV'};
c1.labels.parameters = {'Kp', 'Ti', 'Td'};

c2 = Concept(pf2, ps2, 'GPC');

% 2. Build the Level Diagram
ld = LevelDiagram('comparison');
ld.addConcept(c1);
ld.addConcept(c2);
ld.draw();

% 3. Customise appearance
ld.colorBy(c1, pf1(:,1));        % colour by first objective
ld.syncByNorm(1);                % switch to L1 norm
ld.onSelect(c1, @myCallback);    % callback on point click
```

## Features

| Feature | Description |
|---|---|
| `Concept` | Encapsulates any Pareto front + Pareto set |
| Multiple concepts | Compare PID vs GPC vs MPC on shared normalised axes |
| Concept validation | `addConcept` checks objective count and labels; label mismatches show an interactive dialog |
| Live figure update | Adding a concept after `draw()` updates all figures automatically |
| Concept visibility | Checkbox in the Objectives figure hides a concept from all figures and the Info Panel |
| Interactive selection | Click a point, drag a rectangle, Shift for multi-selection |
| Colour / size / marker | Per-point colormap, RGB matrix, or fixed colour |
| Y-axis sync | p-norm (1, 2, ∞) or any external quality indicator via `syncBy` |
| `qualityIndicator` | Per-point Q indicator comparing two Pareto fronts (Reynoso-Meza 2013) |
| Sync label | `setSyncLabel` propagates to axes, Info Panel column header, and CSV exports |
| Preference bands | Overlay staircase sectors from a preference table |
| Export | Selection → new `Concept`, workspace variable, or CSV |
| Callbacks | Function triggered on each selected point; `punto` includes `selectionIdx` and `selectionSize` |

## Requirements

MATLAB R2019b or later (`scatter` with `CData`, `uitable`, `uicontrol`).

## Reference

Blasco, X., Herrero, J.M., Sanchis, J., Martínez, M. (2008).
*A new graphical visualization of n-dimensional Pareto front for decision-making in multiobjective optimization.*
Information Sciences, 178(20), 3908–3924.

Reynoso-Meza, G., Blasco, X., Sanchis, J., Herrero, J.M. (2013).
*Comparison of design concepts in multi-criteria decision-making using level diagrams.*
Information Sciences, 221, 124–141.
*(basis for `qualityIndicator.m`)*
