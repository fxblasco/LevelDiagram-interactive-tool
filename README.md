# LDTool — Level Diagram Toolbox

[![View on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://es.mathworks.com/matlabcentral/fileexchange/62224-interactive-tool-for-decision-making-in-multiobjective-optimization-with-level-diagrams)

Interactive MATLAB toolbox for visualizing and analysing multi-objective 
Pareto fronts using the **Level Diagram** technique.

> **New version actively developed on GitHub. A completely redesigned version with a cleaner architecture, improved robustness, and extended functionality.**  
> The original release is available on [MATLAB File Exchange (62224)](https://es.mathworks.com/matlabcentral/fileexchange/62224-interactive-tool-for-decision-making-in-multiobjective-optimization-with-level-diagrams).
>  Matlab filexchange entry is kept for reference only.

## Features

- Encapsulate any Pareto front + Pareto set in a `Concept` object
- Compare multiple concepts (e.g. PID vs GPC vs MPC) on shared normalized axes
- `addConcept` validates objective count and labels; label mismatches trigger an interactive dialog
- Adding a concept after `draw()` updates all figures automatically — no redraw needed
- Interactive point selection: click, rectangular drag, Shift for multi-selection
- Customizable colors (per-point colormap or RGB), sizes, and markers
- Synchronized Y-axis (`f_sync`) based on p-norm (1, 2, ∞) or any external indicator
- `syncBy` / `syncByNorm` reset the Y-axis label; use `setSyncLabel` to assign a descriptive name
- Y-axis label propagates to the Info Panel column header and CSV exports
- Concept visibility toggle (checkbox) hides the concept from all figures including the Info Panel
- Export selection to workspace or CSV
- Register callbacks triggered on point selection; `punto` struct includes `selectionIdx` and `selectionSize`

## Project structure

```
ldtool2026/
├── src/
│   └── matlab/                 # Source classes and utilities
│       ├── Concept.m                 # Pareto front/set encapsulation
│       ├── LevelDiagram.m            # Interactive Level Diagram visualization
│       ├── dominance.m               # Pareto front extraction (non-dominated filter)
│       ├── dominanceCone.m           # Dominance cone matrix from preference directions (Blasco 2021)
│       ├── asymmetricDist.m          # Asymmetric distance d = norm(max(y-x, 0))
│       ├── composedNorm.m            # Composed norm based on preference table
│       ├── drawPrefBands.m           # Draw preference sectors on LD figures
│       ├── gppl.m                    # Global Physical Programming index (piecewise-linear)
│       ├── plotGPPScale.m            # Plot GPP normalisation scale per objective
│       └── qualityIndicator.m        # Per-point Q indicator for Pareto front comparison (Reynoso-Meza 2013)
└── test/                       # Examples — see each subfolder for a README
    ├── comparingConcepts/            # Core LevelDiagram features: multiple concepts, coloring, sync
    └── ACCbenchmark/                 # Real-world example: 6-objective controller design
```

## Examples

Step-by-step examples are in the `test/` folder. Each subfolder contains a
`README.md` explaining the context and what each section demonstrates.

| Example | Description |
|---|---|
| [`test/comparingConcepts/`](test/comparingConcepts/README.md) | Core workflow: create concepts, draw, colour, sync, callbacks, export |
| [`test/ACCbenchmark/`](test/ACCbenchmark/README.md) | ACC benchmark: 6-objective PID design, GPP index, preference bands, control responses |

Add LDTool to the MATLAB path before running any example:

```matlab
addpath('src/matlab')
```

## Requirements

- MATLAB R2019b or later (uses `scatter` with `CData`, `uitable`, `uicontrol`)
- Compatible with Windows, macOS and Linux

## Reference

Blasco, X., Herrero, J.M., Sanchis, J., Martínez, M. (2008).  
*A new graphical visualization of n-dimensional Pareto front for decision-making 
in multiobjective optimization.*  
Information Sciences, 178(20), 3908–3924.

Reynoso-Meza, G., Blasco, X., Sanchis, J., Herrero, J.M. (2013).  
*Comparison of design concepts in multi-criteria decision-making using level diagrams.*  
Information Sciences, 221, 124–141.  
*(basis for `qualityIndicator.m`)*
