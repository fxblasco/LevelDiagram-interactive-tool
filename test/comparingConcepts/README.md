# Comparing Concepts Example

Step-by-step demonstration of the core **LevelDiagram** features when working
with multiple Pareto fronts simultaneously.

> **Note:** All objective and parameter values are randomly generated.
> The controller names (PID, GPC, MPC) are illustrative only and do not
> represent a real control design problem.

## Files

| File | Description |
|---|---|
| `comparingConceptsExample.m` | Main script — run section by section with Ctrl+Enter |
| `printPointInfo.m` | `onSelect` callback: prints the selected point's details to the console |

## What this example demonstrates

### Section 1 — Generating Pareto fronts with `dominance`

Random candidate solutions are generated for three controller families.
[`dominance()`](../../src/matlab/dominance.m) filters out dominated solutions,
producing proper Pareto fronts and sets even though the data is synthetic.
This illustrates the typical pre-processing step before passing data to LDTool.

### Section 2 — Creating `Concept` objects

Each `Concept` wraps a Pareto front (objectives matrix) and its Pareto set
(parameters matrix) together with a name and optional axis labels.
Labels propagate automatically to figure axes and the Info Panel.

### Section 3 — Building the Level Diagram

`LevelDiagram` accepts multiple concepts. Global normalisation bounds are
computed automatically and **updated every time a new concept is added**,
so all concepts are always shown on the same normalised scale.

### Section 4 — Drawing

`ld.draw()` opens three figures:

| Figure | Contents |
|---|---|
| Objectives | One subplot per objective; Y-axis = sync value |
| Parameters (per concept) | One subplot per parameter; Y-axis = sync value |
| Info Panel | Details of the currently selected point |

### Section 5 — Sync-axis label

`setSyncLabel` sets the Y-axis label on every subplot and in the Info Panel
column header. Useful to indicate the current synchronisation criterion.

### Section 6 — Per-concept markers

Each concept can use a different marker shape (`o`, `s`, `*`, etc.) to help
distinguish overlapping point clouds visually.

### Section 7 — Colour coding

Three colour modes are demonstrated:

| Mode | Call | Description |
|---|---|---|
| Scalar indicator | `colorBy(c, vector)` | Maps values to the default colormap |
| Custom colormap | `colorBy(c, vector, 'colormap', 'hot')` | Any named MATLAB colormap |
| Fixed colour | `colorBy(c, [r g b])` | Uniform colour for all points of a concept |

### Section 8 — Synchronisation

The Y-axis value (sync) determines the vertical position of every point.
Three synchronisation strategies are shown:

| Strategy | Call | Notes |
|---|---|---|
| p-norm | `syncByNorm(p)` | p = 1, 2, Inf. Applied to all concepts simultaneously using global bounds |
| Custom bounds | `syncByNorm(p, bounds)` | Override automatic bounds. `resetBounds()` restores them |
| External indicator | `syncBy({v1, v2, v3})` | Any scalar per solution — one cell per concept |

`globalBounds` and `globalNorm` can be inspected at any time.

### Section 9 — Point-selection callbacks

`onSelect` registers a function that is called every time a point is clicked
or a rectangular selection is made. Different callbacks can be assigned to
different concepts. `clearCallbacks` removes them.

The `printPointInfo` callback prints concept name, index, objectives,
parameters and sync value to the MATLAB console.

### Section 10 — Exporting a selection

After selecting points interactively, `exportSelection` packages them into a
new `Concept` object that can be inspected, saved, or added back to the diagram.

### Section 11 — Marker sizes

Point size can be:
- **Uniform** — a single scalar applied to all points of a concept.
- **Per-point vector** — e.g. linearly scaled or derived from an objective value,
  making the size encode an additional dimension of information.

### Section 12 — Removing a concept

`removeConcept` removes a concept from the diagram, closes its Parameters
figure, and recalculates global bounds and sync values for the remaining
concepts automatically.

## Requirements

MATLAB R2019b or later. LDTool on the MATLAB path:

```matlab
addpath('../../src/matlab')
```
