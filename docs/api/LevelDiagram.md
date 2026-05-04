# LevelDiagram

Interactive Level Diagram visualisation for one or more Pareto concepts.
Inherits from `handle` so every change to properties is immediately reflected in all references to the object.

```matlab
ld = LevelDiagram('myLD')
ld.addConcept(c1)
ld.draw()
```

---

## Properties

### Read / write

| Property | Type | Default | Description |
|---|---|---|---|
| `name` | `char` | `''` | Name of this Level Diagram (used in figure titles) |
| `syncLabel` | `char` | `'f_{sync}'` | Y-axis label shown in all figures; updating it live re-labels open axes |

### Read-only

| Property | Type | Description |
|---|---|---|
| `globalBounds` | `(2 × nobj) double` | Shared normalisation bounds `[max; min]` across all added concepts |
| `globalNorm` | `double` | Current p-norm value (1, 2, Inf, …) used for sync computation |

---

## Constructor

```matlab
ld = LevelDiagram()
ld = LevelDiagram(name)
```

**Arguments**

| Name | Type | Description |
|---|---|---|
| `name` | `char` | *(optional)* Name of the Level Diagram |

**Example**

```matlab
ld = LevelDiagram('PID_vs_GPC');
```

---

## Concept management

### `addConcept`

```matlab
ld.addConcept(concept)
```

