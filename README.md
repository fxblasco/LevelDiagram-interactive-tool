# LDTool — Level Diagram Toolbox

Interactive MATLAB toolbox for visualizing and analysing multi-objective 
Pareto fronts using the **Level Diagram** technique.

## Features

- Encapsulate any Pareto front + Pareto set in a `Concept` object
- Compare multiple concepts (e.g. PID vs GPC vs MPC) on shared normalized axes
- Interactive point selection: click, rectangular drag, Shift for multi-selection
- Customizable colors (per-point colormap or RGB), sizes, and markers
- Synchronized Y-axis (`f_sync`) based on p-norm (1, 2, ∞) or any external indicator
- Export selection to workspace or CSV
- Register callbacks triggered on point selection

## Project structure

```
ldtool2026/
├── src/
│   └── matlab/           # Source classes and utilities
│       ├── Concept.m           # Pareto front/set encapsulation
│       ├── LevelDiagram.m      # Interactive Level Diagram visualization
│       ├── asymmetricDist.m    # Asymmetric distance d = norm(max(y-x, 0))
│       ├── composedNorm.m      # Composed norm based on preference table
│       └── drawPrefBands.m     # Draw preference sectors on LD figures
└── test/                 # Examples and test scripts
    ├── pruebasLd.m
    └── verPunto.m
```

## Quick start

```matlab
addpath('src/matlab')

% 1. Create concepts
c1 = Concept(pf1, ps1, 'PID');
c1.labels.objectives = {'IAE', 'TV'};
c1.labels.parameters = {'Kp', 'Ti', 'Td'};

c2 = Concept(pf2, ps2, 'GPC');

% 2. Build Level Diagram
ld = LevelDiagram('comparison');
ld.addConcept(c1);
ld.addConcept(c2);
ld.draw();

% 3. Customize
ld.colorBy(c1, pf1(:,1));           % color by first objective
ld.syncByNorm(1);                   % switch to L1 norm
ld.onSelect(c1, @myCallback);       % callback on point click
```

## Requirements

- MATLAB R2019b or later (uses `scatter` with `CData`, `uitable`, `uicontrol`)

## Reference

Blasco, X., Herrero, J.M., Sanchis, J., Martínez, M. (2008).  
*A new graphical visualization of n-dimensional Pareto front for decision-making 
in multiobjective optimization.*  
Information Sciences, 178(20), 3908–3924.
