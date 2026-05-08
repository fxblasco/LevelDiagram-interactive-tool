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

## `gppl`

Global Physical Programming index using a piecewise-linear normalisation scale.
Aggregates multiple objectives into a single scalar that ranks Pareto-front solutions
according to class-range preferences defined by the decision maker.

Inspired by Messac (1996) Physical Programming; the piecewise-linear normalisation
follows [Reynoso-Meza et al. (2014)](https://doi.org/10.1016/j.asoc.2014.07.009).

```matlab
v              = gppl(J, pref)
[v, etiquetas] = gppl(J, pref, etiqPref)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `J` | `(ns × nobj) double` | Objective values. Each row is one solution. |
| `pref` | `(nobj × (nranges+1)) double` | Preference table (see below). |
| `etiqPref` | `(1 × nranges) or (1 × (nranges+1)) cell` | *(optional)* Range names, e.g. `{'HD','D','T','U','HU'}`. If `nranges` labels are given, the extrapolated range is labelled automatically as the last label with `'+'` appended. If `nranges+1` labels are given, the last one is used as-is. Required only when `etiquetas` is requested. |

**Preference table format**

Each row of `pref` defines the class-range boundaries for one objective:

| Column | Meaning |
|---|---|
| 1 | Lower bound of the most desirable range |
| 2 … nranges | Boundaries between consecutive ranges (D\|T, T\|I, …) |

No trailing `Inf` column is needed: the last range is extrapolated automatically
using the slope of the preceding range.

```matlab
pref = [0  1  3;    % J1: Desirable=[0,1],  Tolerable=(1,3],  Indesirable=(3,Inf)
        0  5  8;    % J2: Desirable=[0,5],  Tolerable=(5,8],  Indesirable=(8,Inf)
        0  5 15;    % J3: Desirable=[0,5],  Tolerable=(5,15], Indesirable=(15,Inf)
        0 12 25];   % J4: Desirable=[0,12], Tolerable=(12,25],Indesirable=(25,Inf)
```

**Returns**

| Name | Type | Description |
|---|---|---|
| `v` | `(ns × 1) double` | GPP index per solution. Lower is better. |
| `etiquetas` | `(ns × 1) cell` | Comma-separated class label per solution, e.g. `'HD,D,T,U,HD'`. Only computed when `etiqPref` is provided. |

**Notes**

- The normalised scale enforces the **OVO rule**: a balanced solution (all objectives
  in Tolerable) is always preferred over one with any objective in Indesirable, even
  if the rest are in Desirable.
- Values below `pref(i,1)` yield a negative contribution for objective `i`
  (interpreted as "better than the most desirable bound").
- The last range is extrapolated with a finite slope, so solutions in the indesirable
  region receive distinct, ordered penalties.

**Workflow with LevelDiagram**

```matlab
pref     = [-10 -0.01 -0.005 -0.001 -0.0005 -0.0001;
              0  0.85    0.9      1     1.5       2;
              0    14     20     30      35      40;
              0   0.5    0.9    1.2     1.4     1.5;
              0   0.5    0.7      1     1.5       2;
              0    10     11     15      20      25];
etiqPref = {'HD','D','T','U','HU'};

% GPP index only
v = gppl(c1.objectives, pref);

% GPP index + per-solution labels
[v, etiquetas] = gppl(c1.objectives, pref, etiqPref);

% Use as sync indicator in the Level Diagram
ld.syncBy({v});
ld.setSyncLabel('GPP index');
```

---

## `plotGPPScale`

Plots the piecewise-linear GPP normalisation function for each objective in a single-row figure.
Useful for verifying that the preference table produces the intended scale before using `gppl`.

```matlab
plotGPPScale(pref)
plotGPPScale(pref, etiqPref)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `pref` | `(nobj × (nranges+1)) double` | Preference table — same format as `gppl`. |
| `etiqPref` | `(1 × nranges) or (1 × (nranges+1)) cell` | *(optional)* Range labels. Same rules as `gppl`: `nranges` entries auto-appends `'+'` for the extrapolated range; `nranges+1` entries used as-is. Defaults to `{'R1','R2',…}`. |

Each subplot shows:

- Shaded background per class range (green → yellow → red by default)
- Dashed vertical markers at each boundary with `'RangeA|RangeB'` labels
- The GPP curve in black
- Filled dots at the preference boundary nodes

**Example**

```matlab
pref = [0  1  3;
        0  5  8];
plotGPPScale(pref, {'D', 'T', 'U'})
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
