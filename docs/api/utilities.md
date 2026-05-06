# Utility functions

Standalone functions that complement `LevelDiagram` and `Concept`.

---

## `dominance`

Extracts the Pareto front (non-dominated solutions) from a set of objective function values and their associated decision variables.

```matlab
[x, y] = dominance(P, D)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `P` | `(N × nobj) double` | Objective function values. Each row is one solution. |
| `D` | `(N × nvar) double` | Decision variable values. Each row corresponds to the same solution as the same row of `P`. |

**Returns**

| Name | Type | Description |
|---|---|---|
| `x` | `(np × nobj) double` | Pareto front: non-dominated rows of `P`. |
| `y` | `(np × nvar) double` | Pareto set: rows of `D` corresponding to `x`. |

**Notes**

- A solution `i` is considered dominated if there exists another solution `j` that is no worse in all objectives and strictly better in at least one.
- Equal solutions (identical in all objectives) are treated as dominated: only one representative is kept.
- Internally selects between a fully-vectorized 3D-broadcast implementation (fast for moderate `N`) and an optimized loop-based implementation (memory-safe for large `N`). The switch is automatic based on `N² × nobj`.

**Example**

```matlab
% Generate a random set of candidate solutions
P = rand(500, 3);   % 500 solutions, 3 objectives (minimization)
D = rand(500, 5);   % 5 decision variables per solution

% Extract non-dominated solutions
[pf, ps] = dominance(P, D);

% Wrap in a Concept and visualise
c = Concept(pf, ps, 'MyFront');
ld = LevelDiagram('example');
ld.addConcept(c);
ld.draw();
```

---

## `composedNorm`

Computes the composed norm for each point of a Pareto front relative to a preference table.
The result is a single scalar per point that encodes both **which preference hypercube** the point belongs to and **how far** it is from the preferred vertex — making it suitable as a `syncBy` indicator.

```matlab
[dn, offsets] = composedNorm(pf, pref)
[dn, offsets] = composedNorm(pf, pref, bounds)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `pf` | `(np × nobj) double` | Pareto front in original objective units |
| `pref` | `(nobj × nI) double` | Preference table. Each column is one hypercube vertex. Column 1 = most preferred, column `nI` = least preferred. |
| `bounds` | `(2 × nobj) double` | *(optional)* Normalisation bounds `[max; min]`, same format as `ld.globalBounds`. If omitted, raw objective values are used (no normalisation). |

**Returns**

| Name | Type | Description |
|---|---|---|
| `dn` | `(np × 1) double` | Composed norm value per point. Consistent with the Level Diagram Y-axis when `bounds` is provided. |
| `offsets` | `(nI × 1) double` | Y-axis offset for each preference band (`offsets(1) = 0`). Pass to [`drawPrefBands`](#drawprefbands). |

**Workflow**

```matlab
pref = [0.3 0.6;   % objective 1: prefer <0.3, tolerate <0.6
        0.4 0.7];  % objective 2: prefer <0.4, tolerate <0.7

[dn, offsets] = composedNorm(c1.objectives, pref, ld.globalBounds);
ld.syncBy({dn});

figObj = findobj(groot, 'Type', 'figure', 'Name', 'Objectives - myLD');
figPar = findobj(groot, 'Type', 'figure', 'Name', 'Parameters - PID');
drawPrefBands(figObj, 'obj', pref, offsets);
drawPrefBands(figPar, 'par', offsets);
```

**Algorithm**

Each point is assigned to the innermost hypercube `x` (from most to least preferred) such that the point is **not dominated** by vertex `x`. The composed norm for that point is:

```
dn(i) = norm(max(pf_norm(i,:) - pref_norm(:,x)', 0)) + offsets(x)
```

where `offsets(x) = sum of max distances within each preceding band`.

---

## `drawPrefBands`

Overlays preference bands on an existing Level Diagram figure synchronized by composedNorm.
Must be called **after** `ld.draw()`, `composedNorm()` and `ld.syncBy(...)`.

```matlab
drawPrefBands(fig, 'obj', pref, offsets)   % Objectives figure
drawPrefBands(fig, 'par', offsets)          % Parameters figure
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `fig` | `figure handle` | Target figure (Objectives or Parameters) |
| `mode` | `'obj'` \| `'par'` | Drawing mode (see below) |

**Mode `'obj'` — staircase sectors on the Objectives figure**

Each objective axis receives a staircase shading where lighter grey = more preferred region.

Additional arguments:

| Name | Type | Description |
|---|---|---|
| `pref` | `(nobj × nI) double` | Preference table (same as passed to `composedNorm`) |
| `offsets` | `(nI × 1) double` | Y-axis offsets from `composedNorm` |

**Mode `'par'` — horizontal bands on a Parameters figure**

All parameter axes receive the same horizontal band shading, partitioned by the Y-axis offsets.

Additional argument:

| Name | Type | Description |
|---|---|---|
| `offsets` | `(nI × 1) double` | Y-axis offsets from `composedNorm` |

**Notes**

- Bands are drawn with `FaceAlpha = 0.35` and tagged `'PrefBand'` so they can be found with `findobj(ax, 'Tag', 'PrefBand')`.
- Scatter points are brought to the front automatically after drawing the bands.
- Bands do **not** update automatically if the Y-axis zoom changes; call `drawPrefBands` again if needed.

**Example**

```matlab
[dn, offsets] = composedNorm(c1.objectives, pref, ld.globalBounds);
ld.syncBy({dn});

figObj = findobj(groot, 'Type', 'figure', 'Name', 'Objectives - myLD');
figPar = findobj(groot, 'Type', 'figure', 'Name', 'Parameters - PID');

drawPrefBands(figObj, 'obj', pref, offsets);
drawPrefBands(figPar, 'par', offsets);
```

---

## `asymmetricDist`

Asymmetric distance measuring how much point `y` must move component-wise to dominate point `x`.

```
d = norm(max(y - x, 0))
```

Zero means `x` already dominates `y` (or they are equal).

```matlab
d = asymmetricDist(x, y)
```

**Arguments**

| Case | `x` shape | `y` shape | `d` shape |
|---|---|---|---|
| Point to point | `(1 × p)` | `(1 × p)` | scalar |
| Front to point | `(n × p)` | `(1 × p)` | `(n × 1)` |
| Point to front | `(1 × p)` | `(n × p)` | `(n × 1)` |

Both inputs must have the same number of columns (`p`). At most one of them can be a matrix.

**Example**

```matlab
% Distance from every point in the Pareto front to the ideal point
ideal = min(c1.objectives);
d = asymmetricDist(c1.objectives, ideal);

% Use as a sync indicator
ld.syncBy({d});
```
