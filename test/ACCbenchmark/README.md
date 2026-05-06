# ACC Benchmark Example

Step-by-step demonstration of the LDTool workflow applied to a real multi-objective
controller design problem: the **ACC benchmark** two-mass spring system.

## Problem description

The ACC benchmark consists of a two-mass spring plant where the controller must
balance six competing objectives simultaneously:

| Objective | Symbol | Description |
|---|---|---|
| Robust stability margin | f1 | Stability robustness to plant gain variations |
| Worst-case control effort | f2 | Maximum actuator demand across gain variations |
| Worst-case settling time | f3 | Slowest disturbance rejection across gain variations |
| Noise sensitivity | f4 | Sensitivity of the output to measurement noise |
| Nominal control effort | f5 | Actuator demand at nominal plant gain (K=1) |
| Nominal settling time | f6 | Disturbance rejection speed at nominal gain (K=1) |

The controller has 6 parameters (numerator and denominator coefficients of a 3rd-order
transfer function). The Pareto front stored in `accbench6_ev.mat` was obtained with
evMOGA and contains the non-dominated trade-off solutions.

**Reference:**
> Blasco, X., Reynoso-Meza, G., Sánchez Pérez, E.A., Sánchez Pérez, J.V. (2016).
> Asymmetric distances to improve n-dimensional Pareto fronts graphical analysis.
> *Information Sciences*, 340–341, 228–249.
> <http://dx.doi.org/10.1016/j.ins.2015.12.039>

## Files

| File | Description |
|---|---|
| `accBenchmarkExample.m` | Main script — run section by section |
| `displayGPPInfo.m` | `onSelect` callback: prints GPP index and class labels for a selected point |
| `showControlResponses.m` | `onSelect` callback: simulates and plots y(t) and u(t) for a selected controller |
| `accbench6_ev.mat` | Pareto front and Pareto set data (`ParetoFront`, `ParetoSet`) |

## Workflow overview

The main script (`accBenchmarkExample.m`) is divided into numbered sections that
can be run one at a time with **Ctrl+Enter**:

### 1–2. Load data and define preferences

Pareto data is loaded and a preference table `pref` is defined with five class ranges
per objective:

```
HD  Highly Desirable  — strongly preferred region
D   Desirable         — acceptable region
T   Tolerable         — neutral region
U   Undesirable       — to be avoided
HU  Highly Undesirable — strongly penalised
```

### 3. Global Physical Programming (GPP) index

[`gppl`](../../src/matlab/gppl.m) converts the six-objective preference table into a
single scalar ranking. Two call forms are demonstrated:

```matlab
vgpp = gppl(pf, pref);                         % index only
[vgpp, etiquetas] = gppl(pf, pref, etiqPref);  % index + per-solution labels
```

The labels (`etiquetas`) summarise the class of each objective for each solution,
e.g. `'HD,D,T,U,HD'`.

> Reference: Reynoso-Meza, G. et al. (2014). Physical programming for preference
> driven evolutionary multi-objective optimization. *Applied Soft Computing*, 24,
> 341–362. <https://doi.org/10.1016/j.asoc.2014.07.009>

### 4. Build and display the Level Diagram

A `Concept` wraps the Pareto front and set with objective and parameter labels.
A `LevelDiagram` is created, the concept is added, and `draw()` opens the
interactive figures.

### 5–6. Colour coding

Two colouring strategies are demonstrated:

- **Asymmetric distance** to the tolerable boundary vertex `pref(:,3)`:
  zero means the solution already dominates the target point (see Fig. 17–18
  of Blasco et al. 2016).
- **GPP index** in log scale (`log10(vgpp)`) for better colour contrast across
  the wide range of GPP values.

Clicking a point in either view triggers the `displayGPPInfo` callback, which
prints the GPP value and class labels to the console.

### 7–8. Fixed colour and subset highlighting

A fixed RGB colour is applied to all points, then solutions with zero asymmetric
distance (i.e. those that already dominate the tolerable point) are extracted as
a separate concept with a larger marker size to highlight them visually.

### 9. Switching the synchronisation norm

The Y-axis of the Level Diagram can be switched between L1, L2 and L∞ norms
without rebuilding the diagram.

### 10–11. Composed Norm and preference bands

[`composedNorm`](../../src/matlab/composedNorm.m) assigns each solution to the
innermost preference hypercube it does not dominate and measures its distance
within that hypercube. This produces a Y-axis ordering that respects the
preference structure directly.

[`drawPrefBands`](../../src/matlab/drawPrefBands.m) overlays the class-range
boundaries as shaded bands on both the Objectives and Parameters figures.

### 12. Clearing bands

Closing all figures and calling `ld.draw()` again removes the preference bands
(bands are not stored in the `LevelDiagram` object).

### 13. Control response viewer

Registering `showControlResponses` as the `onSelect` callback opens a figure with
simulated closed-loop responses whenever a point is clicked. Three plant gain
values (K = 0.5, 1, 2) are shown simultaneously to visualise the nominal and
worst-case behaviour. Settling times and peak control efforts are annotated
directly on the plots.

## Requirements

- MATLAB R2020b or later (`tiledlayout` used in `showControlResponses`).
- LDTool on the MATLAB path: `addpath('../../src/matlab')`.
