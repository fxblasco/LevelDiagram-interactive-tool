# LDControlPanel

Graphical control panel for a [`LevelDiagram`](LevelDiagram.md) object.
Provides a point-and-click interface to the most common Level Diagram operations without writing MATLAB commands.

```matlab
panel = ld.showPanel()        % recommended — via LevelDiagram
panel = LDControlPanel(ld)    % direct constructor
```

The panel opens docked to the right of the screen and stays in sync with the diagram via the **↺ Refresh** button at the bottom.

---

## Sections

### CONCEPTS

Add and manage concepts without writing code.

| Control | Description |
|---|---|
| List box | Shows all concepts currently in the diagram |
| PF / PS dropdowns | Select workspace matrices (click ↺ to refresh the list) |
| Name field | Name for the new concept (must be a valid MATLAB identifier) |
| **+ Add concept** | Creates a `Concept(PF, PS, name)` and adds it to the diagram |
| **▶ Draw** | Calls `ld.draw()` — creates or refreshes all figures |
| **✎ Edit labels…** | Opens a non-blocking dialog to assign objective and parameter label names to the selected concept. The dialog is non-blocking so you can switch to other windows to copy text |
| **✕ Remove selected** | Removes the highlighted concept from the diagram |
| **Clear all** | Removes every concept from the diagram |

**Edit labels dialog**

The dialog is pre-filled with the current labels. Enter comma-separated names matching the number of objectives or parameters exactly.

```
Objectives (3 — comma-separated):  IAE, TV, MS
Parameters (2 — comma-separated):  Kp, Ti
```

---

### Y-AXIS SYNC

Applies to all concepts simultaneously (global operation).

| Control | Description |
|---|---|
| Type | **Norm** or **Workspace** |
| p = | Exponent for the Lp norm (default 2; any positive value or Inf) |
| **Apply** | Calls `ld.syncByNorm(p)` or `ld.syncBy(values)` |
| **Reset bounds** | Calls `ld.resetBounds()` — restores automatic per-concept limits |

In **Workspace** mode, one dropdown per concept selects the vector to use as the sync variable. Click ↺ next to each row to reload the workspace list.

---

### ACTIVE CONCEPT

Dropdown that selects which concept is the target for the COLOR, SIZE AND MARKER, and CALLBACK sections below. Automatically updates when concepts are added or removed.

---

### COLOR

| Control | Description |
|---|---|
| **According to** dropdown | Selects the colour source (see table below) |
| ↺ | Refreshes the variable list from the workspace and the active concept |
| Colormap | MATLAB colormap name: parula, jet, hot, cool, gray, turbo, winter, summer, copper |
| Invert colormap | Flips the colormap direction |
| Colour preview | Live strip showing the selected colormap |
| **Pick color…** | Opens the system colour picker (uniform mode only) |
| RGB field | Type three space-separated values 0–1; updates the picker live (uniform mode only) |
| **Apply color** | Calls `ld.colorBy(concept, …)` with the selected settings |

**According to** options:

| Item | Mode | Description |
|---|---|---|
| Uniform (base color) | Fixed | All points share one colour (chosen via picker or RGB field) |
| ── ── | — | Separator |
| Concept objectives | Indicator | Maps one objective column to the colormap |
| Concept parameters | Indicator | Maps one parameter column to the colormap |
| Workspace | Indicator | Maps a workspace vector to the colormap |

Pressing **↺ Refresh panel from LD** (bottom button) reads back the colour currently applied to the diagram and updates the picker and RGB field automatically, including colours set from the command window with `ld.colorBy(c, [r g b])`.

---

### SIZE AND MARKER

| Control | Description |
|---|---|
| Variable dropdown | **Uniform** (slider) or a variable column / workspace vector |
| Slider + numeric field | Marker area in pts² when Uniform is selected |
| Range pts (min – max) | Scales variable values to this marker-size range |
| Marker dropdown | Circle, Square, Triangle, Diamond, Inverted triangle |

Changes are applied immediately when the slider moves or the variable changes. In variable mode, clicking Apply color is not required — size updates automatically when the dropdown selection changes.

---

### CALLBACK

| Control | Description |
|---|---|
| Current: | Shows the function handle(s) currently registered for the active concept |
| Text field | Type a function name (`myFn`) or an @-expression (`@(p) doSomething(p)`) |
| **…** | Browse for a `.m` file; the function name is filled in automatically and the file's folder is added to the path |
| **+ Assign** | Calls `ld.onSelect(concept, fn)` using `str2func` on the text field |
| **Remove callbacks** | Calls `ld.clearCallbacks(concept)` — removes all registered callbacks for the active concept |

---

### ↺ Refresh panel from LD

Synchronises the entire panel with the current state of the diagram. Use this after making changes from the MATLAB command window:

- Rebuilds the concept list and all variable dropdowns.
- Reads back the current colour and updates the picker / RGB field.
- Updates the **Current:** callback label.

---

## Notes

- The panel uses absolute pixel positions and has a fixed size (310 × 920 px). `Resize` is off.
- The panel is a standard `uifigure` — it can be closed and reopened with `ld.showPanel()`.
- All operations write through the `LevelDiagram` API, so the programmatic API remains fully functional alongside the panel.
- Label edits take effect in the COLOR and SIZE dropdowns immediately after the dialog is confirmed (the variable names shown in the "According to" dropdown update on the next Refresh or concept change).
