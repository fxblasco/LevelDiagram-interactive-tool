# Utility functions

Standalone functions that complement `LevelDiagram` and `Concept`.

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

Overlays preference bands on an existing Level Diagram figure.
Must be called **after** `ld.draw()` and `ld.syncBy(...)`.

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
