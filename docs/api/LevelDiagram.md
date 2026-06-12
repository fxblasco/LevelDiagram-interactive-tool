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

If `draw()` has already been called, the new concept is added to the existing figures immediately: a new scatter series appears in the Objectives figure, a new Parameters figure is opened, and the Info Panel and checkboxes are rebuilt.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` | Object with a non-empty, unique `name` |

**Validation**

When a second or later concept is added, the following checks are applied against the first concept already in the diagram:

| Check | Behaviour on failure |
|---|---|
| Same number of objectives (`pfdim`) | Hard error — concept is not added |
| Same objective labels (position by position) | Interactive `questdlg` with three options |

Label-mismatch dialog options:

| Option | Effect |
|---|---|
| **Keep current** | New concept's labels are updated to match the existing ones |
| **Use new** | All existing concepts' labels (and axis titles) are updated to the new ones |
| **Cancel** | Concept is not added; diagram is unchanged |

**Example**

```matlab
ld.addConcept(c1);
ld.addConcept(c2);   % globalBounds now covers both c1 and c2
ld.draw();
ld.addConcept(c3);   % figures update automatically — no need to call draw() again
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

!!! note
    Calling `syncByNorm` resets `syncLabel` to `'f_{sync}'` and refreshes all Y-axis labels and the Info Panel column header. Call `setSyncLabel` afterwards to set a descriptive label.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `p` | `double` | Norm order: `1`, `2`, `Inf`, or any positive value |
| `bounds` | `(2 × nobj) double` | *(optional)* Custom bounds `[max; min]`; stored as `globalBounds` |

**Example**

```matlab
ld.syncByNorm(2);                    % L2 norm (default after addConcept)
ld.syncByNorm(1);  ld.setSyncLabel('L1 norm');
ld.syncByNorm(Inf); ld.setSyncLabel('Chebyshev norm');
ld.syncByNorm(2, myBounds);
```

---

### `syncBy`

```matlab
ld.syncBy(values)
```

Sets the Y-axis from an external quality indicator instead of a norm. Useful with [`composedNorm`](utilities.md#composednorm) or any user-defined indicator.

!!! note
    Calling `syncBy` resets `syncLabel` to `'f_{sync}'` and refreshes all Y-axis labels and the Info Panel column header. Call `setSyncLabel` afterwards to set a descriptive label.

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

Changes the Y-axis label in all open figures, in the last column header of the Info Panel, and in CSV exports. Equivalent to setting `ld.syncLabel = label` directly.

This is the intended way to assign a descriptive label after calling `syncBy` or `syncByNorm`, both of which reset the label to `'f_{sync}'`.

**Example**

```matlab
ld.syncByNorm(1);
ld.setSyncLabel('L1 norm');

[dn, ~] = composedNorm(c1.objectives, pref, ld.globalBounds);
ld.syncBy({dn});
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

## Control panel

### `showPanel`

```matlab
panel = ld.showPanel()
```

Opens the [`LDControlPanel`](LDControlPanel.md) graphical interface docked to the right of the screen.
Returns the `LDControlPanel` handle so it can be kept alive in the workspace.

**Example**

```matlab
ld = LevelDiagram('comparison');
ld.addConcept(c1);
ld.draw();
panel = ld.showPanel();   % open GUI alongside the diagram
```

---

## Concept introspection

### `getConceptNames`

```matlab
names = ld.getConceptNames()
```

Returns a `cell array` of `char` with the name of every concept, in insertion order.

---

### `getConceptByName`

```matlab
concept = ld.getConceptByName(name)
```

Returns the `Concept` object whose `name` matches the given string.
Raises an error if no matching concept is found.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `name` | `char` | Exact concept name (case-sensitive) |

---

### `getConceptCallbacks`

```matlab
fns = ld.getConceptCallbacks(concept)
```

Returns a `cell array` of function handles registered for `concept` via `onSelect`.
Returns an empty cell `{}` if no callbacks are registered.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Concept object or its numeric index |

---

### `getConceptColorData`

```matlab
colData = ld.getConceptColorData(concept)
```

Returns the current colour matrix `(nind × 3)` applied to `concept`.
For a fixed colour set with `ld.colorBy(c, [r g b])`, all rows are identical.
Useful for reading back the current colour into the control panel or for inspection.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Concept object or its numeric index |

---

### `setConceptLabels`

```matlab
ld.setConceptLabels(concept, objLabels)
ld.setConceptLabels(concept, objLabels, parLabels)
```

Sets objective and/or parameter labels for a concept.
Validates that the number of labels matches the concept dimensions.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Concept object or its numeric index |
| `objLabels` | `cell of char` | Label for each objective (length must equal `pfdim`) |
| `parLabels` | `cell of char` | *(optional)* Label for each parameter (length must equal `psdim`) |

**Example**

```matlab
ld.setConceptLabels(c1, {'IAE','TV','MS'}, {'Kp','Ti','Td'});
```

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

### `selectPoints`

```matlab
ld.selectPoints(concept, indices)
```

Selects points of a concept programmatically by numeric index, updating highlights and the Info Panel — equivalent to clicking points interactively.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Source concept object or its numeric index |
| `indices` | `(k × 1) int` | Row indices into `concept.parameters` / `concept.objectives` |

**Example**

```matlab
% Select all points where x8 > 0 and x10 <= 0.5
idx = find(c1.parameters(:,8) > 0 & c1.parameters(:,10) <= 0.5);
ld.selectPoints(c1, idx)

% Combine with deletePoints or exportSelection afterwards
```

!!! note
    After calling `deletePoints`, the workspace variable (`c1`) is updated automatically. Always build `indices` from the current concept data to avoid stale references.

---

### `deletePoints`

```matlab
ld.deletePoints(concept, indices)
ld.deletePoints(concept, indices, varName)
```

Removes points from a concept by index, saves them as a new `Concept` in the base workspace, and updates all figures and the Info Panel. Any workspace variable whose `name` matches the concept is updated automatically to stay in sync.

If `varName` is omitted an `inputdlg` is shown. If `indices` is empty, the call is silently ignored. If `indices` covers all points, a warning dialog is shown and nothing is deleted.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Source concept object or its numeric index |
| `indices` | `(k × 1) int` | Row indices of the points to remove |
| `varName` | `char` | *(optional)* Workspace variable name for the deleted points |

**Example**

```matlab
% Delete points where x1 > 0, save as 'removed_x1'
idx = find(c1.parameters(:,1) > 0);
ld.deletePoints(c1, idx, 'removed_x1')

% c1 is now updated automatically — subsequent calls use the reduced dataset
idx2 = find(c1.parameters(:,2) > 0);
ld.deletePoints(c1, idx2, 'removed_x2')
```

The **"Delete sel."** button in the Info Panel performs the same operation on the current interactive selection (shows the name dialog before deleting).

---

### `deleteSelection`

```matlab
ld.deleteSelection(concept)
```

Programmatic equivalent of the **"Delete sel."** button: removes the points currently selected for `concept`, shows the name dialog to save the deleted points to the workspace, and updates all figures.

**Arguments**

| Name | Type | Description |
|---|---|---|
| `concept` | `Concept` or `int` | Concept object or its numeric index |

**Example**

```matlab
ld.selectPoints(c1, find(c1.parameters(:,1) > 0.5));
ld.deleteSelection(c1);   % same as clicking "Delete sel." in the Info Panel
```

---

## Callbacks

### `onSelect`

```matlab
ld.onSelect(concept, callback)
```

Registers a function to be called when points of `concept` are executed via the **"Run"** button in the Info Panel.

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
