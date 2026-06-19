classdef LDControlPanel < handle
    % LDControlPanel  Interactive control panel for a LevelDiagram object.
    %
    % Launch:
    %   panel = ld.showPanel()          % recommended
    %   panel = LDControlPanel(ld)      % direct constructor
    %
    % The panel opens docked to the right of the screen and provides a
    % graphical interface to the most common LevelDiagram operations
    % without writing MATLAB commands.
    %
    % ── CONCEPTS section ─────────────────────────────────────────────────
    %   Select PF and PS matrices from the workspace, name the concept and
    %   click "+ Add concept".  Use "✎ Edit labels..." to assign meaningful
    %   names to objectives and parameters (the dialog is non-blocking so
    %   you can copy text from other windows).
    %   "✕ Remove selected" removes the highlighted concept; "Clear all"
    %   removes every concept from the diagram.
    %   "▶ Draw" (re)draws the Level Diagram.
    %
    % ── Y-AXIS SYNC section ───────────────────────────────────────────────
    %   Norm  : synchronise axes using an Lp norm (editable p, default 2).
    %   Workspace : assign one workspace vector per concept as the sync
    %               variable.
    %   "Reset bounds" restores the original per-concept axis limits.
    %
    % ── ACTIVE CONCEPT section ───────────────────────────────────────────
    %   Dropdown selects which concept is targeted by the four tabs below.
    %   Each tab acts on the active concept independently.
    %
    %   Tab — Selection:
    %     Filter and select points by objective or parameter value.
    %     Choose a column, an operator (>, <, >=, <=, ==, ~=) and a
    %     threshold, then click "Select" (replace) or "+ Add to sel."
    %     (accumulate).  "Clear selection" deselects all points.
    %     "WS idx" feeds a numeric index vector from the workspace directly
    %     into the selection via "Use".
    %
    %   Tab — Color:
    %     "According to" dropdown:
    %       Uniform (base color) — solid colour chosen via the palette button
    %                              or by typing an RGB triplet (0–1 values).
    %       Concept objectives   — colour mapped to an objective column.
    %       Concept parameters   — colour mapped to a parameter column.
    %       Workspace            — colour mapped to a workspace vector.
    %     Choose a colormap, optionally invert it, then click "Apply color".
    %     "↺ Refresh panel from LD" reads back the current colour from the
    %     diagram and updates the picker/RGB field automatically.
    %
    %   Tab — Size & Marker:
    %     Uniform : a slider sets a fixed marker size for all points.
    %     Variable: scales marker size between a min and max (pts) according
    %               to a selected variable.
    %     Marker shape: circle, square, triangle, diamond, inverted triangle.
    %
    %   Tab — Callback:
    %     Type a function name or @-expression in the text field, or click
    %     "..." to browse for a .m file.  "Assign" registers the callback
    %     with ld.onSelect(); "Remove callbacks" clears all callbacks for
    %     the active concept.
    %
    % ── Refresh button ────────────────────────────────────────────────────
    %   "↺ Refresh panel from LD" synchronises the panel with external
    %   changes made from the MATLAB command window (colour, callbacks,
    %   concept list).

    properties (Access = private)
        ld              % LevelDiagram asociado

        % Figura principal
        fig

        % — CONCEPTOS —
        lstConcepts
        edtName
        ddPF
        ddPS
        ddWsConcept     % Concept objects available in base workspace
        btnAdd
        btnDraw

        % — SINCRONIZACIÓN —
        pnlSync         % Y-AXIS SYNC section panel (resizes dynamically)
        pnlSyncHeader   % sub-panel holding Type dropdown + Reset (moves up with rows)
        ddSyncType
        pnlLp           % sub-panel Norm
        edtP
        pnlWs           % sub-panel Workspace (dynamic rows, resizes dynamically)

        % — CONCEPTO ACTIVO —
        pnlConcepts     % CONCEPTS section panel (repositioned by updateSyncLayout)
        ddConcept

        % — COLOR —
        ddColorVar
        colorVarMeta    % cell de structs paralela a ddColorVar.Items
        ddColormap
        chkRevColor
        axColorPreview

        % — COLOR (extras) —
        pnlColorMap     % sub-panel colormap (variable mode)
        pnlColorUnif    % sub-panel color picker (uniform mode)
        btnColorPicker  % colored button that opens uisetcolor
        edtRgb          % RGB text field for uniform color
        uniformColor    % current uniform RGB color [1x3]

        % — SELECCIÓN —
        ddSelType       % Objectives / Parameters
        ddSelVar        % column label dropdown
        ddSelOp         % operator dropdown
        edtSelVal       % numeric threshold
        ddSelIdx        % workspace index vector dropdown

        % — CALLBACKS —
        lblCurrentCb    % shows currently registered callback
        edtCbFn         % text field: function name or @expression
        btnCbBrowse     % [...] browse for .m file
        btnAssignCb
        btnClearCb

        % — REFRESCO —
        btnRefresh

        % — TAMAÑO Y MARCADOR —
        ddSizeVar
        sizeVarMeta     % cell de structs paralela a ddSizeVar.Items
        pnlSizeUnif     % sub-panel slider (modo Uniforme)
        sldSize
        edtSize
        pnlSizeVar      % sub-panel rango (modo Variable)
        edtSizeMin
        edtSizeMax
        ddMarker

    end

    % =====================================================================
    methods (Access = public)

        function obj = LDControlPanel(ld)
            validateattributes(ld, {'LevelDiagram'}, {'scalar'}, ...
                mfilename, 'ld');
            obj.ld = ld;
            obj.colorVarMeta = {};
            obj.sizeVarMeta  = {};
            obj.uniformColor = [0.00 0.45 0.74]; % default azul
            obj.buildUI();
            obj.refreshConceptList();
        end

    end

    % =====================================================================
    methods (Access = private)

        % -----------------------------------------------------------------
        % CONSTRUCCIÓN DE LA FIGURA
        % -----------------------------------------------------------------
        function buildUI(obj)
            ldName = obj.ld.name;
            if isempty(ldName)
                figTitle = 'LD Controls';
            else
                figTitle = sprintf('LD Controls — %s', ldName);
            end

            % Centrar el panel en pantalla
            panelW = 360; panelH = 718;
            ss     = get(0, 'ScreenSize');
            xPos   = round((ss(3) - panelW) / 2);
            yPos   = max(10, round((ss(4) - panelH) / 2));

            obj.fig = uifigure( ...
                'Name',     figTitle, ...
                'Position', [xPos yPos panelW panelH], ...
                'Resize',   'off');

            M = 8; W = 344;
            obj.buildRefreshButton(     M,   5, W);
            obj.buildConceptOpsSection( M,  36, W);
            obj.buildSyncSection(       M, 306, W);
            obj.buildConceptsSection(   M, 432, W);
        end

        % -----------------------------------------------------------------
        % SECCIÓN: CONCEPTOS
        % -----------------------------------------------------------------
        function buildConceptsSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'CONCEPTS', ...
                'FontWeight', 'bold', 'Position', [x y W 268]);
            obj.pnlConcepts = pnl;

            obj.lstConcepts = uilistbox(pnl, ...
                'Position', [5 197 W-14 46], ...
                'Items', {}, 'Multiselect', 'off');

            uibutton(pnl, 'Text', '✎ Edit labels...', ...
                'Position', [5 171 W-14 22], ...
                'Tooltip', 'Set objective and parameter labels for the selected concept', ...
                'ButtonPushedFcn', @(~,~) obj.onEditLabels());

            uilabel(pnl, 'Text', 'Name', 'Position', [5 145 42 20]);
            obj.edtName = uieditfield(pnl, 'text', ...
                'Position', [52 145 W-62 22], 'Value', 'new');

            uilabel(pnl, 'Text', 'PF', 'Position', [5 118 20 20]);
            obj.ddPF = uidropdown(pnl, ...
                'Position', [30 118 W-61 22], 'Items', {'(refresh ↺)'});
            uibutton(pnl, 'Text', '↺', 'Position', [W-26 118 22 22], ...
                'Tooltip', 'Refresh workspace matrices', ...
                'ButtonPushedFcn', @(~,~) obj.refreshWorkspaceMatrices());

            uilabel(pnl, 'Text', 'PS', 'Position', [5 93 20 20]);
            obj.ddPS = uidropdown(pnl, ...
                'Position', [30 93 W-40 22], 'Items', {'(refresh ↺)'});

            uibutton(pnl, 'Text', '✕ Remove selected', ...
                'Position', [5 66 148 22], ...
                'Tooltip', 'Remove the selected concept from the LD', ...
                'ButtonPushedFcn', @(~,~) obj.onRemoveConcept());
            uibutton(pnl, 'Text', 'Clear all', ...
                'Position', [158 66 W-172 22], ...
                'Tooltip', 'Remove all concepts from the LD', ...
                'ButtonPushedFcn', @(~,~) obj.onClearAllConcepts());

            obj.btnAdd = uibutton(pnl, 'Text', '+ Add concept', ...
                'Position', [5 35 148 26], ...
                'ButtonPushedFcn', @(~,~) obj.onAddConcept());
            obj.btnDraw = uibutton(pnl, 'Text', '▶ Draw', ...
                'Position', [158 35 W-172 26], ...
                'BackgroundColor', [0.18 0.55 0.18], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.onDraw());

            % ── Load existing Concept from workspace ──────────────────────
            uilabel(pnl, 'Text', 'WS:', 'Position', [5 8 28 20], ...
                'Tooltip', 'Select a workspace Concept and click "+ Add concept"');
            obj.ddWsConcept = uidropdown(pnl, ...
                'Position', [38 5 W-76 22], 'Items', {'(none)'}, ...
                'Tooltip', 'Concept objects in the base workspace — overrides PF/PS when selected');
            uibutton(pnl, 'Text', '↺', 'Position', [W-33 5 22 22], ...
                'Tooltip', 'Refresh workspace Concept objects', ...
                'ButtonPushedFcn', @(~,~) obj.refreshWorkspaceConcepts());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: SINCRONIZACIÓN EJE Y
        % -----------------------------------------------------------------
        function buildSyncSection(obj, x, y, W)
            % Height for Norm mode: 5 (bottom) + 58 (subH) + 8 (gap) + 24 (header) + 26 (title) = 121
            obj.pnlSync = uipanel(obj.fig, 'Title', 'Y-AXIS SYNC', ...
                'FontWeight', 'bold', 'Position', [x y W 121]);

            % Header sub-panel: 4px margin each side to avoid clipping panel borders.
            % Positioned 8px above the content sub-panel; stays below the panel title.
            obj.pnlSyncHeader = uipanel(obj.pnlSync, 'BorderType', 'none', ...
                'Position', [4 71 W-8 24]);
            uilabel(obj.pnlSyncHeader, 'Text', 'Type', 'Position', [5 2 30 20]);
            obj.ddSyncType = uidropdown(obj.pnlSyncHeader, ...
                'Position', [40 2 W-160 22], ...
                'Items', {'Norm', 'Workspace'}, ...
                'ValueChangedFcn', @(~,~) obj.onSyncTypeChanged());
            uibutton(obj.pnlSyncHeader, 'Text', 'Reset bounds', ...
                'Position', [W-115 2 110 22], ...
                'ButtonPushedFcn', @(~,~) obj.onSyncReset());

            % Sub-panels: both anchored at y=5; only one visible at a time.
            subX = 4; subW = W - 8; subY = 5; subH = 58;

            % ··· Sub-panel: Norm ··········································
            obj.pnlLp = uipanel(obj.pnlSync, 'BorderType', 'none', ...
                'Position', [subX subY subW subH]);
            uilabel(obj.pnlLp, 'Text', 'p =', 'Position', [5 18 25 20]);
            obj.edtP = uieditfield(obj.pnlLp, 'numeric', ...
                'Position', [35 18 55 22], 'Value', 2, 'Limits', [1 Inf]);
            uibutton(obj.pnlLp, 'Text', 'Apply', ...
                'Position', [100 18 subW-108 22], ...
                'ButtonPushedFcn', @(~,~) obj.onSyncApply());

            % ··· Sub-panel: Workspace (dynamic rows) ······················
            % Apply button tag is fixed; rebuildSyncWsPanel deletes 'wsrow_*' children.
            obj.pnlWs = uipanel(obj.pnlSync, 'BorderType', 'none', ...
                'Position', [subX subY subW subH], 'Visible', 'off');
            uibutton(obj.pnlWs, 'Text', 'Apply sync', ...
                'Position', [subW-110 5 106 22], 'Tag', 'ws_aplicar', ...
                'ButtonPushedFcn', @(~,~) obj.onSyncApply());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: CONCEPTO ACTIVO + TABS DE OPERACIONES
        % -----------------------------------------------------------------
        function buildConceptOpsSection(obj, x, y, W)
            % One section containing the active-concept selector and a tab
            % group for the four operation types (Selection / Color / Size / Callback).
            % Layout (inner y from bottom of panel):
            %   y=5   : tab group (h=210)
            %   y=220 : active concept dropdown
            %   y=242+: panel title area
            pnl = uipanel(obj.fig, 'Title', 'ACTIVE CONCEPT', ...
                'FontWeight', 'bold', 'Position', [x y W 265]);

            uilabel(pnl, 'Text', 'Concept:', ...
                'Position', [5 222 58 20], 'FontWeight', 'bold');
            obj.ddConcept = uidropdown(pnl, ...
                'Position', [68 220 W-76 24], ...
                'Items', {'(no concepts)'}, ...
                'BackgroundColor', [0.92 0.97 1.0], ...
                'ValueChangedFcn', @(~,~) obj.onConceptChanged());

            tg = uitabgroup(pnl, 'Position', [2 5 W-4 210]);

            obj.buildSelectionTab( uitab(tg, 'Title', 'Selection') );
            obj.buildColorTab(     uitab(tg, 'Title', 'Color') );
            obj.buildSizeTab(      uitab(tg, 'Title', 'Size && Marker') );
            obj.buildCallbackTab(  uitab(tg, 'Title', 'Callback') );
        end

        function buildSelectionTab(obj, t)
            obj.ddSelType = uidropdown(t, ...
                'Position', [5 90 85 22], ...
                'Items', {'Objectives', 'Parameters'}, ...
                'ValueChangedFcn', @(~,~) obj.onSelTypeChanged());
            obj.ddSelVar = uidropdown(t, ...
                'Position', [95 90 208 22], 'Items', {'(no concepts)'});
            uibutton(t, 'Text', '↺', 'Position', [308 90 22 22], ...
                'Tooltip', 'Refresh variable list', ...
                'ButtonPushedFcn', @(~,~) obj.refreshSelectionVars());

            obj.ddSelOp = uidropdown(t, ...
                'Position', [5 64 50 22], ...
                'Items', {'>', '<', '>=', '<=', '==', '~='});
            obj.edtSelVal = uieditfield(t, 'numeric', ...
                'Position', [60 64 52 22], 'Value', 0);
            uibutton(t, 'Text', 'Select', ...
                'Position', [117 64 68 22], ...
                'Tooltip', 'Replace selection with matching points', ...
                'ButtonPushedFcn', @(~,~) obj.onSelectByCondition());
            uibutton(t, 'Text', '+ Add to sel.', ...
                'Position', [190 64 140 22], ...
                'Tooltip', 'Add matching points to current selection', ...
                'ButtonPushedFcn', @(~,~) obj.onAddToSelection());

            uibutton(t, 'Text', 'Clear selection', ...
                'Position', [5 38 325 22], ...
                'ButtonPushedFcn', @(~,~) obj.onClearSelection());

            uilabel(t, 'Text', 'WS idx:', 'Position', [5 10 48 20], ...
                'Tooltip', 'Pass an index vector from the workspace');
            obj.ddSelIdx = uidropdown(t, ...
                'Position', [58 8 210 22], 'Items', {'(refresh ↺)'}, ...
                'Tooltip', 'Numeric index vector from the workspace');
            uibutton(t, 'Text', '↺', 'Position', [273 8 22 22], ...
                'Tooltip', 'Refresh workspace index vectors', ...
                'ButtonPushedFcn', @(~,~) obj.refreshSelectionIdxVars());
            uibutton(t, 'Text', 'Use', 'Position', [300 8 30 22], ...
                'Tooltip', 'Select points using this index vector', ...
                'ButtonPushedFcn', @(~,~) obj.onSelectFromWS());
        end

        function buildColorTab(obj, t)
            uilabel(t, 'Text', 'According to', 'Position', [5 152 80 20]);
            obj.ddColorVar = uidropdown(t, ...
                'Position', [90 152 214 22], ...
                'Items', {'(no concepts)'}, ...
                'ValueChangedFcn', @(~,~) obj.onColorVarModeChanged());
            uibutton(t, 'Text', '↺', 'Position', [309 152 22 22], ...
                'Tooltip', 'Refresh workspace variables', ...
                'ButtonPushedFcn', @(~,~) obj.refreshColorVars());

            obj.pnlColorMap = uipanel(t, 'BorderType', 'none', ...
                'Position', [4 38 326 110]);
            uilabel(obj.pnlColorMap, 'Text', 'Colormap', 'Position', [1 84 58 20]);
            obj.ddColormap = uidropdown(obj.pnlColorMap, ...
                'Position', [64 84 260 22], ...
                'Items', {'parula','jet','hot','cool','gray','turbo','winter','summer','copper'});
            obj.chkRevColor = uicheckbox(obj.pnlColorMap, ...
                'Text', 'Invert colormap', 'Position', [1 62 130 20]);
            obj.axColorPreview = uiaxes(obj.pnlColorMap, 'Position', [1 28 322 26]);
            obj.axColorPreview.XTick = []; obj.axColorPreview.YTick = [];
            obj.axColorPreview.XLim  = [0 1]; obj.axColorPreview.YLim = [0 1];
            disableDefaultInteractivity(obj.axColorPreview);
            obj.updateColormapPreview('parula');
            uilabel(obj.pnlColorMap, 'Text', 'min', 'Position', [1 8 25 16], ...
                'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);
            uilabel(obj.pnlColorMap, 'Text', 'max', 'Position', [299 8 28 16], ...
                'FontSize', 9, 'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'right');

            obj.pnlColorUnif = uipanel(t, 'BorderType', 'none', ...
                'Position', [4 38 326 110], 'Visible', 'off');
            uilabel(obj.pnlColorUnif, 'Text', 'Palette', 'Position', [1 82 42 20]);
            obj.btnColorPicker = uibutton(obj.pnlColorUnif, ...
                'Text', 'Pick color...', 'Position', [48 80 274 24], ...
                'BackgroundColor', obj.uniformColor, ...
                'Tooltip', 'Open color picker dialog', ...
                'ButtonPushedFcn', @(~,~) obj.onPickColor());
            uilabel(obj.pnlColorUnif, 'Text', 'RGB', 'Position', [1 52 30 20]);
            obj.edtRgb = uieditfield(obj.pnlColorUnif, 'text', ...
                'Position', [36 52 286 22], ...
                'Value', obj.rgb2str(obj.uniformColor), ...
                'Placeholder', 'e.g.  0.2  0.5  0.8', ...
                'Tooltip', 'Type three values 0–1 separated by spaces', ...
                'ValueChangedFcn', @(~,~) obj.onRgbEdit());

            uibutton(t, 'Text', 'Apply color', ...
                'Position', [5 8 326 24], ...
                'ButtonPushedFcn', @(~,~) obj.onColorApply());
        end

        function buildSizeTab(obj, t)
            uilabel(t, 'Text', 'Variable', 'Position', [5 95 52 20]);
            obj.ddSizeVar = uidropdown(t, ...
                'Position', [62 95 246 22], ...
                'Items', {'Uniform'}, ...
                'ValueChangedFcn', @(~,~) obj.onSizeVarChanged());
            uibutton(t, 'Text', '↺', 'Position', [313 95 22 22], ...
                'Tooltip', 'Refresh workspace variables', ...
                'ButtonPushedFcn', @(~,~) obj.refreshSizeVars());

            obj.pnlSizeUnif = uipanel(t, 'BorderType', 'none', ...
                'Position', [4 42 328 50]);
            obj.sldSize = uislider(obj.pnlSizeUnif, ...
                'Position', [8 30 256 3], ...
                'Limits', [1 200], 'Value', 36, ...
                'MajorTicks', [1 50 100 150 200], 'MinorTicks', [], ...
                'ValueChangedFcn', @(src,~) obj.onSizeSlider(src));
            obj.edtSize = uieditfield(obj.pnlSizeUnif, 'numeric', ...
                'Position', [276 22 47 22], 'Value', 36, 'Limits', [1 200], ...
                'ValueChangedFcn', @(src,~) obj.onSizeEdit(src));
            uilabel(obj.pnlSizeUnif, 'Text', 'pts', ...
                'Position', [276 5 35 16], 'FontSize', 9, ...
                'FontColor', [0.5 0.5 0.5]);

            obj.pnlSizeVar = uipanel(t, 'BorderType', 'none', ...
                'Position', [4 42 328 50], 'Visible', 'off');
            uilabel(obj.pnlSizeVar, 'Text', 'Range pts', 'Position', [5 24 65 20]);
            obj.edtSizeMin = uieditfield(obj.pnlSizeVar, 'numeric', ...
                'Position', [75 24 55 22], 'Value', 10, ...
                'ValueChangedFcn', @(~,~) obj.onSizeApply());
            uilabel(obj.pnlSizeVar, 'Text', '—', 'Position', [134 24 14 20]);
            obj.edtSizeMax = uieditfield(obj.pnlSizeVar, 'numeric', ...
                'Position', [152 24 55 22], 'Value', 80, ...
                'ValueChangedFcn', @(~,~) obj.onSizeApply());
            uilabel(obj.pnlSizeVar, 'Text', 'pts', ...
                'Position', [213 24 28 20], 'FontSize', 9, ...
                'FontColor', [0.5 0.5 0.5]);

            uilabel(t, 'Text', 'Marker', 'Position', [5 12 58 20]);
            obj.ddMarker = uidropdown(t, ...
                'Position', [68 12 267 22], ...
                'Items', {'○  Circle','□  Square','△  Triangle', ...
                          '◇  Diamond','▽  Inv. triangle'}, ...
                'ValueChangedFcn', @(~,~) obj.onMarkerChanged());
        end

        function buildCallbackTab(obj, t)
            uilabel(t, 'Text', 'Current:', ...
                'Position', [5 68 48 18], 'FontSize', 9, ...
                'FontColor', [0.4 0.4 0.4]);
            obj.lblCurrentCb = uilabel(t, 'Text', '(none)', ...
                'Position', [58 65 268 22], ...
                'FontSize', 9, 'FontColor', [0.25 0.25 0.25], ...
                'WordWrap', 'on', 'Interpreter', 'none');

            obj.edtCbFn = uieditfield(t, 'text', ...
                'Position', [5 38 298 22], 'Value', '', ...
                'Placeholder', 'myFunction  or  @(p) expr', ...
                'Tooltip', 'Function name or @-expression. Use [...] to browse a .m file.');
            obj.btnCbBrowse = uibutton(t, 'Text', '...', ...
                'Position', [308 38 22 22], ...
                'Tooltip', 'Browse for a .m file', ...
                'ButtonPushedFcn', @(~,~) obj.onCbBrowse());

            obj.btnAssignCb = uibutton(t, 'Text', '+ Assign', ...
                'Position', [5 8 130 24], ...
                'ButtonPushedFcn', @(~,~) obj.onAssignCallback());
            obj.btnClearCb = uibutton(t, 'Text', 'Remove callbacks', ...
                'Position', [142 8 188 24], ...
                'ButtonPushedFcn', @(~,~) obj.onClearCallbacks());
        end

        % -----------------------------------------------------------------
        % BOTÓN DE REFRESCO (pie del panel, siempre visible)
        % -----------------------------------------------------------------
        function buildRefreshButton(obj, x, y, W)
            obj.btnRefresh = uibutton(obj.fig, ...
                'Text',            '↺  Refresh panel from LD', ...
                'Position',        [x y W 26], ...
                'BackgroundColor', [0.94 0.94 0.94], ...
                'ButtonPushedFcn', @(~,~) obj.refreshAll());
        end

        % =================================================================
        % POBLADO / REFRESCO DE CONTROLES
        % =================================================================

        function refreshAll(obj)
            obj.refreshConceptList();
            obj.refreshColorState();
        end

        function refreshColorState(obj)
            % Reads current colorData from the LD and updates the color controls.
            names = obj.ld.getConceptNames();
            if isempty(names); return; end
            c       = obj.ld.getConceptByName(obj.activeConcept(names));
            colData = obj.ld.getConceptColorData(c);
            if isempty(colData) || size(colData,2) ~= 3; return; end
            firstRow = colData(1,:);
            isUniform = all(max(abs(colData - firstRow)) < 1e-6);
            if isUniform
                obj.uniformColor = firstRow;
                obj.btnColorPicker.BackgroundColor = firstRow;
                obj.edtRgb.Value = obj.rgb2str(firstRow);
                if ~strcmp(obj.ddColorVar.Value, 'Uniform (base color)') && ...
                        ~isempty(obj.colorVarMeta)
                    obj.ddColorVar.Value = 'Uniform (base color)';
                    obj.onColorVarModeChanged();
                end
            end
            drawnow;
        end

        function refreshCallbackDisplay(obj)
            names = obj.ld.getConceptNames();
            if isempty(names)
                obj.lblCurrentCb.Text = '(none)';
                drawnow;
                return
            end
            c   = obj.ld.getConceptByName(obj.activeConcept(names));
            fns = obj.ld.getConceptCallbacks(c);
            if isempty(fns)
                obj.lblCurrentCb.Text = '(none)';
            else
                strs = cellfun(@func2str, fns, 'UniformOutput', false);
                obj.lblCurrentCb.Text = strjoin(strs, '  |  ');
            end
            drawnow;
        end

        function refreshConceptList(obj)
            names = obj.ld.getConceptNames();
            if isempty(names)
                obj.lstConcepts.Items = {};
                obj.ddConcept.Items   = {'(no concepts)'};
                obj.ddColorVar.Items  = {'(no concepts)'};
                obj.colorVarMeta      = {};
                obj.ddSizeVar.Items   = {'Uniform'};
                obj.sizeVarMeta       = {struct('type','uniform')};
            else
                obj.lstConcepts.Items = names;
                % Mantener el concepto activo si sigue existiendo
                if ~ismember(obj.ddConcept.Value, names)
                    obj.ddConcept.Items = names;
                    obj.ddConcept.Value = names{1};
                else
                    prev = obj.ddConcept.Value;
                    obj.ddConcept.Items = names;
                    obj.ddConcept.Value = prev;
                end
                obj.refreshColorVars();
                obj.refreshSizeVars();
                obj.refreshSelectionVars();
                obj.rebuildSyncWsPanel();
                obj.refreshCallbackDisplay();
            end
        end

        function refreshWorkspaceConcepts(obj)
            try
                vars  = evalin('base', 'whos');
                ok    = arrayfun(@(v) strcmp(v.class, 'Concept'), vars);
                found = {vars(ok).name};
            catch
                found = {};
            end
            obj.ddWsConcept.Items = [{'(none)'}, found];
            obj.ddWsConcept.Value = '(none)';
        end

        function refreshSelectionVars(obj)
            names = obj.ld.getConceptNames();
            if isempty(names)
                obj.ddSelVar.Items = {'(no concepts)'};
                return
            end
            c = obj.ld.getConceptByName(obj.activeConcept(names));
            if strcmp(obj.ddSelType.Value, 'Objectives')
                labels = c.labels.objectives;
            else
                labels = c.labels.parameters;
            end
            if isempty(labels)
                obj.ddSelVar.Items = {'(none)'};
            else
                obj.ddSelVar.Items = labels;
                obj.ddSelVar.Value = labels{1};
            end
        end

        function refreshSelectionIdxVars(obj)
            try
                vars = evalin('base', 'whos');
                ok   = arrayfun(@(v) strcmp(v.class,'double') && ...
                                     numel(v.size)==2 && min(v.size)==1, vars);
                items = {vars(ok).name};
            catch
                items = {};
            end
            if isempty(items); items = {'(none)'}; end
            obj.ddSelIdx.Items = items;
        end

        function refreshWorkspaceMatrices(obj)
            try
                vars = evalin('base', 'whos');
                ok   = arrayfun(@(v) ...
                    strcmp(v.class,'double') && numel(v.size) == 2, vars);
                mats = {vars(ok).name};
            catch
                mats = {};
            end
            if isempty(mats); mats = {'(none)'}; end
            obj.ddPF.Items = mats;
            obj.ddPS.Items = mats;
        end

        function refreshColorVars(obj)
            names = obj.ld.getConceptNames();
            if isempty(names); return; end
            conceptName = obj.activeConcept(names);
            c = obj.ld.getConceptByName(conceptName);
            [items, meta] = obj.buildVarItems(c);
            obj.ddColorVar.Items = [{'Uniform (base color)', '── ──'}, items];
            obj.colorVarMeta     = [{struct('type','uniform'), struct('type','sep')}, meta];
            obj.onColorVarModeChanged();
        end

        function refreshSizeVars(obj)
            names = obj.ld.getConceptNames();
            if isempty(names); return; end
            conceptName = obj.activeConcept(names);
            c = obj.ld.getConceptByName(conceptName);
            [items, meta] = obj.buildVarItems(c);
            obj.ddSizeVar.Items = [{'Uniform'}, items];
            obj.sizeVarMeta     = [{struct('type','uniform')}, meta];
        end

        function [items, meta] = buildVarItems(obj, concept)
            objLabels = concept.labels.objectives;
            parLabels = concept.labels.parameters;
            wsItems   = obj.getWorkspaceVectors(concept.nind);

            items = [{'── Concept ──'}, objLabels, ...
                     {'── Parameters ──'}, parLabels, ...
                     {'── Workspace ──'}, wsItems];

            meta = {struct('type','sep')};
            for i = 1:numel(objLabels)
                meta{end+1} = struct('type','obj','index',i); %#ok<AGROW>
            end
            meta{end+1} = struct('type','sep');
            for i = 1:numel(parLabels)
                meta{end+1} = struct('type','par','index',i); %#ok<AGROW>
            end
            meta{end+1} = struct('type','sep');
            for i = 1:numel(wsItems)
                meta{end+1} = struct('type','ws','name',wsItems{i}); %#ok<AGROW>
            end
        end

        function items = getWorkspaceVectors(~, nind)
            try
                vars = evalin('base', 'whos');
                if nind > 0
                    ok = arrayfun(@(v) ...
                        strcmp(v.class,'double') && ...
                        numel(v.size) == 2 && ...
                        any(v.size == nind) && ...
                        min(v.size) >= 1, vars);
                else
                    ok = arrayfun(@(v) ...
                        strcmp(v.class,'double') && ...
                        numel(v.size) == 2 && ...
                        min(v.size) == 1, vars);
                end
                items = {vars(ok).name};
            catch
                items = {};
            end
            if isempty(items); items = {'(none)'}; end
        end

        function rebuildSyncWsPanel(obj)
            % Delete only dynamic rows (Tag starts with 'wsrow_');
            % preserve the fixed Apply button (Tag 'ws_aplicar').
            kids = obj.pnlWs.Children;
            for k = 1:numel(kids)
                if startsWith(kids(k).Tag, 'wsrow_')
                    delete(kids(k));
                end
            end
            names  = obj.ld.getConceptNames();
            nC     = numel(names);
            rowH   = 26; gap = 4;
            wsVars = obj.getWorkspaceVectors(0);
            pnlW   = obj.pnlWs.Position(3);   % actual panel width

            % Rows stack upward from y=32 (above the fixed Apply button at y=5)
            for k = 1:nC
                yRow = 32 + (nC - k) * (rowH + gap);
                uilabel(obj.pnlWs, 'Text', names{k}, ...
                    'Position', [5 yRow 82 20], ...
                    'Tag', sprintf('wsrow_lbl%d', k));
                uidropdown(obj.pnlWs, ...
                    'Position', [92 yRow pnlW-122 22], ...
                    'Items', wsVars, ...
                    'Tag', sprintf('wsrow_dd%d', k));
                uibutton(obj.pnlWs, 'Text', '↺', ...
                    'Position', [pnlW-26 yRow 22 22], ...
                    'Tag', sprintf('wsrow_ref%d', k), ...
                    'ButtonPushedFcn', @(~,~) obj.rebuildSyncWsPanel());
            end

            % Resize pnlWs: Apply(27px) + nC rows × 30px, minimum 32px
            wsH = 32 + nC * (rowH + gap);
            obj.pnlWs.Position(4) = wsH;

            % If Workspace mode is active, cascade the resize to the section
            if strcmp(obj.ddSyncType.Value, 'Workspace')
                obj.updateSyncLayout(wsH);
            end
        end

        % =================================================================
        % CALLBACKS
        % =================================================================

        function onAddConcept(obj)
            wsVal = obj.ddWsConcept.Value;
            if ~strcmp(wsVal, '(none)')
                % Load an existing Concept object from the workspace
                try
                    c = evalin('base', wsVal);
                    if ~isa(c, 'Concept')
                        uialert(obj.fig, ...
                            sprintf('"%s" is not a Concept object.', wsVal), 'Type error');
                        return
                    end
                    obj.ld.addConcept(c);
                    obj.ddWsConcept.Value = '(none)';
                    obj.refreshConceptList();
                catch ME
                    uialert(obj.fig, ME.message, 'Error loading concept');
                end
                return
            end
            % Create a new Concept from PF/PS matrices
            try
                pf   = evalin('base', obj.ddPF.Value);
                ps   = evalin('base', obj.ddPS.Value);
                name = strtrim(obj.edtName.Value);
                if isempty(name); name = obj.ddPF.Value; end
                c = Concept(pf, ps, name);
                obj.ld.addConcept(c);
                assignin('base', name, c);
                obj.edtName.Value = 'new';
                obj.refreshConceptList();
            catch ME
                uialert(obj.fig, ME.message, 'Error adding concept');
            end
        end

        function onDraw(obj)
            try
                obj.ld.draw();
                obj.refreshConceptList();
            catch ME
                uialert(obj.fig, ME.message, 'Error drawing');
            end
        end

        function onRemoveConcept(obj)
            name = obj.lstConcepts.Value;
            if isempty(name); return; end
            try
                c = obj.ld.getConceptByName(name);
                obj.ld.removeConcept(c);
                obj.clearWorkspaceConcept(name);
                obj.refreshConceptList();
            catch ME
                uialert(obj.fig, ME.message, 'Error removing concept');
            end
        end

        function onClearAllConcepts(obj)
            answer = uiconfirm(obj.fig, ...
                'Remove all concepts from the Level Diagram?', ...
                'Clear All Concepts', ...
                'Options',       {'Remove All', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption',  2);
            if ~strcmp(answer, 'Remove All'); return; end
            try
                obj.ld.closeAllFigures();
                names = obj.ld.getConceptNames();
                for k = 1:numel(names)
                    c = obj.ld.getConceptByName(names{k});
                    obj.ld.removeConcept(c);
                    obj.clearWorkspaceConcept(names{k});
                end
                obj.refreshConceptList();
            catch ME
                uialert(obj.fig, ME.message, 'Error clearing concepts');
            end
        end

        function onEditLabels(obj)
            name = obj.lstConcepts.Value;
            if isempty(name)
                uialert(obj.fig, 'Select a concept in the list first.', 'No selection');
                return
            end
            try
                c      = obj.ld.getConceptByName(name);
                defObj = strjoin(c.labels.objectives, ', ');
                defPar = strjoin(c.labels.parameters, ', ');

                % Non-blocking uifigure so the user can switch to other windows
                dlg = uifigure('Name', ['Labels — ' name], ...
                    'Position', [0 0 390 180], 'Resize', 'off');
                ss = get(0, 'ScreenSize');
                dlg.Position(1:2) = [round((ss(3)-390)/2), round((ss(4)-180)/2)];

                uilabel(dlg, ...
                    'Text', sprintf('Objectives  (%d — comma-separated):', c.pfdim), ...
                    'Position', [10 136 370 20]);
                edtObj = uieditfield(dlg, 'text', ...
                    'Position', [10 110 370 22], 'Value', defObj);

                uilabel(dlg, ...
                    'Text', sprintf('Parameters  (%d — comma-separated):', c.psdim), ...
                    'Position', [10 78 370 20]);
                edtPar = uieditfield(dlg, 'text', ...
                    'Position', [10 52 370 22], 'Value', defPar);

                uibutton(dlg, 'Text', 'OK', ...
                    'Position', [10 10 180 30], ...
                    'ButtonPushedFcn', @(~,~) obj.applyLabels(dlg, name, edtObj, edtPar));
                uibutton(dlg, 'Text', 'Cancel', ...
                    'Position', [200 10 180 30], ...
                    'ButtonPushedFcn', @(~,~) close(dlg));
            catch ME
                uialert(obj.fig, ME.message, 'Error opening label editor');
            end
        end

        function applyLabels(obj, dlg, conceptName, edtObj, edtPar)
            try
                c      = obj.ld.getConceptByName(conceptName);
                newObj = strtrim(strsplit(edtObj.Value, ','));
                newPar = strtrim(strsplit(edtPar.Value, ','));

                if numel(newObj) ~= c.pfdim
                    uialert(dlg, sprintf('Need %d objective labels, got %d.', ...
                        c.pfdim, numel(newObj)), 'Wrong count');
                    return
                end
                if numel(newPar) ~= c.psdim
                    uialert(dlg, sprintf('Need %d parameter labels, got %d.', ...
                        c.psdim, numel(newPar)), 'Wrong count');
                    return
                end

                obj.ld.setConceptLabels(c, newObj, newPar);
                close(dlg);
                obj.refreshConceptList();
            catch ME
                uialert(dlg, ME.message, 'Error setting labels');
            end
        end

        function onSyncTypeChanged(obj)
            tipo = obj.ddSyncType.Value;
            obj.pnlLp.Visible = strcmp(tipo, 'Norm');
            obj.pnlWs.Visible = strcmp(tipo, 'Workspace');
            if strcmp(tipo, 'Norm')
                obj.updateSyncLayout(58);
            else
                % Rebuild rows and cascade layout in one step
                obj.rebuildSyncWsPanel();
            end
        end

        function onSyncApply(obj)
            try
                switch obj.ddSyncType.Value
                    case 'Norm'
                        obj.ld.syncByNorm(obj.edtP.Value);

                    case 'Workspace'
                        names = obj.ld.getConceptNames();
                        vals  = cell(1, numel(names));
                        for k = 1:numel(names)
                            dd = findobj(obj.pnlWs, 'Tag', sprintf('wsrow_dd%d', k));
                            vals{k} = evalin('base', dd.Value);
                        end
                        obj.ld.syncBy(vals);
                end
            catch ME
                uialert(obj.fig, ME.message, 'Sync error');
            end
        end

        function onSyncReset(obj)
            try
                obj.ld.resetBounds();
            catch ME
                uialert(obj.fig, ME.message, 'Error resetting bounds');
            end
        end

        function onConceptChanged(obj)
            obj.refreshColorVars();
            obj.refreshSizeVars();
            obj.refreshSelectionVars();
            obj.refreshCallbackDisplay();
        end

        function onSelTypeChanged(obj)
            obj.refreshSelectionVars();
        end

        function onSelectByCondition(obj)
            try
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c    = obj.ld.getConceptByName(obj.activeConcept(names));
                data = obj.getSelectionData(c);
                if isempty(data); return; end
                idx  = obj.applySelOperator(data, obj.ddSelOp.Value, obj.edtSelVal.Value);
                obj.ld.selectPoints(c, idx);
            catch ME
                uialert(obj.fig, ME.message, 'Selection error');
            end
        end

        function onAddToSelection(obj)
            try
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c    = obj.ld.getConceptByName(obj.activeConcept(names));
                data = obj.getSelectionData(c);
                if isempty(data); return; end
                idx  = obj.applySelOperator(data, obj.ddSelOp.Value, obj.edtSelVal.Value);
                obj.ld.addToSelection(c, idx);
            catch ME
                uialert(obj.fig, ME.message, 'Selection error');
            end
        end

        function onClearSelection(obj)
            try
                obj.ld.clearSelection();
            catch ME
                uialert(obj.fig, ME.message, 'Error clearing selection');
            end
        end

        function onSelectFromWS(obj)
            varName = obj.ddSelIdx.Value;
            if ismember(varName, {'(none)', '(refresh ↺)'}); return; end
            try
                idx = evalin('base', varName);
                idx = idx(:);
                if ~isnumeric(idx)
                    uialert(obj.fig, ...
                        sprintf('"%s" must be a numeric vector.', varName), 'Type error');
                    return
                end
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c = obj.ld.getConceptByName(obj.activeConcept(names));
                obj.ld.selectPoints(c, idx);
            catch ME
                uialert(obj.fig, ME.message, 'Error selecting from workspace');
            end
        end

        function onColorApply(obj)
            if isempty(obj.colorVarMeta); return; end

            selVal = obj.ddColorVar.Value;
            idx    = find(strcmp(obj.ddColorVar.Items, selVal), 1);
            if isempty(idx); return; end
            m = obj.colorVarMeta{idx};
            if strcmp(m.type, 'sep'); return; end

            try
                names       = obj.ld.getConceptNames();
                if isempty(names); return; end
                conceptName = obj.activeConcept(names);
                c           = obj.ld.getConceptByName(conceptName);

                if strcmp(m.type, 'uniform')
                    obj.ld.colorBy(c, obj.uniformColor);
                    return
                end

                obj.updateColormapPreview(obj.ddColormap.Value);
                switch m.type
                    case 'obj'; data = c.objectives(:, m.index);
                    case 'par'; data = c.parameters(:, m.index);
                    case 'ws';  data = evalin('base', m.name);
                end
                obj.ld.colorBy(c, data, ...
                    'colormap',    obj.ddColormap.Value, ...
                    'reverseColor', obj.chkRevColor.Value);
            catch ME
                uialert(obj.fig, ME.message, 'Error applying color');
            end
        end

        function onSizeVarChanged(obj)
            isUnif = strcmp(obj.ddSizeVar.Value, 'Uniform');
            obj.pnlSizeUnif.Visible = isUnif;
            obj.pnlSizeVar.Visible  = ~isUnif;
            if ~isUnif; obj.onSizeApply(); end
        end

        function onSizeSlider(obj, src)
            obj.edtSize.Value = round(src.Value);
            obj.onSizeApply();
        end

        function onSizeEdit(obj, src)
            obj.sldSize.Value = src.Value;
            obj.onSizeApply();
        end

        function onSizeApply(obj)
            try
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                conceptName = obj.activeConcept(names);
                c = obj.ld.getConceptByName(conceptName);

                if strcmp(obj.ddSizeVar.Value, 'Uniform')
                    obj.ld.setSize(c, obj.edtSize.Value);
                    return
                end

                % Modo variable: escalar al rango [min, max] pts
                idx = find(strcmp(obj.ddSizeVar.Items, obj.ddSizeVar.Value), 1);
                if isempty(idx); return; end
                m = obj.sizeVarMeta{idx};
                if strcmp(m.type, 'sep') || strcmp(m.type, 'uniform'); return; end

                switch m.type
                    case 'obj'; data = c.objectives(:, m.index);
                    case 'par'; data = c.parameters(:, m.index);
                    case 'ws';  data = evalin('base', m.name);
                end
                lo   = obj.edtSizeMin.Value;
                hi   = obj.edtSizeMax.Value;
                dmin = min(data); dmax = max(data);
                if dmax > dmin
                    sizes = lo + (data - dmin) / (dmax - dmin) * (hi - lo);
                else
                    sizes = repmat((lo + hi)/2, numel(data), 1);
                end
                obj.ld.setSize(c, sizes);
            catch ME
                uialert(obj.fig, ME.message, 'Error changing size');
            end
        end

        function onMarkerChanged(obj)
            map = {'○  Circle','o'; '□  Square','s'; '△  Triangle','^'; ...
                   '◇  Diamond','d'; '▽  Inv. triangle','v'};
            row = strcmp(map(:,1), obj.ddMarker.Value);
            if ~any(row); return; end
            sym = map{row, 2};
            try
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c = obj.ld.getConceptByName(obj.activeConcept(names));
                obj.ld.setMarker(c, sym);
            catch ME
                uialert(obj.fig, ME.message, 'Error changing marker');
            end
        end


        function onAssignCallback(obj)
            fnStr = strtrim(obj.edtCbFn.Value);
            if isempty(fnStr)
                uialert(obj.fig, ...
                    'Enter a function name or @-expression first.', ...
                    'No function specified');
                return
            end
            try
                fn    = str2func(fnStr);
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c     = obj.ld.getConceptByName(obj.activeConcept(names));
                obj.ld.onSelect(c, fn);
                obj.refreshCallbackDisplay();
            catch ME
                uialert(obj.fig, ME.message, 'Error assigning callback');
            end
        end

        function onClearCallbacks(obj)
            try
                names = obj.ld.getConceptNames();
                if isempty(names); return; end
                c = obj.ld.getConceptByName(obj.activeConcept(names));
                obj.ld.clearCallbacks(c);
                obj.refreshCallbackDisplay();
            catch ME
                uialert(obj.fig, ME.message, 'Error clearing callbacks');
            end
        end

        function onColorVarModeChanged(obj)
            if isempty(obj.colorVarMeta); return; end
            idx = find(strcmp(obj.ddColorVar.Items, obj.ddColorVar.Value), 1);
            if isempty(idx); return; end
            m = obj.colorVarMeta{idx};
            isUnif = strcmp(m.type, 'uniform');
            obj.pnlColorMap.Visible  = ~isUnif;
            obj.pnlColorUnif.Visible = isUnif;
        end

        function onPickColor(obj)
            newColor = uisetcolor(obj.uniformColor, 'Select color');
            figure(obj.fig);  % restore panel focus after system dialog
            if isequal(newColor, 0); return; end
            obj.uniformColor = newColor;
            obj.btnColorPicker.BackgroundColor = newColor;
            obj.edtRgb.Value = obj.rgb2str(newColor);
        end

        function onCbBrowse(obj)
            [fname, fpath] = uigetfile('*.m', 'Select a .m file');
            if isequal(fname, 0); return; end
            [~, name, ~] = fileparts(fname);
            obj.edtCbFn.Value = name;
            addpath(fpath);
        end

        function onRgbEdit(obj)
            vals = str2num(obj.edtRgb.Value); %#ok<ST2NM>
            if numel(vals) == 3 && all(vals >= 0 & vals <= 1)
                obj.uniformColor = vals(:)';
                obj.btnColorPicker.BackgroundColor = obj.uniformColor;
            end
        end

        % =================================================================
        % UTILIDADES
        % =================================================================

        function clearWorkspaceConcept(~, varName)
            % Elimina del workspace base la variable del concepto, pero solo
            % si sigue apuntando a un Concept (para no borrar variables del usuario).
            if ~isvarname(varName); return; end
            try
                v = evalin('base', varName);
                if isa(v, 'Concept')
                    evalin('base', ['clear ' varName]);
                end
            catch
            end
        end

        function updateSyncLayout(obj, subH)
            % Resize the SYNC section to accommodate subH for the active sub-panel,
            % then reposition the CONCEPTS section and resize the figure accordingly.
            %
            % Layout inside pnlSync (y from bottom):
            %   y=5            : bottom of active sub-panel
            %   y=5+subH       : top of sub-panel  (= headerY - 8)
            %   y=5+subH+8     : bottom of header (Type + Reset row)
            %   y=5+subH+8+24  : top of header
            %   +26px title    : panel title area (font + border)
            %
            headerY  = 5 + subH + 8;
            newSyncH = headerY + 24 + 26;

            % Resize both sub-panels (only one is visible, both share the space)
            obj.pnlLp.Position(4) = subH;
            obj.pnlWs.Position(4) = subH;

            % Move the header row
            obj.pnlSyncHeader.Position(2) = headerY;

            % Resize SYNC section panel
            oldSyncH = obj.pnlSync.Position(4);
            if newSyncH == oldSyncH; return; end
            obj.pnlSync.Position(4) = newSyncH;

            % Reposition CONCEPTS section: keep 5px gap above SYNC
            syncY         = obj.pnlSync.Position(2);
            newConceptsY  = syncY + newSyncH + 5;
            obj.pnlConcepts.Position(2) = newConceptsY;

            % Resize figure to fit, keeping figure bottom fixed
            conceptsH  = obj.pnlConcepts.Position(4);
            newFigH    = newConceptsY + conceptsH + 18;
            oldFigH    = obj.fig.Position(4);
            if newFigH ~= oldFigH
                obj.fig.Position(2) = obj.fig.Position(2) - (newFigH - oldFigH);
                obj.fig.Position(4) = newFigH;
            end
        end

        function data = getSelectionData(obj, c)
            varLabel = obj.ddSelVar.Value;
            if strcmp(obj.ddSelType.Value, 'Objectives')
                colIdx = find(strcmp(c.labels.objectives, varLabel), 1);
                if isempty(colIdx); data = []; return; end
                data = c.objectives(:, colIdx);
            else
                colIdx = find(strcmp(c.labels.parameters, varLabel), 1);
                if isempty(colIdx); data = []; return; end
                data = c.parameters(:, colIdx);
            end
        end

        function idx = applySelOperator(~, data, op, val)
            switch op
                case '>';  idx = find(data >  val);
                case '<';  idx = find(data <  val);
                case '>='; idx = find(data >= val);
                case '<='; idx = find(data <= val);
                case '=='; idx = find(data == val);
                case '~='; idx = find(data ~= val);
                otherwise; idx = [];
            end
        end

        function name = activeConcept(obj, names)
            % Devuelve el nombre del concepto activo; si no es válido, devuelve el primero.
            if ismember(obj.ddConcept.Value, names)
                name = obj.ddConcept.Value;
            else
                name = names{1};
            end
        end

        function updateColormapPreview(obj, cmapName)
            try
                cmap = feval(cmapName, 256);
                img  = reshape(cmap, 1, 256, 3);
                cla(obj.axColorPreview);
                image(obj.axColorPreview, ...
                    'XData', [0 1], 'YData', [0 1], 'CData', img);
                obj.axColorPreview.XTick = [];
                obj.axColorPreview.YTick = [];
                obj.axColorPreview.XLim  = [0 1];
                obj.axColorPreview.YLim  = [0 1];
            catch
            end
        end

        function s = rgb2str(~, rgb)
            s = sprintf('%.2f  %.2f  %.2f', rgb(1), rgb(2), rgb(3));
        end

        function rgb = defaultConceptColor(obj, conceptName)
            names  = obj.ld.getConceptNames();
            idx    = find(strcmp(names, conceptName), 1);
            colors = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19;
                      0.49 0.18 0.56; 0.93 0.69 0.13; 0.30 0.75 0.93;
                      0.64 0.08 0.18];
            rgb    = colors(mod(idx-1, size(colors,1)) + 1, :);
        end

    end
end