Adds a `Concept` to the diagram. Global bounds and the synchronisation values of **all** existing concepts are recomputed automatically with the current norm.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` | Object with a non-empty, unique `name` |

!!! note
    Call `draw()` after adding all concepts. Adding a concept after `draw()` requires calling `draw()` again or updating the axes manually.

**Example**

```matlab
ld.addConcept(c1);
ld.addConcept(c2);   % globalBounds now covers both c1 and c2
```

---

### `removeConcept`

```matlab
ld.removeConcept(concept)
```

Removes a concept and its associated graphics. Global bounds and sync of the remaining concepts are recomputed.

---

## Y-axis synchronisation

### `syncByNorm`

```matlab
ld.syncByNorm(p)
ld.syncByNorm(p, bounds)
```

Recomputes the sync axis for **all** concepts using the Lp norm. Normalisation is performed to `[0, 1]` using `globalBounds` before applying the norm.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `p` | `double` | Norm order: `1`, `2`, `Inf`, or any positive value |
| `bounds` | `(2 × nobj) double` | *(optional)* Custom bounds `[max; min]`; stored as `globalBounds` |

**Example**

```matlab
ld.syncByNorm(2);          % L2 norm (default after addConcept)
ld.syncByNorm(1);          % L1 norm
ld.syncByNorm(Inf);        % Chebyshev norm
ld.syncByNorm(2, myBounds);
```

---

### `syncBy`

```matlab
ld.syncBy(values)
```

Sets the Y-axis from an external quality indicator instead of a norm. Useful with [`composedNorm`](utilities.md#composednorm) or any user-defined indicator.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `values` | `cell array` | One numeric column vector `(nind × 1)` per concept, in the same order as `addConcept` calls |

**Example**

```matlab
[dn1, offsets] = composedNorm(c1.objectives, pref, ld.globalBounds);
[dn2, ~]       = composedNorm(c2.objectives, pref, ld.globalBounds);
ld.syncBy({dn1, dn2});
```

---

### `resetBounds`

```matlab
ld.resetBounds()
```

Resets `globalBounds` to the automatic values (max of all `maxpf`, min of all `minpf`) and recomputes sync with the current norm.

---

### `setSyncLabel`

```matlab
ld.setSyncLabel(label)
```

Changes the Y-axis label in all open figures. Equivalent to setting `ld.syncLabel = label` directly.

**Example**

```matlab
ld.setSyncLabel('Composed norm');
```

---

## Appearance

### `colorBy`

```matlab
ld.colorBy(concept, input)
ld.colorBy(concept, input, Name, Value, ...)
```

Assigns colours to the points of one concept. Three input modes are supported:

| `input` | Mode | Description |
|---|---|---|
| `(nind × 1)` vector | Indicator | Maps values to a colormap; low values painted last (on top) |
| `(nind × 3)` matrix | RGB per point | One `[r g b]` row per solution |
| `[r g b]` row vector | Fixed colour | Same colour for all points |

**Name-Value options** *(indicator mode only)*

| Option | Type | Default | Description |
|---|---|---|---|
| `'colormap'` | `char` | `'parula'` | Any MATLAB colormap name |
| `'reverseColor'` | `logical` | `false` | Flip the colormap colours |
| `'reverseInd'` | `logical` | `false` | `true` → high indicator value painted on top |
| `'clim'` | `[min max]` | auto | Fixed colour axis limits |
| `'label'` | `char` | `''` | Colorbar label in the parameters figure |

**Examples**

```matlab
ld.colorBy(c1, pf1(:,1));                             % colour by objective 1
ld.colorBy(c1, pf1(:,1), 'colormap', 'hot');          % hot colormap
ld.colorBy(c1, pf1(:,1), 'reverseInd', true);         % high = best = on top
ld.colorBy(c1, pf1(:,1), 'label', 'IAE');             % colorbar label
ld.colorBy(c1, myRGBMatrix);                           % per-point RGB
ld.colorBy(c1, [0.2 0.6 0.9]);                        % fixed blue
```

---

### `setSize`

```matlab
ld.setSize(concept, sizes)
```

Sets the scatter marker size(s) for one concept.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `sizes` | `scalar` or `(nind × 1)` | Marker area in points² (same unit as MATLAB `scatter`) |

**Example**

```matlab
ld.setSize(c1, 60);                  % all points same size
ld.setSize(c1, normQI * 80 + 10);   % size proportional to quality
```

---

### `setMarker`

```matlab
ld.setMarker(concept, marker)
```

Changes the marker style for one concept.

**Arguments**

| `marker` | Shape |
|---|---|
| `'o'` | Circle (default) |
| `'s'` | Square |
| `'^'` | Triangle up |
| `'v'` | Triangle down |
| `'d'` | Diamond |
| `'p'` | Pentagram |
| `'h'` | Hexagram |
| `'+'` | Plus |
| `'*'` | Asterisk |

---

## Drawing

### `draw`

```matlab
ld.draw()
```

Creates all figures: one shared **Objectives** figure (all concepts overlaid), one **Parameters** figure per concept, and one **Info Panel**.

!!! warning
    Requires at least one concept to have been added with `addConcept`.

---

## Selection and export

### `exportSelection`

```matlab
subset = ld.exportSelection(concept)
subset = ld.exportSelection(concept, name)
```

Returns a new `Concept` containing only the currently selected points. The `labels` struct is copied from the source concept.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Source concept object or its numeric index |
| `name` | `char` | *(optional)* Name for the new subset concept |

**Example**

```matlab
best = ld.exportSelection(c1, 'best_PID');
```

---

### `clearSelection`

```matlab
ld.clearSelection()
```

Clears all highlighted points and resets the Info Panel.

---

## Callbacks

### `onSelect`

```matlab
ld.onSelect(concept, callback)
```

Registers a function to be called when points of `concept` are executed via the **"Ejecutar"** button in the Info Panel.

**Callback signature**

```matlab
function myCallback(punto)
%   punto.concept       - concept name (char)
%   punto.index         - solution index (integer)
%   punto.objectives    - objective values (1 × pfdim)
%   punto.parameters    - parameter values (1 × psdim)
%   punto.sync          - Y-axis value
%   punto.labels        - labels struct
%   punto.selectionIdx  - position within current selection (1-based)
%   punto.selectionSize - total number of selected points
end
```

**Example**

```matlab
ld.onSelect(c1, @(p) simular(p.parameters));
```

---

### `clearCallbacks`

```matlab
ld.clearCallbacks()           % remove all callbacks
ld.clearCallbacks(concept)    % remove only callbacks for one concept
```

---

## Utilities

### `refreshAxes`

```matlab
ld.refreshAxes()
```

Forces a refresh of the Y-axis limits on all open axes. Useful after manual changes to `syncValues`.

### `disp`

```matlab
ld.disp()   % or just: ld
```

Prints a summary: name, number of concepts, and solution count per concept.
