# Concept

Container for a Pareto front and its corresponding Pareto set.

```matlab
c = Concept(pf, ps, 'PID')
c.labels.objectives = {'IAE', 'TV'};
c.labels.parameters = {'Kp', 'Ti', 'Td'};
```

---

## Properties

### Read / write

| Property | Type | Description |
|---|---|---|
| `name` | `char` | Concept name. Must be a valid MATLAB identifier (`isvarname`). |
| `labels` | `struct` | Axis labels. Fields: `labels.objectives` (cell, length `pfdim`) and `labels.parameters` (cell, length `psdim`). Defaults: `'f1','f2',…` and `'x1','x2',…`. |

### Read-only

| Property | Type | Description |
|---|---|---|
| `data` | `(nind × (pfdim+psdim)) double` | Raw data matrix `[pf ps]` |
| `nind` | `double` | Number of solutions |
| `pfdim` | `double` | Number of objectives |
| `psdim` | `double` | Number of parameters |

### Computed (dependent, read-only)

| Property | Type | Description |
|---|---|---|
| `objectives` | `(nind × pfdim)` | Pareto front columns |
| `parameters` | `(nind × psdim)` | Pareto set columns |
| `maxpf` | `(1 × pfdim)` | Column-wise maximum of `objectives` |
| `minpf` | `(1 × pfdim)` | Column-wise minimum of `objectives` |
| `maxps` | `(1 × psdim)` | Column-wise maximum of `parameters` |
| `minps` | `(1 × psdim)` | Column-wise minimum of `parameters` |

---

## Constructor

```matlab
c = Concept(pf, ps)
c = Concept(pf, ps, name)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `pf` | `(nind × pfdim) double` | Pareto front matrix. No NaN or Inf. |
| `ps` | `(nind × psdim) double` | Pareto set matrix. Same number of rows as `pf`. No NaN or Inf. |
| `name` | `char` | *(optional)* Concept name |

**Example**

```matlab
c = Concept(pfront, pset, 'PID');
c.labels.objectives = {'IAE', 'TV'};
c.labels.parameters = {'Kp', 'Ti', 'Td'};
```

---

## Methods

### `autoBounds`

```matlab
bounds = c.autoBounds()
```

Returns `[maxpf; minpf]` — the normalisation bounds derived from this concept's data alone.
Useful as a starting point before merging bounds across concepts.

**Returns** `(2 × pfdim) double`

---

### `mergeBounds`

```matlab
bounds = c1.mergeBounds(c2)
```

Combines the bounds of two concepts: `max` of the maxima and `min` of the minima, dimension-wise.
Both concepts must have the same `pfdim`.

**Returns** `(2 × pfdim) double`

**Example**

```matlab
bounds = c1.mergeBounds(c2);
% equivalent to what LevelDiagram computes automatically as globalBounds
```

---

### `extractSubset`

```matlab
subset = c.extractSubset(idx)
```

Creates a new `Concept` from a subset of solutions. Labels are copied from the parent.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `idx` | `integer vector` or `logical vector` | Indices or logical mask selecting the rows to keep |

**Returns** `Concept` — name is `'<parent_name>_subset'`

**Example**

```matlab
% After interactive selection in the Level Diagram:
sub = ld.exportSelection(c1, 'selected');

% Or directly with known indices:
sub = c1.extractSubset([3 7 12]);
sub = c1.extractSubset(c1.objectives(:,1) < 0.5);  % logical mask
```

---

## Static methods

### `Concept.mergeBoundsN`

```matlab
bounds = Concept.mergeBoundsN(c1, c2, c3, ...)
bounds = Concept.mergeBoundsN({c1, c2, c3, ...})
```

Combines the bounds of N concepts (N ≥ 2). All must have the same `pfdim`.
This is what `LevelDiagram` computes internally as `globalBounds`.

**Returns** `(2 × pfdim) double`

**Example**

```matlab
bounds = Concept.mergeBoundsN(c1, c2, c3);
% or equivalently:
bounds = Concept.mergeBoundsN({c1, c2, c3});
```

---

## Notes

- `Concept` does **not** inherit from `handle`: it has value semantics. Modifying a copy does not affect the original.
- After `extractSubset`, edit `subset.name` and `subset.labels` as needed before adding to a `LevelDiagram`.
