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
    % ── ACTIVE CONCEPT dropdown ──────────────────────────────────────────
    %   Selects which concept is targeted by the COLOR, SIZE and CALLBACK
    %   sections below.
    %
    % ── COLOR section ────────────────────────────────────────────────────
    %   "According to" dropdown:
    %     Uniform (base color) — solid colour chosen via the palette button
    %                            or by typing an RGB triplet (0–1 values).
    %     Concept objectives   — colour mapped to an objective column.
    %     Concept parameters   — colour mapped to a parameter column.
    %     Workspace            — colour mapped to a workspace vector.
    %   Choose a colormap, optionally invert it, then click "Apply color".
    %   "↺ Refresh panel from LD" reads back the current colour from the
    %   diagram and updates the picker/RGB field automatically.
    %
    % ── SIZE AND MARKER section ───────────────────────────────────────────
    %   Uniform : a slider sets a fixed marker size for all points.
    %   Variable: scales marker size between a min and max (pts) according
    %             to a selected variable.
    %   Marker shape: circle, square, triangle, diamond, inverted triangle.
    %
    % ── CALLBACK section ─────────────────────────────────────────────────
    %   Type a function name or @-expression in the text field, or click
    %   "..." to browse for a .m file.  "Assign" registers the callback
    %   with ld.onSelect(); "Remove callbacks" clears all callbacks for
    %   the active concept.
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
        btnAdd
        btnDraw

        % — SINCRONIZACIÓN —
        ddSyncType
        pnlLp           % sub-panel Norm
        edtP
        pnlWs           % sub-panel Workspace (dynamic rows)

        % — CONCEPTO ACTIVO —
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

            % Posicionar en el lado derecho de la pantalla
            panelW = 310; panelH = 920;
            ss     = get(0, 'ScreenSize');
            xPos   = ss(3) - panelW - 20;
            yPos   = max(10, round((ss(4) - panelH) / 2));

            obj.fig = uifigure( ...
                'Name',     figTitle, ...
                'Position', [xPos yPos panelW panelH], ...
                'Resize',   'off');

            M = 8; W = 294;
            obj.buildRefreshButton(   M,   5, W);
            obj.buildCallbackSection( M,  36, W);
            obj.buildSizeSection(     M, 151, W);
            obj.buildColorSection(    M, 294, W);
            obj.buildConceptSelector( M, 499, W);
            obj.buildSyncSection(     M, 552, W);
            obj.buildConceptsSection( M, 669, W);
        end

        % -----------------------------------------------------------------
        % SECCIÓN: CONCEPTOS
        % -----------------------------------------------------------------
        function buildConceptsSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'CONCEPTS', ...
                'FontWeight', 'bold', 'Position', [x y W 238]);

            obj.lstConcepts = uilistbox(pnl, ...
                'Position', [5 167 280 46], ...
                'Items', {}, 'Multiselect', 'off');

            uibutton(pnl, 'Text', '✎ Edit labels...', ...
                'Position', [5 141 280 22], ...
                'Tooltip', 'Set objective and parameter labels for the selected concept', ...
                'ButtonPushedFcn', @(~,~) obj.onEditLabels());

            uilabel(pnl, 'Text', 'Name', 'Position', [5 115 42 20]);
            obj.edtName = uieditfield(pnl, 'text', ...
                'Position', [52 115 228 22], 'Value', 'new');

            uilabel(pnl, 'Text', 'PF', 'Position', [5 88 20 20]);
            obj.ddPF = uidropdown(pnl, ...
                'Position', [30 88 228 22], 'Items', {'(refresh ↺)'});
            uibutton(pnl, 'Text', '↺', 'Position', [263 88 22 22], ...
                'Tooltip', 'Refresh workspace matrices', ...
                'ButtonPushedFcn', @(~,~) obj.refreshWorkspaceMatrices());

            uilabel(pnl, 'Text', 'PS', 'Position', [5 63 20 20]);
            obj.ddPS = uidropdown(pnl, ...
                'Position', [30 63 255 22], 'Items', {'(refresh ↺)'});

            uibutton(pnl, 'Text', '✕ Remove selected', ...
                'Position', [5 36 148 22], ...
                'Tooltip', 'Remove the selected concept from the LD', ...
                'ButtonPushedFcn', @(~,~) obj.onRemoveConcept());
            uibutton(pnl, 'Text', 'Clear all', ...
                'Position', [158 36 127 22], ...
                'Tooltip', 'Remove all concepts from the LD', ...
                'ButtonPushedFcn', @(~,~) obj.onClearAllConcepts());

            obj.btnAdd = uibutton(pnl, 'Text', '+ Add concept', ...
                'Position', [5 5 148 26], ...
                'ButtonPushedFcn', @(~,~) obj.onAddConcept());
            obj.btnDraw = uibutton(pnl, 'Text', '▶ Draw', ...
                'Position', [158 5 127 26], ...
                'BackgroundColor', [0.18 0.55 0.18], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.onDraw());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: SINCRONIZACIÓN EJE Y
        % -----------------------------------------------------------------
        function buildSyncSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'Y-AXIS SYNC', ...
                'FontWeight', 'bold', 'Position', [x y W 112]);

            % Top row: type + Reset (always visible)
            uilabel(pnl, 'Text', 'Type', 'Position', [5 68 30 20]);
            obj.ddSyncType = uidropdown(pnl, ...
                'Position', [40 68 175 22], ...
                'Items', {'Norm', 'Workspace'}, ...
                'ValueChangedFcn', @(~,~) obj.onSyncTypeChanged());
            uibutton(pnl, 'Text', 'Reset bounds', ...
                'Position', [220 68 68 22], ...
                'ButtonPushedFcn', @(~,~) obj.onSyncReset());

            % Two sub-panels at the same position; only one visible at a time.
            subX = 4; subW = 282; subY = 5; subH = 58;

            % ··· Sub-panel: Norm (visible by default) ·····················
            obj.pnlLp = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [subX subY subW subH]);
            uilabel(obj.pnlLp, 'Text', 'p =', 'Position', [5 18 25 20]);
            obj.edtP = uieditfield(obj.pnlLp, 'numeric', ...
                'Position', [35 18 55 22], 'Value', 2, 'Limits', [1 Inf]);
            uibutton(obj.pnlLp, 'Text', 'Apply', ...
                'Position', [100 18 174 22], ...
                'ButtonPushedFcn', @(~,~) obj.onSyncApply());

            % ··· Sub-panel: Workspace (dynamic rows) ······················
            % Apply button has fixed Tag; rebuildSyncWsPanel only deletes
            % elements whose Tag starts with 'wsrow_'.
            obj.pnlWs = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [subX subY subW subH], 'Visible', 'off');
            uibutton(obj.pnlWs, 'Text', 'Apply', ...
                'Position', [180 5 98 22], 'Tag', 'ws_aplicar', ...
                'ButtonPushedFcn', @(~,~) obj.onSyncApply());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: CONCEPTO ACTIVO (selector)
        % -----------------------------------------------------------------
        function buildConceptSelector(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'ACTIVE CONCEPT', ...
                'FontWeight', 'bold', 'Position', [x y W 48]);
            obj.ddConcept = uidropdown(pnl, ...
                'Position', [5 4 280 22], ...
                'Items', {'(no concepts)'}, ...
                'ValueChangedFcn', @(~,~) obj.onConceptChanged());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: COLOR
        % -----------------------------------------------------------------
        function buildColorSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'COLOR', ...
                'FontWeight', 'bold', 'Position', [x y W 200]);

            % Color variable row — y=152 keeps it below the title bar
            uilabel(pnl, 'Text', 'According to', 'Position', [5 152 80 20]);
            obj.ddColorVar = uidropdown(pnl, ...
                'Position', [90 152 172 22], ...
                'Items', {'(no concepts)'}, ...
                'ValueChangedFcn', @(~,~) obj.onColorVarModeChanged());
            uibutton(pnl, 'Text', '↺', 'Position', [267 152 22 22], ...
                'Tooltip', 'Refresh workspace variables', ...
                'ButtonPushedFcn', @(~,~) obj.refreshColorVars());

            % ··· Sub-panel: colormap mode (visible by default) ············
            % h=110 keeps top (38+110=148) below the "According to" row (y=152)
            obj.pnlColorMap = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [4 38 282 110]);
            uilabel(obj.pnlColorMap, 'Text', 'Colormap', 'Position', [1 84 58 20]);
            obj.ddColormap = uidropdown(obj.pnlColorMap, ...
                'Position', [64 84 218 22], ...
                'Items', {'parula','jet','hot','cool','gray','turbo','winter','summer','copper'});
            obj.chkRevColor = uicheckbox(obj.pnlColorMap, ...
                'Text', 'Invert colormap', 'Position', [1 62 130 20]);
            obj.axColorPreview = uiaxes(obj.pnlColorMap, 'Position', [1 28 280 26]);
            obj.axColorPreview.XTick = []; obj.axColorPreview.YTick = [];
            obj.axColorPreview.XLim  = [0 1]; obj.axColorPreview.YLim = [0 1];
            disableDefaultInteractivity(obj.axColorPreview);
            obj.updateColormapPreview('parula');
            uilabel(obj.pnlColorMap, 'Text', 'min', 'Position', [1 8 25 16], ...
                'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);
            uilabel(obj.pnlColorMap, 'Text', 'max', 'Position', [257 8 28 16], ...
                'FontSize', 9, 'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'right');

            % ··· Sub-panel: uniform color mode (hidden by default) ········
            obj.pnlColorUnif = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [4 38 282 110], 'Visible', 'off');
            uilabel(obj.pnlColorUnif, 'Text', 'Palette', 'Position', [1 82 42 20]);
            obj.btnColorPicker = uibutton(obj.pnlColorUnif, ...
                'Text', 'Pick color...', 'Position', [48 80 228 24], ...
                'BackgroundColor', obj.uniformColor, ...
                'Tooltip', 'Open color picker dialog', ...
                'ButtonPushedFcn', @(~,~) obj.onPickColor());
            uilabel(obj.pnlColorUnif, 'Text', 'RGB', 'Position', [1 52 30 20]);
            obj.edtRgb = uieditfield(obj.pnlColorUnif, 'text', ...
                'Position', [36 52 240 22], ...
                'Value', obj.rgb2str(obj.uniformColor), ...
                'Placeholder', 'e.g.  0.2  0.5  0.8', ...
                'Tooltip', 'Type three values 0–1 separated by spaces', ...
                'ValueChangedFcn', @(~,~) obj.onRgbEdit());

            % Apply button (always visible)
            uibutton(pnl, 'Text', 'Apply color', ...
                'Position', [5 8 280 24], ...
                'ButtonPushedFcn', @(~,~) obj.onColorApply());
        end

        % -----------------------------------------------------------------
        % SECCIÓN: TAMAÑO Y MARCADOR
        % -----------------------------------------------------------------
        function buildSizeSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'SIZE AND MARKER', ...
                'FontWeight', 'bold', 'Position', [x y W 138]);

            % Size variable
            uilabel(pnl, 'Text', 'Variable', 'Position', [5 95 52 20]);
            obj.ddSizeVar = uidropdown(pnl, ...
                'Position', [62 95 200 22], ...
                'Items', {'Uniform'}, ...
                'ValueChangedFcn', @(~,~) obj.onSizeVarChanged());
            uibutton(pnl, 'Text', '↺', 'Position', [267 95 22 22], ...
                'Tooltip', 'Refresh workspace variables', ...
                'ButtonPushedFcn', @(~,~) obj.refreshSizeVars());

            % Sub-panel: Uniforme (slider)
            obj.pnlSizeUnif = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [4 42 282 50]);
            obj.sldSize = uislider(obj.pnlSizeUnif, ...
                'Position', [8 30 210 3], ...
                'Limits', [1 150], 'Value', 36, ...
                'MajorTicks', [1 50 100 150], ...
                'MinorTicks', [], ...
                'ValueChangedFcn', @(src,~) obj.onSizeSlider(src));
            obj.edtSize = uieditfield(obj.pnlSizeUnif, 'numeric', ...
                'Position', [230 22 47 22], 'Value', 36, ...
                'Limits', [1 150], ...
                'ValueChangedFcn', @(src,~) obj.onSizeEdit(src));
            uilabel(obj.pnlSizeUnif, 'Text', 'pts', ...
                'Position', [230 5 35 16], 'FontSize', 9, ...
                'FontColor', [0.5 0.5 0.5]);

            % Sub-panel: Variable (rango de pts)
            obj.pnlSizeVar = uipanel(pnl, 'BorderType', 'none', ...
                'Position', [4 42 282 50], 'Visible', 'off');
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

            % Marker
            uilabel(pnl, 'Text', 'Marker', 'Position', [5 12 58 20]);
            obj.ddMarker = uidropdown(pnl, ...
                'Position', [68 12 221 22], ...
                'Items', {'○  Circle','□  Square','△  Triangle', ...
                          '◇  Diamond','▽  Inv. triangle'}, ...
                'ValueChangedFcn', @(~,~) obj.onMarkerChanged());
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

        % -----------------------------------------------------------------
        % SECCIÓN: CALLBACKS
        % -----------------------------------------------------------------
        function buildCallbackSection(obj, x, y, W)
            pnl = uipanel(obj.fig, 'Title', 'CALLBACK', ...
                'FontWeight', 'bold', 'Position', [x y W 110]);

            % Callback registrado actualmente (solo lectura)
            uilabel(pnl, 'Text', 'Current:', ...
                'Position', [5 68 48 18], 'FontSize', 9, ...
                'FontColor', [0.4 0.4 0.4]);
            obj.lblCurrentCb = uilabel(pnl, ...
                'Text', '(none)', ...
                'Position', [58 65 228 22], ...
                'FontSize', 9, 'FontColor', [0.25 0.25 0.25], ...
                'WordWrap', 'on', 'Interpreter', 'none');

            % Campo de texto: nombre de función o expresión @
            obj.edtCbFn = uieditfield(pnl, 'text', ...
                'Position', [5 38 248 22], ...
                'Value', '', ...
                'Placeholder', 'myFunction  or  @(p) expr', ...
                'Tooltip', 'Function name or @-expression. Use [...] to browse a .m file.');
            obj.btnCbBrowse = uibutton(pnl, 'Text', '...', ...
                'Position', [258 38 30 22], ...
                'Tooltip', 'Browse for a .m file', ...
                'ButtonPushedFcn', @(~,~) obj.onCbBrowse());

            % Botones acción
            obj.btnAssignCb = uibutton(pnl, 'Text', '+ Assign', ...
                'Position', [5 8 130 24], ...
                'ButtonPushedFcn', @(~,~) obj.onAssignCallback());
            obj.btnClearCb = uibutton(pnl, 'Text', 'Remove callbacks', ...
                'Position', [142 8 145 24], ...
                'ButtonPushedFcn', @(~,~) obj.onClearCallbacks());
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
                obj.rebuildSyncWsPanel();
                obj.refreshCallbackDisplay();
            end
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
            % Borra solo las filas dinámicas (Tag empieza por 'wsrow_'),
            % preservando el botón Aplicar fijo (Tag 'ws_aplicar').
            kids = obj.pnlWs.Children;
            for k = 1:numel(kids)
                if startsWith(kids(k).Tag, 'wsrow_')
                    delete(kids(k));
                end
            end
            names = obj.ld.getConceptNames();
            rowH  = 26; gap = 4;
            wsVars = obj.getWorkspaceVectors(0);
            % Las filas se apilan de arriba a abajo empezando en y=32
            % (por encima del botón Aplicar fijo en y=5)
            for k = 1:numel(names)
                yRow = 32 + (numel(names) - k) * (rowH + gap);
                uilabel(obj.pnlWs, 'Text', names{k}, ...
                    'Position', [5 yRow 68 20], ...
                    'Tag', sprintf('wsrow_lbl%d', k));
                uidropdown(obj.pnlWs, ...
                    'Position', [78 yRow 158 22], ...
                    'Items', wsVars, ...
                    'Tag', sprintf('wsrow_dd%d', k));
                uibutton(obj.pnlWs, 'Text', '↺', ...
                    'Position', [241 yRow 22 22], ...
                    'Tag', sprintf('wsrow_ref%d', k), ...
                    'ButtonPushedFcn', @(~,~) obj.rebuildSyncWsPanel());
            end
        end

        % =================================================================
        % CALLBACKS
        % =================================================================

        function onAddConcept(obj)
            try
                pf   = evalin('base', obj.ddPF.Value);
                ps   = evalin('base', obj.ddPS.Value);
                name = strtrim(obj.edtName.Value);
                if isempty(name); name = obj.ddPF.Value; end
                c = Concept(pf, ps, name);
                obj.ld.addConcept(c);
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
                obj.refreshConceptList();
            catch ME
                uialert(obj.fig, ME.message, 'Error removing concept');
            end
        end

        function onClearAllConcepts(obj)
            try
                names = obj.ld.getConceptNames();
                for k = 1:numel(names)
                    c = obj.ld.getConceptByName(names{k});
                    obj.ld.removeConcept(c);
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
            obj.refreshCallbackDisplay();
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
