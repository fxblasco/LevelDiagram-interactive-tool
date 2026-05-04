classdef LevelDiagram < handle
    % LevelDiagram - Clase para visualizar y analizar conceptos de Pareto
    % mediante Level Diagrams
    %
    % Uso:
    %   ld = LevelDiagram('ld1')
    %   ld.addConcept(c1, bounds, 2)
    %   ld.draw()
    %
    % Nota: hereda de handle para que los cambios en las propiedades
    % se reflejen automáticamente en todas las referencias al objeto

    properties
        name        (1,:) char    = ''     % Nombre del Level Diagram
        syncLabel   (1,:) char    = 'f_{sync}'  % Etiqueta del eje Y de sincronización
    end

    properties (SetAccess = private, GetAccess = public)
        globalBounds double        = []     % Bounds globales de todos los conceptos [max;min]
        globalNorm   (1,1) double  = 2      % Norma p global (1, 2, inf, ...)
    end

    properties (Access = private)
        concepts    cell          = {}     % Cell array de objetos Concept
        syncValues  cell          = {}     % Cell array de vectores de sincronización (nind x 1)
        colorData   cell          = {}     % Cell array de datos de color por concepto
        sizeData    cell          = {}     % Cell array de datos de tamaño por concepto
        markerData  cell          = {}     % Cell array de marcadores por concepto
        sortOrder   cell          = {}     % Cell array de vectores de orden de trazado por concepto
        callbacks   cell          = {}     % Cell array de {conceptIdx, callback}
        selection   cell          = {}    % Cell array de struct {conceptIdx, indices} por concepto

        % Handles gráficos
        figObjectives   = []              % Handle figura de objetivos
        figsParameters  cell  = {}        % Cell array de handles de figuras de parámetros
        axesObjectives  cell  = {}        % Cell array de axes de objetivos
        axesParameters  cell  = {}        % Cell array de axes de parámetros por concepto
        scatterObjectives cell = {}       % Handles scatter objetivos por concepto
        scatterParameters cell = {}       % Handles scatter parámetros por concepto
        scatterHighlightObj  cell = {}    % Handles scatter de resaltado (uno por concepto)
        checkboxHandles      cell = {}    % Handles checkboxes de visibilidad por concepto
        colorbarHandles      cell = {}    % Handles colorbar por concepto (figura parámetros)
        colorbarRefAxes      cell = {}    % Axes de referencia para el colorbar
        colorbarLabels       cell = {}    % Handles de la etiqueta del colorbar por concepto
        figPanel        = []              % Handle figura panel de información
        panelTables     cell = {}         % Cell array de uitables, una por concepto
        panelLabels     cell = {}         % Cell array de uicontrol text, una por concepto
        panelButtons    cell = {}         % Cell array de botones {ejecutar,csv,ws} por concepto
        conceptVisible  logical = []     % visibilidad por concepto (true = visible)
        isDragging      logical = false
        dragStart       = []
        dragRect        = []    % handle del rectángulo de selección
        shiftDown       logical = false  % estado de Shift al hacer mouseDown
    end

    properties (Constant, Access = private)
        DEFAULT_MARKERS     = {'o','s','^','d','v','p','h'}
        DEFAULT_SIZE        = 36
        DEFAULT_COLORMAP    = 'parula'
        HIGHLIGHT_COLOR     = [0.4 0.0 0.4]   
        HIGHLIGHT_SIZE      = 100
        HIGHLIGHT_FACE_COLOR = [0.4 0.0 0.4]      % color relleno resaltado (RGB)
        HIGHLIGHT_FACE_ALPHA = 0.3        % transparencia relleno resaltado [0-1]
        % Colores por defecto para cada concepto
        DEFAULT_COLORS      = [0.00 0.45 0.74;   % azul
            0.85 0.33 0.10;   % naranja
            0.47 0.67 0.19;   % verde
            0.49 0.18 0.56;   % morado
            0.93 0.69 0.13;   % amarillo
            0.30 0.75 0.93;   % cyan
            0.64 0.08 0.18]   % rojo oscuro
    end

    methods
        %% Constructor
        function obj = LevelDiagram(name)
            % LevelDiagram - Constructor
            %
            % Entradas:
            %   name - Nombre del Level Diagram

            if nargin >= 1
                obj.validateName(name);
                obj.name = name;
            end
        end

        %% Setter de syncLabel
        function set.syncLabel(obj, label)
            obj.syncLabel = label;
            % Actualizar etiquetas en ejes ya dibujados
            if ~isempty(obj.axesObjectives)
                for j = 1:numel(obj.axesObjectives)
                    if ~isempty(obj.axesObjectives{j}) && isvalid(obj.axesObjectives{j})
                        ylabel(obj.axesObjectives{j}, label);
                    end
                end
            end
            if ~isempty(obj.axesParameters)
                for i = 1:numel(obj.axesParameters)
                    for j = 1:numel(obj.axesParameters{i})
                        if ~isempty(obj.axesParameters{i}{j}) && isvalid(obj.axesParameters{i}{j})
                            ylabel(obj.axesParameters{i}{j}, label);
                        end
                    end
                end
            end
        end

        %% Gestión de conceptos
        function addConcept(obj, concept)
            % Añade un concepto al Level Diagram
            % Los bounds globales se recalculan automáticamente y se
            % recalcula f_sync de todos los conceptos con norma 2
            %
            % Uso:
            %   ld.addConcept(c1)
            %   ld.addConcept(c2)   % recalcula bounds y sync de c1 y c2

            % Validar concept
            obj.validateConcept(concept);

            if isempty(concept.name)
                error('LevelDiagram:addConcept:emptyName', ...
                    'El concepto debe tener un nombre para añadirlo a un Level Diagram.');
            end

            if obj.conceptExists(concept)
                error('LevelDiagram:addConcept:duplicateConcept', ...
                    'Ya existe un concepto con el nombre "%s" en este Level Diagram.', ...
                    concept.name);
            end

            % Añadir concepto con sync provisional (se recalcula abajo)
            obj.concepts{end+1}   = concept;
            obj.syncValues{end+1} = zeros(concept.nind, 1);

            % Valores por defecto de visualización
            nC = numel(obj.concepts);
            colorIdx = mod(nC-1, size(obj.DEFAULT_COLORS,1)) + 1;
            obj.colorData{end+1}  = obj.DEFAULT_COLORS(colorIdx,:);
            obj.sizeData{end+1}   = obj.DEFAULT_SIZE;
            markerIdx = mod(nC-1, numel(obj.DEFAULT_MARKERS)) + 1;
            obj.markerData{end+1} = obj.DEFAULT_MARKERS{markerIdx};
            obj.sortOrder{end+1}       = (1:concept.nind)';
            obj.conceptVisible(end+1)  = true;
            obj.colorbarHandles{end+1} = [];
            obj.colorbarRefAxes{end+1} = [];
            obj.colorbarLabels{end+1}  = [];

            % Recalcular bounds globales y sync de TODOS los conceptos
            obj.recalcGlobalBoundsAndSync();
        end

        function removeConcept(obj, concept)
            % Elimina un concepto del Level Diagram
            % Recalcula bounds globales y sync del resto de conceptos
            idx = obj.getConceptIndex(concept);
            obj.concepts(idx)          = [];
            obj.syncValues(idx)        = [];
            obj.colorData(idx)         = [];
            obj.sizeData(idx)          = [];
            obj.markerData(idx)        = [];
            obj.sortOrder(idx)         = [];
            obj.conceptVisible(idx)    = [];
            obj.colorbarHandles(idx)   = [];
            obj.colorbarRefAxes(idx)   = [];
            obj.colorbarLabels(idx)    = [];

            % Cerrar figura de parámetros del concepto eliminado
            if ~isempty(obj.figsParameters) && idx <= numel(obj.figsParameters)
                if isvalid(obj.figsParameters{idx})
                    close(obj.figsParameters{idx});
                end
                obj.figsParameters(idx) = [];
            end

            % Eliminar scatter de objetivos del concepto borrado
            if ~isempty(obj.scatterObjectives) && size(obj.scatterObjectives,1) >= idx
                for j = 1:size(obj.scatterObjectives, 2)
                    if ~isempty(obj.scatterObjectives{idx,j}) && isvalid(obj.scatterObjectives{idx,j})
                        delete(obj.scatterObjectives{idx,j});
                    end
                end
                obj.scatterObjectives(idx,:) = [];
            end
            if ~isempty(obj.scatterParameters) && numel(obj.scatterParameters) >= idx
                obj.scatterParameters(idx) = [];
            end
            if ~isempty(obj.axesParameters) && numel(obj.axesParameters) >= idx
                obj.axesParameters(idx) = [];
            end

            % Eliminar y reconstruir checkboxes en figura de objetivos
            if ~isempty(obj.checkboxHandles)
                % Eliminar todos los checkboxes actuales
                for k = 1:numel(obj.checkboxHandles)
                    cb = obj.checkboxHandles{k};
                    if ~isempty(cb) && isvalid(cb)
                        delete(cb.Parent);  % elimina el uipanel contenedor
                    end
                end
                obj.checkboxHandles = {};
                % Recrear checkboxes con los conceptos restantes
                if ~isempty(obj.concepts) && ~isempty(obj.figObjectives) && isvalid(obj.figObjectives)
                    obj.rebuildCheckboxes();
                end
            end

            % Recalcular bounds globales y sync del resto
            if ~isempty(obj.concepts)
                obj.recalcGlobalBoundsAndSync();
            end

            % Reconstruir panel de info con los conceptos actuales
            obj.rebuildInfoPanel();

            % Limpiar selección (puede referenciar el concepto eliminado)
            obj.selection = {};
            obj.updateHighlightsMultiple([]);
        end

        %% Etiqueta eje Y
        function setSyncLabel(obj, label)
            % Cambia la etiqueta del eje Y de sincronización en todas las figuras
            %
            % Uso:
            %   ld.setSyncLabel('Norma 2')
            %   ld.setSyncLabel('Quality Indicator')
            obj.syncLabel = label;
            obj.updateSyncLabels();
        end

        %% Sincronización eje Y
        function syncByNorm(obj, p, bounds)
            % Recalcula la sincronización de TODOS los conceptos con norma p
            %
            % Uso:
            %   ld.syncByNorm(2)           % norma 2 con bounds globales actuales
            %   ld.syncByNorm(1)           % norma 1
            %   ld.syncByNorm(inf)         % norma infinito
            %   ld.syncByNorm(2, myBounds) % norma 2 con bounds personalizados

            if nargin < 2; p = 2; end

            if nargin >= 3
                % Bounds personalizados
                pfdim = obj.concepts{1}.pfdim;
                obj.validateBounds(bounds, pfdim);
                obj.globalBounds = bounds;
            end

            obj.globalNorm = p;

            % Recalcular sync para todos los conceptos
            for i = 1:numel(obj.concepts)
                obj.syncValues{i} = obj.computeNorm(...
                    obj.concepts{i}.objectives, obj.globalBounds, p);
                obj.updateYAxis(i);
            end
            obj.rescaleYAxes();
        end

        function resetBounds(obj)
            % Restaura los bounds globales automaticos
            % (maximo de maxpf y minimo de minpf de todos los conceptos)
            % y recalcula f_sync de todos con la norma actual
            %
            % Uso:
            %   ld.resetBounds()
            if isempty(obj.concepts)
                obj.globalBounds = [];
                return;
            end
            maxPF = obj.concepts{1}.maxpf;
            minPF = obj.concepts{1}.minpf;
            for i = 2:numel(obj.concepts)
                maxPF = max([maxPF; obj.concepts{i}.maxpf]);
                minPF = min([minPF; obj.concepts{i}.minpf]);
            end
            obj.globalBounds = [maxPF; minPF];
            obj.recalcGlobalBoundsAndSync();
        end

        function syncBy(obj, values)
            % Cambia la sincronización de TODOS los conceptos con indicadores externos
            % El usuario debe pasar un cell array con un vector por concepto,
            % en el mismo orden en que se añadieron con addConcept
            %
            % Uso:
            %   ld.syncBy({QI_pid, QI_gpc})         % 2 conceptos
            %   ld.syncBy({QI_pid, QI_gpc, QI_mpc}) % 3 conceptos

            if ~iscell(values)
                error('LevelDiagram:syncBy:invalidInput', ...
                    'syncBy requiere un cell array. Uso: ld.syncBy({QI_c1, QI_c2, ...})');
            end

            nC = numel(obj.concepts);
            if numel(values) ~= nC
                error('LevelDiagram:syncBy:wrongSize', ...
                    'Se esperan %d vectores (uno por concepto), se han pasado %d.', ...
                    nC, numel(values));
            end

            for i = 1:nC
                obj.validateSyncValues(values{i}, obj.concepts{i}.nind);
                obj.syncValues{i} = values{i}(:);
                obj.updateYAxis(i);
            end
            obj.rescaleYAxes();
        end

        %% Coloreado
        function colorBy(obj, concept, input, varargin)
            % Asigna colores a los puntos del concepto
            %
            % Uso:
            %   ld.colorBy(c, indicador)                           % vector nind x 1 -> colormap
            %   ld.colorBy(c, indicador, 'colormap', 'hot')        % colormap específico
            %   ld.colorBy(c, indicador, 'reverseColor', true)     % invertir colores del mapa
            %   ld.colorBy(c, indicador, 'reverseInd',  true)      % alto indicador = más importante
            %   ld.colorBy(c, indicador, 'clim', [0 100])          % límites fijos
            %   ld.colorBy(c, indicador, 'label', 'IAE')           % etiqueta del colorbar
            %   ld.colorBy(c, colores_rgb)                         % matriz nind x 3: color por punto
            %   ld.colorBy(c, [r g b])                             % vector 1x3: color único para todos

            idx = obj.getConceptIndex(concept);

            if obj.isSingleRGB(input)
                % CASO 3: color RGB único -> orden de trazado sin importancia
                colores = repmat(input(:)', concept.nind, 1);
                obj.sortOrder{idx} = (1:concept.nind)';
                obj.hideColorbar(idx);

            elseif obj.isRGBMatrix(input, concept.nind)
                % CASO 2: matriz RGB nind x 3 -> orden de trazado sin importancia
                colores = input;
                obj.sortOrder{idx} = (1:concept.nind)';
                obj.hideColorbar(idx);

            elseif isvector(input) && numel(input) == concept.nind
                % CASO 1: indicador escalar -> ordenar según importancia
                p = inputParser();
                p.addParameter('colormap',    obj.DEFAULT_COLORMAP);
                p.addParameter('reverseColor', false);  % invierte colores del mapa
                p.addParameter('reverseInd',   false);  % true: alto=mejor=encima
                p.addParameter('clim',         []);
                p.addParameter('label',        '');
                p.parse(varargin{:});

                % Pasar reverseColor a indicatorToColors (renombrado de 'reverse')
                colores = obj.indicatorToColors(input, ...
                    'colormap', p.Results.colormap, ...
                    'reverse',  p.Results.reverseColor, ...
                    'clim',     p.Results.clim);

                % Por defecto bajo=mejor=encima ('descend'); reverseInd invierte
                if p.Results.reverseInd
                    [~, obj.sortOrder{idx}] = sort(input(:), 'ascend');
                else
                    [~, obj.sortOrder{idx}] = sort(input(:), 'descend');
                end

                climVals = p.Results.clim;
                if isempty(climVals)
                    climVals = [min(input), max(input)];
                end
                obj.updateColorbar(idx, climVals, p.Results.colormap, ...
                    p.Results.reverseColor, p.Results.label);

            else
                error('LevelDiagram:colorBy:invalidInput', ...
                    ['El input debe ser:\n' ...
                     '  - vector de %d elementos (indicador)\n' ...
                     '  - matriz %d x 3 (RGB por punto)\n' ...
                     '  - vector [r g b] (color único)'], ...
                    concept.nind, concept.nind);
            end

            obj.colorData{idx} = colores;
            obj.updateColors(idx);
        end

        %% Tamaño
        function setSize(obj, concept, sizes)
            % Asigna tamaños a los puntos del concepto
            %
            % Uso:
            %   ld.setSize(c, 50)              % escalar: todos igual
            %   ld.setSize(c, vector_tamaños)  % por punto

            idx = obj.getConceptIndex(concept);

            if isscalar(sizes)
                obj.sizeData{idx} = sizes;
            elseif isvector(sizes) && numel(sizes) == concept.nind
                obj.sizeData{idx} = sizes(:);
            else
                error('LevelDiagram:setSize:invalidInput', ...
                    'sizes debe ser un escalar o un vector de %d elementos.', ...
                    concept.nind);
            end
            obj.updateSizes(idx);
        end

        %% Marcadores
        function setMarker(obj, concept, marker)
            % Cambia el marcador del concepto
            %
            % Uso:
            %   ld.setMarker(c, 'o')   % círculo
            %   ld.setMarker(c, 's')   % cuadrado
            %   ld.setMarker(c, '^')   % triángulo
            %   ld.setMarker(c, 'h')   % hexágono

            validMarkers = {'o','s','^','v','>','<','p','h','d','+','*'};
            if ~ismember(marker, validMarkers)
                error('LevelDiagram:setMarker:invalidMarker', ...
                    'Marcador no válido. Opciones: %s', strjoin(validMarkers, ', '));
            end
            idx = obj.getConceptIndex(concept);
            obj.markerData{idx} = marker;
            obj.updateMarkers(idx);
        end

        %% Callbacks de usuario
        function onSelect(obj, concept, callback)
            % Registra un callback para un concepto específico
            %
            % Uso:
            %   ld.onSelect(c1, @simularPID)
            %   ld.onSelect(c2, @simularGPC)
            %
            % La función recibe una estructura con:
            %   punto.concept      - nombre del concepto
            %   punto.index        - índice del punto
            %   punto.objectives   - valores de los objetivos
            %   punto.parameters   - valores de los parámetros
            %   punto.sync         - valor de sincronización
            %   punto.labels       - etiquetas

            if ~isa(callback, 'function_handle')
                error('LevelDiagram:onSelect:invalidCallback', ...
                    'El callback debe ser un function handle.');
            end
            obj.validateConcept(concept);
            conceptIdx = obj.getConceptIndex(concept);
            obj.callbacks{end+1} = struct('conceptIdx', conceptIdx, ...
                                          'func',       callback);
        end

        function clearCallbacks(obj, concept)
            % Elimina callbacks. Sin argumento elimina todos.
            % Con concepto elimina solo los de ese concepto.
            if nargin < 2
                obj.callbacks = {};
            else
                conceptIdx = obj.getConceptIndex(concept);
                keep = true(1, numel(obj.callbacks));
                for k = 1:numel(obj.callbacks)
                    if obj.callbacks{k}.conceptIdx == conceptIdx
                        keep(k) = false;
                    end
                end
                obj.callbacks = obj.callbacks(keep);
            end
        end

        %% Dibujar
        function draw(obj)
            % Dibuja el Level Diagram completo

            if isempty(obj.concepts)
                error('LevelDiagram:draw:noConcepts', ...
                    'No hay conceptos añadidos al Level Diagram.');
            end

            % Calcular layout de figuras antes de crearlas
            nFigs    = 1 + numel(obj.concepts) + 1; % obj + params + panel
            positions = obj.computeFigureLayout(nFigs);

            % Crear figura de objetivos (compartida por todos los conceptos)
            obj.createObjectivesFigure(positions{1});

            % Crear figura de parámetros por cada concepto
            for i = 1:numel(obj.concepts)
                obj.createParametersFigure(i, positions{1+i});
            end

            % Crear panel de información
            obj.createInfoPanel(positions{end});

            % Aplicar sortOrder, colores y tamaños actuales a los scatter
            % recién creados (draw() dibuja en orden original; updateColors
            % reordena XData e YData de forma consistente)
            for i = 1:numel(obj.concepts)
                obj.updateColors(i);
            end
        end

        %% Exportación
        function subset = exportSelection(obj, concept, name)
            % Exporta la selección de un concepto como nuevo Concept
            % Acepta un objeto Concept o un índice numérico
            %
            % Uso:
            %   subset = ld.exportSelection(c1)
            %   subset = ld.exportSelection(c1, 'mi_subset')

            % Resolver índice numérico si se pasa un Concept
            if isa(concept, 'Concept')
                conceptIdx = obj.getConceptIndex(concept);
            else
                conceptIdx = concept;
            end

            if isempty(obj.selection)
                error('LevelDiagram:exportSelection:noSelection', ...
                    'No hay puntos seleccionados.');
            end
            indices = obj.getSelectionForConcept(conceptIdx);
            if isempty(indices)
                error('LevelDiagram:exportSelection:noSelection', ...
                    'No hay puntos seleccionados para este concepto.');
            end
            c      = obj.concepts{conceptIdx};
            subset = c.extractSubset(indices);
            if nargin >= 3
                subset.name = name;
            end
        end

        function clearSelection(obj)
            % Limpia la selección actual
            obj.selection = {};
            obj.updateHighlightsMultiple([]);
            obj.updateInfoPanel([]);
        end

        %% Utilidades
        function refreshAxes(obj)
            % Refresca los límites de todos los ejes
            for i = 1:numel(obj.concepts)
                obj.updateYAxis(i);
            end
        end

        function disp(obj)
            fprintf('LevelDiagram: %s\n', obj.name);
            fprintf('  Conceptos: %d\n', numel(obj.concepts));
            for i = 1:numel(obj.concepts)
                fprintf('    [%d] %s (%d soluciones)\n', ...
                    i, obj.concepts{i}.name, obj.concepts{i}.nind);
            end
        end
    end

    methods (Access = private)
        function positions = computeFigureLayout(~, nFigs)
            % Calcula posiciones [x y w h] en píxeles para nFigs figuras
            % distribuidas en cuadrícula sin solapamiento

            % Obtener tamaño de pantalla disponible
            screenSize = get(0, 'ScreenSize');  % [1 1 width height]
            sw = screenSize(3);
            sh = screenSize(4);

            % Reservar espacio para barra de tareas (aprox 40px abajo)
            % y barra de menú del SO (aprox 25px arriba)
            usableH = sh - 65;
            usableW = sw;

            % Margen entre figuras
            margin = 8;

            % Calcular número de columnas y filas
            nCols = ceil(sqrt(nFigs));
            nRows = ceil(nFigs / nCols);

            % Tamaño de cada figura: 80% del espacio disponible por celda
            cellW = floor((usableW - (nCols+1)*margin) / nCols);
            cellH = floor((usableH - (nRows+1)*margin) / nRows);
            figW  = floor(cellW * 0.87);
            figH  = floor(cellH * 0.87);

            % Centrar cada figura dentro de su celda
            padW = floor((cellW - figW) / 2);
            padH = floor((cellH - figH) / 2);

            % Calcular posición de cada figura
            positions = cell(1, nFigs);
            for k = 1:nFigs
                col = mod(k-1, nCols);
                row = floor((k-1) / nCols);
                x   = margin + col*(cellW+margin) + padW;
                % y=0 es abajo en Matlab, empezamos desde arriba
                y   = sh - 40 - (row+1)*(cellH+margin) + padH;
                positions{k} = [x, y, figW, figH];
            end
        end

        %% Creación de figuras
        function createObjectivesFigure(obj, pos)
            nConcepts = numel(obj.concepts);
            pfdim     = obj.concepts{1}.pfdim;

            obj.figObjectives = figure('Name', ...
                sprintf('Objectives - %s', obj.name), ...
                'NumberTitle', 'off', ...
                'Position',    pos);

            % Checkboxes con figure clásico: uicontrol soporta BackgroundColor
            checkH    = 0.06;
            checkboxW = 1 / nConcepts;
            % Reducir fuente si hay muchos conceptos para que quepan los nombres
            cbFontSize = max(7, 11 - nConcepts);
            obj.checkboxHandles = cell(1, nConcepts);
            for i = 1:nConcepts
                colorIdx = mod(i-1, size(obj.DEFAULT_COLORS,1)) + 1;
                bgColor  = obj.DEFAULT_COLORS(colorIdx,:);
                % Usar uipanel como contenedor para poder borrarlo limpiamente
                pnl = uipanel(obj.figObjectives, ...
                    'Units',           'normalized', ...
                    'Position',        [(i-1)*checkboxW, 1-checkH, checkboxW, checkH], ...
                    'BackgroundColor',  bgColor, ...
                    'BorderType',       'none');
                obj.checkboxHandles{i} = uicontrol(pnl, ...
                    'Style',           'checkbox', ...
                    'Units',           'normalized', ...
                    'Position',        [0 0 1 1], ...
                    'String',          sprintf(' %s', obj.concepts{i}.name), ...
                    'Value',           1, ...
                    'FontWeight',      'bold', ...
                    'FontSize',        cbFontSize, ...
                    'BackgroundColor', bgColor, ...
                    'ForegroundColor', obj.contrastColor(bgColor), ...
                    'Callback',        @(src,~) obj.onConceptVisibility(src, i));
            end

            % Subplots de objetivos
            if pfdim <= 6
                pfRows = 1; pfCols = pfdim;
            else
                pfRows = 2; pfCols = ceil(pfdim / 2);
            end

            tl = tiledlayout(obj.figObjectives, pfRows, pfCols, ...
                'TileSpacing', 'compact', 'Padding', 'compact');
            tl.OuterPosition = [0, 0, 1, 1 - checkH];

            obj.axesObjectives    = cell(1, pfdim);
            obj.scatterObjectives = cell(nConcepts, pfdim);

            for j = 1:pfdim
                obj.axesObjectives{j} = nexttile(tl);
                hold(obj.axesObjectives{j}, 'on');
                grid(obj.axesObjectives{j}, 'on');
                xlabel(obj.axesObjectives{j}, obj.concepts{1}.labels.objectives{j});
                ylabel(obj.axesObjectives{j}, obj.syncLabel);

                for i = 1:nConcepts
                    c    = obj.concepts{i};
                    sync = obj.syncValues{i};
                    col  = obj.colorData{i};
                    sz   = obj.sizeData{i};
                    mk   = obj.markerData{i};
                    obj.scatterObjectives{i,j} = scatter(...
                        obj.axesObjectives{j}, ...
                        c.objectives(:,j), sync, sz, col, mk, ...
                        'MarkerFaceColor', 'flat');
                end
            end

            linkaxes([obj.axesObjectives{:}], 'y');
            obj.setupFigureInteraction(obj.figObjectives, 0);
        end

        function createParametersFigure(obj, conceptIdx, pos)
            c     = obj.concepts{conceptIdx};
            sync  = obj.syncValues{conceptIdx};
            col   = obj.colorData{conceptIdx};
            sz    = obj.sizeData{conceptIdx};
            mk    = obj.markerData{conceptIdx};
            psdim = c.psdim;

            fig = figure('Name', ...
                sprintf('Parameters - %s', c.name), ...
                'NumberTitle', 'off', ...
                'Position',    pos);
            obj.figsParameters{conceptIdx} = fig;

            if psdim <= 6
                nRows = 1;
                nCols = psdim;
            else
                nRows = 2;
                nCols = ceil(psdim / 2);
            end

            cbH = 0.10;  % fracción reservada para colorbar en la parte superior
            tl = tiledlayout(fig, nRows, nCols, ...
                'TileSpacing', 'compact', 'Padding', 'compact');
            tl.OuterPosition = [0, 0, 1, 1 - cbH];

            % Axes de referencia invisible para el colorbar (en la franja superior)
            refAx = axes(fig, 'Units', 'normalized', ...
                'Position', [0.05, 1 - cbH + 0.01, 0.9, 0.001], ...
                'Visible',  'off', ...
                'XDir',     'normal');
            obj.colorbarRefAxes{conceptIdx} = refAx;

            % Colorbar horizontal oculto hasta que se llame colorBy con indicador
            cb = colorbar(refAx, 'Location', 'south', ...
                'Units',     'normalized', ...
                'Position',  [0.05, 1 - cbH + 0.02, 0.9, 0.04], ...
                'Direction', 'normal', ...
                'Visible',   'off');
            obj.colorbarHandles{conceptIdx} = cb;

            axesPar = cell(1, psdim);
            scatPar = cell(1, psdim);

            for j = 1:psdim
                axesPar{j} = nexttile(tl);
                hold(axesPar{j}, 'on');
                grid(axesPar{j}, 'on');
                xlabel(axesPar{j}, c.labels.parameters{j});
                ylabel(axesPar{j}, obj.syncLabel);
                scatPar{j} = scatter(axesPar{j}, ...
                    c.parameters(:,j), sync, sz, col, mk, ...
                    'MarkerFaceColor', 'flat');
            end

            allAxes = [obj.axesObjectives{:}, axesPar{:}];
            linkaxes(allAxes, 'y');

            obj.axesParameters{conceptIdx}    = axesPar;
            obj.scatterParameters{conceptIdx} = scatPar;
            obj.setupFigureInteraction(fig, conceptIdx);
        end

        function rebuildCheckboxes(obj)
            % Reconstruye los checkboxes en la figura de objetivos
            % tras añadir o eliminar un concepto
            if isempty(obj.figObjectives) || ~isvalid(obj.figObjectives)
                return;
            end
            nConcepts = numel(obj.concepts);
            checkH    = 0.06;
            checkboxW = 1 / nConcepts;
            cbFontSize = max(7, 11 - nConcepts);

            obj.checkboxHandles = cell(1, nConcepts);
            for i = 1:nConcepts
                colorIdx = mod(i-1, size(obj.DEFAULT_COLORS,1)) + 1;
                bgColor  = obj.DEFAULT_COLORS(colorIdx,:);
                pnl = uipanel(obj.figObjectives, ...
                    'Units',           'normalized', ...
                    'Position',        [(i-1)*checkboxW, 1-checkH, checkboxW, checkH], ...
                    'BackgroundColor',  bgColor, ...
                    'BorderType',       'none');
                obj.checkboxHandles{i} = uicontrol(pnl, ...
                    'Style',           'checkbox', ...
                    'Units',           'normalized', ...
                    'Position',        [0 0 1 1], ...
                    'String',          sprintf(' %s', obj.concepts{i}.name), ...
                    'Value',           1, ...
                    'FontWeight',      'bold', ...
                    'FontSize',        cbFontSize, ...
                    'BackgroundColor', bgColor, ...
                    'ForegroundColor', obj.contrastColor(bgColor), ...
                    'Callback',        @(src,~) obj.onConceptVisibility(src, i));
            end
        end

        function rebuildInfoPanel(obj)
            % Cierra y recrea el panel de información con los conceptos actuales
            % Se llama al añadir o eliminar conceptos tras draw()
            if isempty(obj.figPanel) || ~isvalid(obj.figPanel)
                return;  % panel no creado aún, no hacer nada
            end
            % Guardar posición actual del panel
            pos = obj.figPanel.Position;
            % Cerrar panel actual
            close(obj.figPanel);
            obj.figPanel    = [];
            obj.panelTables = {};
            obj.panelLabels = {};
            obj.panelButtons = {};
            % Recrear solo si quedan conceptos
            if ~isempty(obj.concepts)
                obj.createInfoPanel(pos);
            end
        end

        function createInfoPanel(obj, pos)
            % Panel de info con figure clásico: botones + tabla por concepto
            % Todo en unidades normalizadas para que se adapte al redimensionado
            nC = numel(obj.concepts);

            obj.figPanel     = figure('Name', 'Info Panel', ...
                'NumberTitle',   'off', ...
                'MenuBar',       'none', ...
                'ToolBar',       'none', ...
                'Position',      pos, ...
                'ResizeFcn',     @(~,~) obj.onInfoPanelResize());
            obj.panelTables  = cell(1, nC);
            obj.panelLabels  = cell(1, nC);
            obj.panelButtons = cell(1, nC);

            % Alturas normalizadas fijas para título y tabla
            marginN = 0.005;
            subHN   = (1 - (nC+1)*marginN) / nC;
            titleHN = min(0.08, subHN * 0.18);
            tableHN = subHN - titleHN - marginN;
            btnWN   = 0.18;   % anchura botones normalizada
            btnHN   = titleHN * 0.85;

            for i = 1:nC
                c        = obj.concepts{i};
                colorIdx = mod(i-1, size(obj.DEFAULT_COLORS,1)) + 1;
                bgColor  = obj.DEFAULT_COLORS(colorIdx,:);
                yBotN    = 1 - i*(subHN + marginN);

                % Título coloreado
                obj.panelLabels{i} = uicontrol(obj.figPanel, ...
                    'Style',               'text', ...
                    'Units',               'normalized', ...
                    'Position',            [marginN, yBotN+tableHN+marginN, ...
                                            1-3*btnWN-4*marginN, titleHN], ...
                    'String',              sprintf('%s  (0 puntos)', c.name), ...
                    'FontWeight',          'bold', ...
                    'FontSize',            9, ...
                    'BackgroundColor',     bgColor, ...
                    'ForegroundColor',     obj.contrastColor(bgColor), ...
                    'HorizontalAlignment', 'left');

                % Botones alineados a la derecha, normalizados
                btnY = yBotN + tableHN + marginN + (titleHN - btnHN)/2;
                uicontrol(obj.figPanel, ...
                    'Style',    'pushbutton', ...
                    'Units',    'normalized', ...
                    'Position', [1-3*btnWN-3*marginN, btnY, btnWN, btnHN], ...
                    'String',   '> Ejecutar', ...
                    'Callback', @(~,~) obj.onRunCallbacksFor(i));

                uicontrol(obj.figPanel, ...
                    'Style',    'pushbutton', ...
                    'Units',    'normalized', ...
                    'Position', [1-2*btnWN-2*marginN, btnY, btnWN, btnHN], ...
                    'String',   'CSV', ...
                    'Callback', @(~,~) obj.onExportCSVFor(i));

                uicontrol(obj.figPanel, ...
                    'Style',    'pushbutton', ...
                    'Units',    'normalized', ...
                    'Position', [1-btnWN-marginN, btnY, btnWN, btnHN], ...
                    'String',   'Workspace', ...
                    'Callback', @(~,~) obj.onExportWorkspaceFor(i));

                % Tabla con unidades normalizadas y scroll automático
                obj.panelTables{i} = uitable(obj.figPanel, ...
                    'Units',      'normalized', ...
                    'Position',   [marginN, yBotN, 1-2*marginN, tableHN], ...
                    'ColumnName', obj.buildPanelColumns(i), ...
                    'Data',       {});
            end
        end

        function onInfoPanelResize(obj)
            % Refresca la tabla al redimensionar (las unidades normalizadas
            % se adaptan solas, pero forzamos repintado)
            if ~isempty(obj.figPanel) && isvalid(obj.figPanel)
                drawnow limitrate;
            end
        end

        function col = contrastColor(~, bgColor)
            % Devuelve blanco o negro según el brillo del fondo
            % para que el texto sea siempre legible
            luminance = 0.299*bgColor(1) + 0.587*bgColor(2) + 0.114*bgColor(3);
            if luminance > 0.5
                col = [0 0 0];   % negro
            else
                col = [1 1 1];   % blanco
            end
        end

        function cols = buildPanelColumns(obj, conceptIdx)
            % Construye las columnas del panel para un concepto específico
            if nargin < 2
                conceptIdx = 1;
            end
            c    = obj.concepts{conceptIdx};
            cols = [{'Index'}, ...
                c.labels.objectives, ...
                c.labels.parameters, ...
                {obj.syncLabel}];
        end

        %% Interacción
        function updateHighlights(obj)
            % Resalta los puntos seleccionados en todas las figuras
            % Primero restaura todos los puntos a su estado normal
            for i = 1:numel(obj.concepts)
                obj.updateColors(i);
                obj.updateSizes(i);
            end

            % Luego resalta los seleccionados
            if isempty(obj.selection)
                return;
            end

            cIdx = obj.selection{1}.conceptIdx;
            idx  = obj.selection{1}.indices;

            % Resaltar en figura de objetivos
            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.scatterObjectives{cIdx,j})
                    col = obj.colorData{cIdx};
                    if size(col,1) > 1
                        col(idx,:) = repmat(obj.HIGHLIGHT_COLOR, numel(idx), 1);
                    else
                        col = repmat(col, obj.concepts{cIdx}.nind, 1);
                        col(idx,:) = repmat(obj.HIGHLIGHT_COLOR, numel(idx), 1);
                    end
                    obj.scatterObjectives{cIdx,j}.CData     = col;
                    sz = obj.buildSizeVector(cIdx);
                    sz(idx) = obj.HIGHLIGHT_SIZE;
                    obj.scatterObjectives{cIdx,j}.SizeData  = sz;
                end
            end

            % Resaltar en figura de parámetros del concepto seleccionado
            if cIdx <= numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{cIdx})
                    col = obj.colorData{cIdx};
                    if size(col,1) > 1
                        col(idx,:) = repmat(obj.HIGHLIGHT_COLOR, numel(idx), 1);
                    else
                        col = repmat(col, obj.concepts{cIdx}.nind, 1);
                        col(idx,:) = repmat(obj.HIGHLIGHT_COLOR, numel(idx), 1);
                    end
                    obj.scatterParameters{cIdx}{j}.CData    = col;
                    sz = obj.buildSizeVector(cIdx);
                    sz(idx) = obj.HIGHLIGHT_SIZE;
                    obj.scatterParameters{cIdx}{j}.SizeData = sz;
                end
            end
        end

        function updateHighlightsMultiple(obj, selections)
            % Resalta puntos usando scatter superpuesto separado,
            % sin modificar los colores del scatter original.
            % selections: struct array con campos conceptIdx e indices
            %             o vacío para limpiar el resaltado

            % Eliminar todos los scatter de resaltado anteriores
            for i = 1:numel(obj.scatterHighlightObj)
                for k = 1:numel(obj.scatterHighlightObj{i})
                    if ~isempty(obj.scatterHighlightObj{i}{k}) && ...
                       isvalid(obj.scatterHighlightObj{i}{k})
                        delete(obj.scatterHighlightObj{i}{k});
                    end
                end
            end
            obj.scatterHighlightObj = {};

            if isempty(selections)
                return;
            end

            % Crear scatter de resaltado para cada concepto seleccionado
            for k = 1:numel(selections)
                ci  = selections(k).conceptIdx;
                idx = selections(k).indices;
                if isempty(idx); continue; end

                c    = obj.concepts{ci};
                sync = obj.syncValues{ci};
                mk   = obj.markerData{ci};
                hlScatters = {};

                % Tamaño del resaltado: max(HIGHLIGHT_SIZE, 1.5 * tamaño_punto)
                % para que siempre sea visible aunque el punto sea grande
                szBase = obj.buildSizeVector(ci);
                hlSz   = max(obj.HIGHLIGHT_SIZE, szBase(idx) * 1.5);

                % Resaltar en figura de objetivos
                for j = 1:numel(obj.axesObjectives)
                    ax = obj.axesObjectives{j};
                    h  = scatter(ax, ...
                        c.objectives(idx,j), sync(idx), ...
                        hlSz, ...
                        obj.HIGHLIGHT_COLOR, mk, ...
                        'MarkerFaceColor', obj.HIGHLIGHT_FACE_COLOR, ...
                        'MarkerFaceAlpha', obj.HIGHLIGHT_FACE_ALPHA, ...
                        'HitTest', 'off');   % no intercepta clicks
                    hlScatters{end+1} = h;   %#ok<AGROW>
                end

                % Resaltar en figura de parámetros del concepto
                if ci <= numel(obj.scatterParameters)
                    for j = 1:numel(obj.scatterParameters{ci})
                        ax = obj.axesParameters{ci}{j};
                        h  = scatter(ax, ...
                            c.parameters(idx,j), sync(idx), ...
                            hlSz, ...
                            obj.HIGHLIGHT_COLOR, mk, ...
                            'MarkerFaceColor', obj.HIGHLIGHT_FACE_COLOR, ...
                            'MarkerFaceAlpha', obj.HIGHLIGHT_FACE_ALPHA, ...
                            'HitTest', 'off');
                        hlScatters{end+1} = h;  %#ok<AGROW>
                    end
                end

                obj.scatterHighlightObj{end+1} = hlScatters;
            end
        end

        function updateInfoPanel(obj, selections)
            % Actualiza el panel de información
            if isempty(obj.figPanel) || ~isvalid(obj.figPanel)
                return;
            end

            % Limpiar todos los subpaneles primero
            for i = 1:numel(obj.panelTables)
                if ~isempty(obj.panelTables{i}) && isvalid(obj.panelTables{i})
                    obj.panelTables{i}.Data = {};
                    obj.panelLabels{i}.String = sprintf('%s  (0 puntos)', ...
                        obj.concepts{i}.name);
                end
            end

            if nargin < 2 || isempty(selections)
                return;
            end

            % Rellenar cada subpanel con sus puntos seleccionados
            for k = 1:numel(selections)
                ci      = selections(k).conceptIdx;
                indices = selections(k).indices;
                c       = obj.concepts{ci};
                sync    = obj.syncValues{ci};

                if isempty(indices); continue; end

                % Actualizar título
                obj.panelLabels{ci}.String = sprintf('%s  (%d puntos seleccionados)', ...
                    c.name, numel(indices));

                % Construir filas como cell array (figure clásico)
                nRows = numel(indices);
                rows  = cell(nRows, 1 + c.pfdim + c.psdim + 1);
                for r = 1:nRows
                    ii = indices(r);
                    rows(r,:) = [{ii}, ...
                        num2cell(c.objectives(ii,:)), ...
                        num2cell(c.parameters(ii,:)), ...
                        {sync(ii)}];
                end
                obj.panelTables{ci}.Data       = rows;
                obj.panelTables{ci}.ColumnName = obj.buildPanelColumns(ci);
            end
        end
        function executeCallbacks(obj, conceptIdx, ptIdx, selIdx, nTotal)
            % Ejecuta los callbacks de usuario con los datos del punto
            if isempty(obj.callbacks)
                return;
            end

            c    = obj.concepts{conceptIdx};
            sync = obj.syncValues{conceptIdx};

            % Construir estructura del punto
            punto.concept       = c.name;
            punto.index         = ptIdx;
            punto.objectives    = c.objectives(ptIdx,:);
            punto.parameters    = c.parameters(ptIdx,:);
            punto.sync          = sync(ptIdx);
            punto.labels        = c.labels;
            punto.selectionIdx  = selIdx;    % posición dentro de la selección actual
            punto.selectionSize = nTotal;    % total de puntos seleccionados

            % Ejecutar solo los callbacks asociados a este concepto
            for i = 1:numel(obj.callbacks)
                if obj.callbacks{i}.conceptIdx == conceptIdx
                    try
                        obj.callbacks{i}.func(punto);
                    catch e
                        warning('LevelDiagram:callbackError', ...
                            'Error en callback %d: %s', i, e.message);
                    end
                end
            end
        end

        function onRunCallbacksFor(obj, conceptIdx)
            % Ejecuta los callbacks del concepto conceptIdx con su selección actual
            % Buscar indices seleccionados de este concepto
            indices = obj.getSelectionForConcept(conceptIdx);
            if isempty(indices)
                warndlg('No hay puntos seleccionados para este concepto.', 'Aviso');
                return;
            end
            hasCallback = false;
            for k = 1:numel(obj.callbacks)
                if obj.callbacks{k}.conceptIdx == conceptIdx
                    hasCallback = true;
                    break;
                end
            end
            if ~hasCallback
                warndlg(sprintf('No hay callbacks para "%s". Use ld.onSelect(c, @func).', obj.concepts{conceptIdx}.name), 'Aviso');
                return;
            end
            nTotal = numel(indices);
            for k = 1:nTotal
                obj.executeCallbacks(conceptIdx, indices(k), k, nTotal);
            end
        end

        function onExportWorkspaceFor(obj, conceptIdx)
            % Exporta la selección del concepto conceptIdx al workspace
            indices = obj.getSelectionForConcept(conceptIdx);
            if isempty(indices)
                warndlg('No hay puntos seleccionados para este concepto.', 'Aviso');
                return;
            end
            answer = inputdlg('Nombre de la variable en el workspace:', ...
                              'Exportar al workspace', 1, ...
                              {[obj.concepts{conceptIdx}.name '_subset']});
            if isempty(answer); return; end
            varName = answer{1};
            if ~isvarname(varName)
                warndlg(sprintf('"%s" no es un nombre válido.', varName), 'Error');
                return;
            end
            c      = obj.concepts{conceptIdx};
            subset = c.extractSubset(indices);
            subset.name = varName;
            assignin('base', varName, subset);
            msgbox(sprintf('Exportado como "%s" (%d puntos).', varName, subset.nind), 'Exportación completada');
        end

        function onExportCSVFor(obj, conceptIdx)
            % Exporta la selección del concepto conceptIdx a CSV
            indices = obj.getSelectionForConcept(conceptIdx);
            if isempty(indices)
                warndlg('No hay puntos seleccionados para este concepto.', 'Aviso');
                return;
            end
            [file, path] = uiputfile('*.csv', 'Guardar selección como CSV');
            if isequal(file, 0); return; end

            fullPath = fullfile(path, file);
            c        = obj.concepts{conceptIdx};
            sync     = obj.syncValues{conceptIdx};
            headers  = [{'Index'}, c.labels.objectives, c.labels.parameters, {'f_sync'}];
            data     = [num2cell(indices(:)), ...
                        num2cell(c.objectives(indices,:)), ...
                        num2cell(c.parameters(indices,:)), ...
                        num2cell(sync(indices))];

            fid = fopen(fullPath, 'w');
            fprintf(fid, '%s,', headers{1:end-1});
            fprintf(fid, '%s\n', headers{end});
            for r = 1:size(data,1)
                for col = 1:size(data,2)-1
                    fprintf(fid, '%g,', data{r,col});
                end
                fprintf(fid, '%g\n', data{r,end});
            end
            fclose(fid);
            msgbox(sprintf('Guardado en:\n%s', fullPath), 'Exportación completada');
        end

        function indices = getSelectionForConcept(obj, conceptIdx)
            % Devuelve los índices seleccionados para un concepto dado
            % conceptIdx puede ser un índice numérico o un objeto Concept
            if isa(conceptIdx, 'Concept')
                conceptIdx = obj.getConceptIndex(conceptIdx);
            end
            indices = [];
            for k = 1:numel(obj.selection)
                if obj.selection{k}.conceptIdx == conceptIdx
                    indices = obj.selection{k}.indices;
                    return;
                end
            end
        end
        function mergeSelection(obj, conceptIdx, newIndices)
            % Añade índices a la selección de un concepto
            for k = 1:numel(obj.selection)
                if obj.selection{k}.conceptIdx == conceptIdx
                    obj.selection{k}.indices = unique([obj.selection{k}.indices; newIndices(:)]);
                    return;
                end
            end
            % No existía entrada para este concepto, añadir
            obj.selection{end+1} = struct('conceptIdx', conceptIdx, ...
                                          'indices',    newIndices(:));
        end

        function subtractSelection(obj, conceptIdx, removeIndices)
            % Quita índices de la selección de un concepto
            for k = 1:numel(obj.selection)
                if obj.selection{k}.conceptIdx == conceptIdx
                    obj.selection{k}.indices = setdiff(obj.selection{k}.indices, removeIndices);
                    if isempty(obj.selection{k}.indices)
                        obj.selection(k) = [];  % eliminar entrada vacía
                    end
                    return;
                end
            end
        end

        function onConceptVisibility(obj, src, conceptIdx)
            % Callback del checkbox: muestra/oculta un concepto
            visible = logical(src.Value);  % 1 = visible, 0 = oculto
            obj.conceptVisible(conceptIdx) = visible;

            % Mostrar/ocultar en figura de objetivos
            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.scatterObjectives{conceptIdx, j})
                    if visible
                        obj.scatterObjectives{conceptIdx,j}.Visible = 'on';
                    else
                        obj.scatterObjectives{conceptIdx,j}.Visible = 'off';
                    end
                end
            end

            % Mostrar/ocultar figura de parámetros completa
            if conceptIdx <= numel(obj.figsParameters) && ...
               ~isempty(obj.figsParameters{conceptIdx}) && ...
               isvalid(obj.figsParameters{conceptIdx})
                if visible
                    obj.figsParameters{conceptIdx}.Visible = 'on';
                else
                    obj.figsParameters{conceptIdx}.Visible = 'off';
                end
            end

            % Si se oculta, limpiar selección de ese concepto
            if ~visible && ~isempty(obj.getSelectionForConcept(conceptIdx))
                obj.subtractSelection(conceptIdx, obj.getSelectionForConcept(conceptIdx));
                obj.updateHighlightsMultiple([]);
                obj.updateInfoPanel([]);
            end
        end

        function setupFigureInteraction(obj, fig, conceptIdx)
            % Configura los callbacks de interacción de una figura
            set(fig, 'WindowButtonDownFcn',  @(src,evt) obj.onMouseDown(src, evt, conceptIdx));
            set(fig, 'WindowButtonUpFcn',    @(src,evt) obj.onMouseUp(src, evt, conceptIdx));
            set(fig, 'WindowButtonMotionFcn',@(src,evt) obj.onMouseMove(src, evt));
            % Limpiar estado tras zoom (ActionPostCallback no modifica callbacks)
            zm = zoom(fig);
            set(zm, 'ActionPostCallback', @(~,~) obj.cleanupAfterZoom());
        end

        function cleanupAfterZoom(obj)
            % Limpia estado de arrastre tras zoom
            if ~isempty(obj.dragRect) && isvalid(obj.dragRect)
                delete(obj.dragRect);
                obj.dragRect = [];
            end
            obj.dragStart  = [];
            obj.isDragging = false;
        end

        function tf = isInteractiveModeActive(~, fig)
            % Comprueba si zoom o pan están activos
            try
                tf = isactiveuimode(fig, 'zoom') || ...
                     isactiveuimode(fig, 'pan')  || ...
                     strcmp(zoom(fig).Enable, 'on') || ...
                     strcmp(pan(fig).Enable,  'on');
            catch
                tf = false;
            end
        end

        function onMouseDown(obj, src, ~, ~)
            % Ignorar si zoom o pan están activos
            if obj.isInteractiveModeActive(src); return; end

            % Ignorar botón derecho
            selType = get(src, 'SelectionType');
            if strcmp(selType, 'alt')
                return;
            end

            % Capturar estado de Shift en el momento del click
            % 'extend' = Shift+click en figure clásico
            obj.shiftDown  = strcmp(selType, 'extend');
            obj.isDragging = false;

            ax = get(src, 'CurrentAxes');
            if isempty(ax); return; end
            pos = get(ax, 'CurrentPoint');
            obj.dragStart = [pos(1,1), pos(1,2)];

            % Crear rectángulo de selección (solo borde, sin relleno)
            obj.dragRect = rectangle(ax, ...
                'Position',   [obj.dragStart(1), obj.dragStart(2), 0, 0], ...
                'EdgeColor',  'k', ...
                'LineStyle',  '--', ...
                'LineWidth',  1.5, ...
                'FaceColor',  'none');
        end

        function onMouseMove(obj, src, ~)
            % Durante el drag: actualizar rectángulo
            if obj.isInteractiveModeActive(src); return; end
            if isempty(obj.dragStart); return; end
            ax = get(src, 'CurrentAxes');
            if isempty(ax); return; end
            pos = get(ax, 'CurrentPoint');
            curPos = [pos(1,1), pos(1,2)];

            % Calcular rectángulo
            x = min(obj.dragStart(1), curPos(1));
            y = min(obj.dragStart(2), curPos(2));
            w = abs(curPos(1) - obj.dragStart(1));
            h = abs(curPos(2) - obj.dragStart(2));

            if w > 0 && h > 0
                obj.isDragging = true;
                if ~isempty(obj.dragRect) && isvalid(obj.dragRect)
                    obj.dragRect.Position = [x, y, w, h];
                end
            end
        end

        function onMouseUp(obj, src, ~, conceptIdx)
            % Fin del click o drag
            if obj.isInteractiveModeActive(src)
                obj.cleanupAfterZoom();
                return;
            end
            ax = get(src, 'CurrentAxes');
            if isempty(ax)
                obj.dragStart = [];
                return;
            end

            % Eliminar rectángulo visual
            if ~isempty(obj.dragRect) && isvalid(obj.dragRect)
                delete(obj.dragRect);
                obj.dragRect = [];
            end

            % Si es figura de objetivos (conceptIdx==0) identificar
            % el concepto más cercano al click en tiempo de ejecución
            if conceptIdx == 0
                conceptIdx = obj.getConceptIndexFromAxes(ax);
            end
            if isempty(conceptIdx)
                obj.isDragging = false;
                obj.dragStart  = [];
                return;
            end

            if obj.isDragging
                % SELECCIÓN POR ZONA
                pos    = get(ax, 'CurrentPoint');
                endPos = [pos(1,1), pos(1,2)];
                xLim   = sort([obj.dragStart(1), endPos(1)]);
                yLim   = sort([obj.dragStart(2), endPos(2)]);
                obj.selectByZone(xLim, yLim, conceptIdx, ax);
            else
                % CLICK SIMPLE
                obj.selectByClick(ax, conceptIdx);
            end

            obj.isDragging = false;
            obj.dragStart  = [];
        end

        function idx = getConceptIndexFromAxes(obj, ax)
            % Identifica qué concepto tiene el punto más cercano al click
            % en la figura de objetivos (compartida por todos los conceptos)
            pos    = get(ax, 'CurrentPoint');
            xClick = pos(1,1);
            yClick = pos(1,2);

            xLabel = get(get(ax, 'XLabel'), 'String');
            xRange = diff(get(ax, 'XLim'));
            yRange = diff(get(ax, 'YLim'));

            if xRange == 0 || yRange == 0
                idx = [];
                return;
            end

            bestDist = inf;
            idx      = 1;  % por defecto el primero

            for i = 1:numel(obj.concepts)
                c     = obj.concepts{i};
                sync  = obj.syncValues{i};
                xData = obj.getDataByLabel(c, xLabel);
                if isempty(xData); continue; end

                dist = sqrt(((xData - xClick)./xRange).^2 + ...
                            ((sync  - yClick)./yRange).^2);
                [minDist, ~] = min(dist);

                if minDist < bestDist
                    bestDist = minDist;
                    idx      = i;
                end
            end
        end

        function selectByZone(obj, xLim, yLim, conceptIdx, ax)
            % Selecciona puntos dentro de la zona.
            % Si conceptIdx > 0 (figura de parámetros), solo busca en ese concepto.
            % Si conceptIdx == 0 (figura de objetivos), busca en todos los visibles.
            xLabel = get(get(ax, 'XLabel'), 'String');

            % Determinar qué conceptos explorar
            if conceptIdx > 0
                ciList = conceptIdx;
            else
                ciList = 1:numel(obj.concepts);
            end

            % Buscar puntos en la zona para cada concepto
            found = struct('conceptIdx', {}, 'indices', {});
            for ci = ciList
                if ci <= numel(obj.conceptVisible) && ~obj.conceptVisible(ci); continue; end
                c     = obj.concepts{ci};
                sync  = obj.syncValues{ci};
                xData = obj.getDataByLabel(c, xLabel);
                if isempty(xData); continue; end

                inZone  = xData >= xLim(1) & xData <= xLim(2) & ...
                          sync  >= yLim(1) & sync  <= yLim(2);
                indices = find(inZone);
                if isempty(indices); continue; end

                found(end+1).conceptIdx = ci;    %#ok<AGROW>
                found(end).indices      = indices;
            end

            if isempty(found)
                % Zona vacía: limpiar selección
                if ~obj.shiftDown
                    obj.selection = {};
                    obj.updateHighlightsMultiple([]);
                    obj.updateInfoPanel([]);
                end
                return;
            end

            if obj.shiftDown
                % Shift: toggle — añade los que no estaban, quita los que estaban
                for k = 1:numel(found)
                    ci  = found(k).conceptIdx;
                    idx = found(k).indices;
                    existing = obj.getSelectionForConcept(ci);
                    alreadySel = intersect(existing, idx);
                    newSel     = setdiff(idx, existing);
                    % Quitar los ya seleccionados
                    if ~isempty(alreadySel)
                        obj.subtractSelection(ci, alreadySel);
                    end
                    % Añadir los nuevos
                    if ~isempty(newSel)
                        obj.mergeSelection(ci, newSel);
                    end
                end
            else
                % Sin Shift: reemplazar selección completa
                obj.selection = {};
                for k = 1:numel(found)
                    obj.selection{end+1} = struct('conceptIdx', found(k).conceptIdx, ...
                                                  'indices',    found(k).indices);
                end
            end

            % Reconstruir selections desde estado actual para highlight y panel
            selections = struct('conceptIdx', {}, 'indices', {});
            for k = 1:numel(obj.selection)
                if ~isempty(obj.selection{k}.indices)
                    selections(end+1).conceptIdx = obj.selection{k}.conceptIdx; %#ok<AGROW>
                    selections(end).indices      = obj.selection{k}.indices;
                end
            end

            obj.updateHighlightsMultiple(selections);
            obj.updateInfoPanel(selections);
            % Callbacks se ejecutan desde el botón del panel de info
        end

        function selectByClick(obj, ax, conceptIdx)
            % Selecciona el punto más cercano al click
            % Si el click está lejos de todos los puntos, limpia la selección
            pos    = get(ax, 'CurrentPoint');
            xClick = pos(1,1);
            yClick = pos(1,2);

            xRange = diff(get(ax, 'XLim'));
            yRange = diff(get(ax, 'YLim'));
            if xRange == 0 || yRange == 0; return; end

            % Umbral: si el punto más cercano está a más del 5% del rango -> zona vacía
            THRESHOLD = 0.05;

            % Determinar qué conceptos explorar
            if conceptIdx > 0
                ciList = conceptIdx;
            else
                ciList = 1:numel(obj.concepts);
            end

            % Buscar el punto más cercano en los conceptos relevantes
            bestDist   = inf;
            bestCi     = conceptIdx;
            bestPtIdx  = [];
            xLabel     = get(get(ax, 'XLabel'), 'String');

            for ci = ciList
                if ci <= numel(obj.conceptVisible) && ~obj.conceptVisible(ci); continue; end
                c     = obj.concepts{ci};
                sync  = obj.syncValues{ci};
                xData = obj.getDataByLabel(c, xLabel);
                if isempty(xData); continue; end

                dist = sqrt(((xData - xClick)./xRange).^2 + ...
                            ((sync  - yClick)./yRange).^2);
                [minD, ptIdx] = min(dist);
                if minD < bestDist
                    bestDist  = minD;
                    bestCi    = ci;
                    bestPtIdx = ptIdx;
                end
            end

            % Click en zona vacía -> limpiar selección
            if isempty(bestPtIdx) || bestDist > THRESHOLD
                if ~obj.shiftDown
                    obj.selection = {};
                    obj.updateHighlightsMultiple([]);
                    obj.updateInfoPanel([]);
                end
                return;
            end

            % Actualizar selección con toggle si Shift, reemplazar si no
            if obj.shiftDown
                existing = obj.getSelectionForConcept(bestCi);
                if ismember(bestPtIdx, existing)
                    % Ya estaba seleccionado -> deseleccionar
                    obj.subtractSelection(bestCi, bestPtIdx);
                else
                    % No estaba -> añadir
                    obj.mergeSelection(bestCi, bestPtIdx);
                end
            else
                obj.selection = {struct('conceptIdx', bestCi, 'indices', bestPtIdx)};
            end

            % Reconstruir selections desde estado actual
            selections = struct('conceptIdx', {}, 'indices', {});
            for k = 1:numel(obj.selection)
                if ~isempty(obj.selection{k}.indices)
                    selections(end+1).conceptIdx = obj.selection{k}.conceptIdx; %#ok<AGROW>
                    selections(end).indices      = obj.selection{k}.indices;
                end
            end

            obj.updateHighlightsMultiple(selections);
            obj.updateInfoPanel(selections);
            % Callbacks se ejecutan desde el botón del panel de info
        end

        function xData = getDataByLabel(~, concept, label)
            % Devuelve la columna de datos que corresponde a una etiqueta
            xData = [];
            for i = 1:concept.pfdim
                if strcmp(concept.labels.objectives{i}, label)
                    xData = concept.objectives(:,i);
                    return;
                end
            end
            for i = 1:concept.psdim
                if strcmp(concept.labels.parameters{i}, label)
                    xData = concept.parameters(:,i);
                    return;
                end
            end
        end

        function executeCallbacksMultiple(obj, conceptIdx, indices)
            if isempty(obj.callbacks); return; end
            c    = obj.concepts{conceptIdx};
            sync = obj.syncValues{conceptIdx};

            for k = 1:numel(indices)
                i = indices(k);
                punto.concept    = c.name;
                punto.index      = i;
                punto.objectives = c.objectives(i,:);
                punto.parameters = c.parameters(i,:);
                punto.sync       = sync(i);
                punto.labels     = c.labels;

                for j = 1:numel(obj.callbacks)
                    if obj.callbacks{j}.conceptIdx == conceptIdx
                        try
                            obj.callbacks{j}.func(punto);
                        catch e
                            warning('LevelDiagram:callbackError', ...
                                'Error en callback %d: %s', j, e.message);
                        end
                    end
                end
            end
        end
        %% Actualización de propiedades gráficas
        function updateSyncLabels(obj)
            % Actualiza la etiqueta del eje Y en todas las figuras
            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.axesObjectives{j}) && isvalid(obj.axesObjectives{j})
                    ylabel(obj.axesObjectives{j}, obj.syncLabel);
                end
            end
            for ci = 1:numel(obj.axesParameters)
                for j = 1:numel(obj.axesParameters{ci})
                    if ~isempty(obj.axesParameters{ci}{j}) && isvalid(obj.axesParameters{ci}{j})
                        ylabel(obj.axesParameters{ci}{j}, obj.syncLabel);
                    end
                end
            end
        end

        function updateYAxis(obj, conceptIdx)
            % Actualiza el eje Y de sincronización
            if isempty(obj.figObjectives)
                return;
            end
            % Concepto aún no dibujado (addConcept antes de draw para este concepto)
            if conceptIdx > size(obj.scatterObjectives, 1)
                return;
            end
            sync = obj.syncValues{conceptIdx};
            % Aplicar el mismo sortOrder que usa updateColors para mantener
            % XData e YData sincronizados
            ord  = obj.sortOrder{conceptIdx};
            sync = sync(ord);

            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.scatterObjectives{conceptIdx,j})
                    obj.scatterObjectives{conceptIdx,j}.YData = sync;
                end
            end
            if conceptIdx <= numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{conceptIdx})
                    obj.scatterParameters{conceptIdx}{j}.YData = sync;
                end
            end
        end

        function rescaleYAxes(obj)
            % Recalcula y aplica los límites del eje Y a todos los ejes tras
            % cambiar syncValues. linkaxes congela YLimMode='manual', por lo
            % que es necesario actualizar YLim explícitamente.
            if isempty(obj.syncValues); return; end

            allSync = cell2mat(obj.syncValues(:));
            if isempty(allSync); return; end

            yMin = min(allSync);
            yMax = max(allSync);
            if yMin == yMax
                yMin = yMin - 0.5;
                yMax = yMax + 0.5;
            end
            margin = 0.05 * (yMax - yMin);
            newLim = [yMin - margin, yMax + margin];

            % Aplicar a ejes de objetivos
            for j = 1:numel(obj.axesObjectives)
                ax = obj.axesObjectives{j};
                if ~isempty(ax) && isvalid(ax)
                    ax.YLim = newLim;
                end
            end

            % Aplicar a ejes de parámetros de cada concepto
            for ci = 1:numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{ci})
                    sc = obj.scatterParameters{ci}{j};
                    if ~isempty(sc) && isvalid(sc)
                        sc.Parent.YLim = newLim;
                    end
                end
            end
        end

        function updateColors(obj, conceptIdx)
            % Actualiza colores y orden de trazado de un concepto en todas sus figuras
            if isempty(obj.figObjectives)
                return;
            end
            ord  = obj.sortOrder{conceptIdx};
            col  = obj.colorData{conceptIdx};
            sz   = obj.buildSizeVector(conceptIdx);
            sync = obj.syncValues{conceptIdx};
            c    = obj.concepts{conceptIdx};

            % Reordenar todos los datos según sortOrder para controlar z-order
            % col(ord,:) asegura que cada punto mantiene su color correcto
            % aunque se dibuje en una posición diferente del array
            if size(col, 1) > 1
                col  = col(ord, :);
            end
            sz   = sz(ord);
            sync = sync(ord);

            for j = 1:numel(obj.axesObjectives)
                sc = obj.scatterObjectives{conceptIdx, j};
                if ~isempty(sc)
                    sc.XData             = c.objectives(ord, j);
                    sc.YData             = sync;
                    sc.CData             = col;
                    sc.SizeData          = sz;
                    sc.MarkerFaceColor   = 'flat';
                end
            end
            if conceptIdx <= numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{conceptIdx})
                    sc = obj.scatterParameters{conceptIdx}{j};
                    if ~isempty(sc)
                        sc.XData           = c.parameters(ord, j);
                        sc.YData           = sync;
                        sc.CData           = col;
                        sc.SizeData        = sz;
                        sc.MarkerFaceColor = 'flat';
                    end
                end
            end
        end

        function updateColorbar(obj, conceptIdx, climVals, cmapName, reverseColor, label)
            % Muestra y actualiza el colorbar horizontal en la figura de parámetros
            cb    = obj.colorbarHandles{conceptIdx};
            refAx = obj.colorbarRefAxes{conceptIdx};
            if isempty(cb) || ~isvalid(cb) || isempty(refAx) || ~isvalid(refAx)
                return;
            end
            if ischar(cmapName)
                cmap = feval(cmapName, 256);
            else
                cmap = cmapName;
            end
            if reverseColor
                cmap = flipud(cmap);
            end
            colormap(refAx, cmap);
            clim(refAx, climVals);
            cb.Direction = 'normal';

            cbPos = cb.Position;  % [x y w h] normalizados

            % Eliminar etiqueta anterior si existe
            lh = obj.colorbarLabels{conceptIdx};
            if ~isempty(lh) && isvalid(lh)
                delete(lh);
            end
            obj.colorbarLabels{conceptIdx} = [];

            if ~isempty(label)
                fig = obj.figsParameters{conceptIdx};
                obj.colorbarLabels{conceptIdx} = annotation(fig, 'textbox', ...
                    'Units',              'normalized', ...
                    'Position',           [0.01, cbPos(2)-cbPos(4)*0.5, 0.14, cbPos(4)*2], ...
                    'String',             label, ...
                    'FontWeight',         'bold', ...
                    'EdgeColor',          'none', ...
                    'HorizontalAlignment','right', ...
                    'VerticalAlignment',  'middle');
                cb.Position = [0.17, cbPos(2), 0.80, cbPos(4)];
            else
                cb.Position = [0.05, cbPos(2), 0.92, cbPos(4)];
            end
            cb.Visible = 'on';
        end

        function hideColorbar(obj, conceptIdx)
            % Oculta el colorbar de un concepto
            if conceptIdx > numel(obj.colorbarHandles); return; end
            cb = obj.colorbarHandles{conceptIdx};
            if ~isempty(cb) && isvalid(cb)
                cb.Visible = 'off';
            end
        end

        function updateSizes(obj, conceptIdx)
            % Actualiza los tamaños de un concepto en todas sus figuras
            if isempty(obj.figObjectives)
                return;
            end
            sz = obj.buildSizeVector(conceptIdx);
            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.scatterObjectives{conceptIdx,j})
                    obj.scatterObjectives{conceptIdx,j}.SizeData = sz;
                end
            end
            if conceptIdx <= numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{conceptIdx})
                    obj.scatterParameters{conceptIdx}{j}.SizeData = sz;
                end
            end
        end

        function updateMarkers(obj, conceptIdx)
            % Actualiza el marcador de un concepto en todas sus figuras
            if isempty(obj.figObjectives)
                return;
            end
            mk = obj.markerData{conceptIdx};
            for j = 1:numel(obj.axesObjectives)
                if ~isempty(obj.scatterObjectives{conceptIdx,j})
                    obj.scatterObjectives{conceptIdx,j}.Marker = mk;
                end
            end
            if conceptIdx <= numel(obj.scatterParameters)
                for j = 1:numel(obj.scatterParameters{conceptIdx})
                    obj.scatterParameters{conceptIdx}{j}.Marker = mk;
                end
            end
        end

        %% Métodos de soporte
        function recalcGlobalBoundsAndSync(obj)
            % Recalcula bounds globales (max de maxpf, min de minpf de todos)
            % y recalcula f_sync de todos los conceptos con la norma global actual
            if isempty(obj.concepts); return; end

            % Recalcular bounds globales
            maxPF = obj.concepts{1}.maxpf;
            minPF = obj.concepts{1}.minpf;
            for i = 2:numel(obj.concepts)
                maxPF = max([maxPF; obj.concepts{i}.maxpf]);
                minPF = min([minPF; obj.concepts{i}.minpf]);
            end
            obj.globalBounds = [maxPF; minPF];

            % Recalcular sync para todos con la norma global actual
            for i = 1:numel(obj.concepts)
                obj.syncValues{i} = obj.computeNorm(...
                    obj.concepts{i}.objectives, obj.globalBounds, obj.globalNorm);
                obj.updateYAxis(i);
            end
            obj.rescaleYAxes();
        end

        function sync = computeNorm(~, objectives, bounds, p)
            % Calcula la norma p normalizada del frente de Pareto
            maxb = bounds(1,:);
            minb = bounds(2,:);

            % Evitar división por cero
            range = maxb - minb;
            range(range == 0) = 1;

            % Normalizar
            objNorm = (objectives - minb) ./ range;
            objNorm = max(0, min(1, objNorm));  % clamp a [0,1]

            % Calcular norma
            if isinf(p)
                sync = max(objNorm, [], 2);
            else
                sync = sum(objNorm.^p, 2).^(1/p);
            end
        end

        function colores = indicatorToColors(obj, indicator, varargin)
            % Mapea un vector indicador a colores usando un colormap
            p = inputParser();
            p.addParameter('colormap', obj.DEFAULT_COLORMAP);
            p.addParameter('reverse',  false);
            p.addParameter('clim',     []);
            p.parse(varargin{:});

            cmap    = p.Results.colormap;
            reverse = p.Results.reverse;
            clim    = p.Results.clim;

            % Normalizar indicador a [0,1]
            if isempty(clim)
                minVal = min(indicator);
                maxVal = max(indicator);
            else
                minVal = clim(1);
                maxVal = clim(2);
            end

            range = maxVal - minVal;
            if range == 0
                ind_norm = zeros(size(indicator));
            else
                ind_norm = (indicator - minVal) / range;
                ind_norm = max(0, min(1, ind_norm));
            end

            if reverse
                ind_norm = 1 - ind_norm;
            end

            % Obtener colores del colormap
            nColors = 256;
            if ischar(cmap)
                cmap = feval(cmap, nColors);
            end
            cidx    = max(1, round(ind_norm * (nColors-1)) + 1);
            colores = cmap(cidx, :);
        end

        function sz = buildSizeVector(obj, conceptIdx)
            % Construye el vector de tamaños para scatter
            s = obj.sizeData{conceptIdx};
            n = obj.concepts{conceptIdx}.nind;
            if isscalar(s)
                sz = repmat(s, n, 1);
            else
                sz = s;
            end
        end

        function col = defaultColors(obj)
            % Color por defecto (azul)
            col = obj.indicatorToColors(0);
        end

        function tf = isSingleRGB(~, input)
            % Comprueba si el input es un color RGB único [r g b]
            % Para distinguirlo de un indicador de 3 puntos, exige
            % que sea un vector fila o columna con valores en [0, 1]
            % y que tenga exactamente 3 elementos
            tf = isnumeric(input)   && ...
                 isvector(input)    && ...
                 numel(input) == 3  && ...
                 all(input >= 0)    && ...
                 all(input <= 1);
        end

        function tf = isRGBMatrix(~, input, nind)
            % Comprueba si el input es una matriz RGB nind x 3
            tf = isnumeric(input) && ...
                ismatrix(input) && ...
                size(input,1) == nind && ...
                size(input,2) == 3 && ...
                all(all(input >= 0)) && ...
                all(all(input <= 1));
        end

        function idx = getConceptIndex(obj, concept)
            % Devuelve el índice de un concepto en la lista
            for i = 1:numel(obj.concepts)
                if strcmp(obj.concepts{i}.name, concept.name)
                    idx = i;
                    return;
                end
            end
            error('LevelDiagram:conceptNotFound', ...
                'El concepto "%s" no está en este Level Diagram.', concept.name);
        end

        function tf = conceptExists(obj, concept)
            % Comprueba si un concepto ya está en el Level Diagram
            tf = false;
            for i = 1:numel(obj.concepts)
                if strcmp(obj.concepts{i}.name, concept.name)
                    tf = true;
                    return;
                end
            end
        end

        %% Validaciones
        function validateName(~, name)
            if ~ischar(name) && ~isstring(name)
                error('LevelDiagram:invalidName', ...
                    'El nombre debe ser un string.');
            end
        end

        function validateConcept(~, concept)
            if ~isa(concept, 'Concept')
                error('LevelDiagram:invalidConcept', ...
                    'El argumento debe ser un objeto Concept.');
            end
        end

        function validateBounds(~, bounds, pfdim)
            if ~isnumeric(bounds) || size(bounds,1) ~= 2 || size(bounds,2) ~= pfdim
                error('LevelDiagram:invalidBounds', ...
                    'bounds debe ser una matriz 2 x %d [maximos; minimos].', pfdim);
            end
            if any(bounds(1,:) <= bounds(2,:))
                error('LevelDiagram:invalidBounds', ...
                    'bounds(1,:) debe ser mayor que bounds(2,:) en todas las dimensiones.');
            end
        end

        function validateSyncValues(~, values, nind)
            if ~isnumeric(values) || ~isvector(values) || numel(values) ~= nind
                error('LevelDiagram:invalidSyncValues', ...
                    'syncValues debe ser un vector numérico de %d elementos.', nind);
            end
        end
    end
end