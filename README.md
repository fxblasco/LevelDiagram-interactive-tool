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
│   └── matlab/       # Source classes
│       ├── Concept.m
│       └── LevelDiagram.m
└── test/             # Examples and test scripts
    ├── examples....
```

## Requirements

- MATLAB R2019b or later (uses `scatter` with `CData`, `uitable`, `uicontrol`)

## Reference

Blasco, X., Herrero, J.M., Sanchis, J., Martínez, M. (2008).  
*A new graphical visualization of n-dimensional Pareto front for decision-making 
in multiobjective optimization.*  
Information Sciences, 178(20), 3908–3924.
