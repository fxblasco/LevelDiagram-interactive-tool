# LDControlPanel

Graphical control panel for a [`LevelDiagram`](LevelDiagram.md) object.
Provides a point-and-click interface to the most common Level Diagram operations without writing MATLAB commands.

```matlab
panel = ld.showPanel()        % recommended — via LevelDiagram
panel = LDControlPanel(ld)    % direct constructor
```

The panel opens centred on screen (360 × 718 px, fixed size). The `ld` object and any concepts created from the panel are automatically exported to the MATLAB base workspace so you can use both the panel and the command line interchangeably.

---

## Sections

### CONCEPTS

Add and manage concepts. New concepts created here are automatically assigned to a workspace variable with the same name as the concept, so they can be used immediately from the command line.

| Control | Description |
|---|---|
| List box | Shows all concepts currently in the diagram |
| Name field | Name for the new concept (must be a valid MATLAB identifier) |
| PF / PS dropdowns | Select workspace matrices (click ↺ to refresh the list) |
| WS dropdown | Select an existing `Concept` object from the base workspace to load it directly |
| ↺ (WS row) | Refreshes the list of `Concept` objects available in the workspace |
| **+ Add concept** | If a WS concept is selected: loads it into the diagram. Otherwise: creates `Concept(PF, PS, name)`, adds it to the diagram, and exports it to the workspace |
| **▶ Draw** | Calls `ld.draw()` — closes any existing figures and opens fresh ones |
| **✎ Edit labels…** | Opens a non-blocking dialog to assign objective and parameter label names to the selected concept |
| **✕ Remove selected** | Removes the highlighted concept from the diagram and clears it from the workspace |
| **Clear all** | Shows a confirmation dialog, then removes every concept from the diagram, closes all LD figures, and clears the workspace variables |

**Edit labels dialog**

Pre-filled with current labels. Enter comma-separated names matching the number of objectives or parameters exactly.

```
Objectives (3 — comma-separated):  IAE, TV, MS
Parameters (2 — comma-separated):  Kp, Ti
```

**Bidirectional workspace access**

```matlab
% Create from panel → available immediately in command line
idx = find(c1.parameters(:, 3) > 0);
ld.selectPoints(c1, idx)

% Create from command line → load via WS dropdown in panel
c2 = Concept(PF2, PS2, 'GPC');
% Then: refresh WS ↺ in panel and select c2 from the WS dropdown
```

---

### Y-AXIS SYNC

Applies to all concepts simultaneously (global operation).

| Control | Description |
|---|---|
| Type | **Norm** — synchronise by Lp norm; **Workspace** — use one external vector per concept |
| p = | Exponent for the Lp norm (default 2; any positive value or Inf) |
| **Apply** | Calls `ld.syncByNorm(p)` (Norm mode) or `ld.syncBy(values)` (Workspace mode) |
| **Reset bounds** | Calls `ld.resetBounds()` — restores automatic per-concept limits |

In **Workspace** mode, one row per concept appears showing a dropdown to select the vector from the workspace. Click ↺ next to each row to reload the workspace list. The section height adjusts automatically to fit all rows.

---

### ACTIVE CONCEPT

Dropdown (highlighted in blue) that selects which concept is the target for the four operation tabs below. Updates automatically when concepts are added or removed.

The four tabs share the space; only one set of controls is visible at a time.

---

### Tab: Selection

Filter and select points of the active concept by condition, or pass an index vector from the workspace.

| Control | Description |
|---|---|
| **Objectives / Parameters** | Choose which data matrix to filter on |
| Variable dropdown | Column label to apply the condition to (click ↺ to refresh) |
| Operator | `>`, `<`, `>=`, `<=`, `==`, `~=` |
| Value field | Numeric threshold |
| **Select** | Replaces the current selection with all points matching the condition — calls `ld.selectPoints(c, idx)` |
| **+ Add to sel.** | Adds matching points to the existing selection — calls `ld.addToSelection(c, idx)` |
| **Clear selection** | Calls `ld.clearSelection()` |
| WS idx dropdown | Numeric index vector already computed in the workspace (click ↺ to refresh) |
| **Use** | Selects points using the chosen workspace index vector |

**Example workflow**

```matlab
% From command line: build a complex index
idx = find(c1.parameters(:,14) > 0 & c1.objectives(:,2) < 0.5);
% Then: refresh WS idx ↺ in panel, pick the variable, click Use
```

---

### Tab: Color

| Control | Description |
|---|---|
| **According to** dropdown | Selects the colour source (see table below) |
| ↺ | Refreshes the variable list from the workspace and the active concept |
| Colormap | MATLAB colormap name: parula, jet, hot, cool, gray, turbo, winter, summer, copper |
| Invert colormap | Flips the colormap direction |
| Colour preview | Live strip showing the selected colormap |
| **Pick color…** | Opens the system colour picker (uniform mode only) |
| RGB field | Type three space-separated values 0–1 (uniform mode only) |
| **Apply color** | Calls `ld.colorBy(concept, …)` with the selected settings |

**According to** options:

| Item | Mode | Description |
|---|---|---|
| Uniform (base color) | Fixed | All points share one colour |
| Concept objectives | Indicator | Maps one objective column to the colormap |
| Concept parameters | Indicator | Maps one parameter column to the colormap |
| Workspace | Indicator | Maps a workspace vector to the colormap |

---

### Tab: Size & Marker

| Control | Description |
|---|---|
| Variable dropdown | **Uniform** (slider) or a variable column / workspace vector |
| Slider + numeric field | Marker area in pts² when Uniform is selected (range 1–200) |
| Range pts (min – max) | Scales variable values to this marker-size range |
| Marker dropdown | Circle, Square, Triangle, Diamond, Inverted triangle |

Changes are applied immediately when the slider moves or the variable selection changes.

---

### Tab: Callback

| Control | Description |
|---|---|
| Current: | Shows the function handle(s) currently registered for the active concept |
| Text field | Type a function name (`myFn`) or an @-expression (`@(p) doSomething(p)`) |
| **…** | Browse for a `.m` file; the name is filled in and the folder added to the path |
| **+ Assign** | Calls `ld.onSelect(concept, fn)` using `str2func` on the text field |
| **Remove callbacks** | Calls `ld.clearCallbacks(concept)` — removes all registered callbacks |

---

### ↺ Refresh panel from LD

Synchronises the entire panel with the current state of the diagram. Use after making changes from the MATLAB command window:

- Rebuilds the concept list and all variable dropdowns.
- Reads back the current colour and updates the picker / RGB field.
- Updates the **Current:** callback label.
- Rebuilds the Y-AXIS SYNC workspace rows.

---

## Notes

- The panel is a `uifigure` (360 × 718 px, `Resize` off), centred on screen at startup.
- The panel can be closed and reopened with `ld.showPanel()`.
- All operations write through the `LevelDiagram` API — the programmatic API remains fully functional alongside the panel.
- `ld` itself is assigned to the workspace variable whose name matches `ld.name` (or `ld` if the name is empty) when `showPanel` is called from the command line.
