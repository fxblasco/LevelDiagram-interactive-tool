classdef Concept
    % Concept - Clase para encapsular datos de un frente y conjunto de Pareto
    %
    % Uso:
    %   c = Concept(pf, ps)
    %   c = Concept(pf, ps, 'nombre')
    %
    % Propiedades:
    %   name            - Nombre del concepto
    %   data            - Matriz [pf ps] con todos los datos
    %   nind            - Número de soluciones
    %   pfdim           - Dimensión del frente de Pareto
    %   psdim           - Dimensión del conjunto de Pareto
    %   labels          - Etiquetas de objetivos y parámetros
    %
    % Ejemplo:
    %   c = Concept(pfront, pset, 'PIDesign');
    %   c.labels.objectives = {'J1', 'J2'};
    %   c.labels.parameters = {'Kp', 'Ti'};
    
    properties
        name        (1,:) char       = ''      % Nombre del concepto
    end
    
    properties (SetAccess = private)
        data        (:,:) double               % Matriz [pf ps]
        nind        (1,1) double               % Número de soluciones
        pfdim       (1,1) double               % Dimensión frente Pareto
        psdim       (1,1) double               % Dimensión conjunto Pareto
    end

    properties
        labels      struct                     % Etiquetas de ejes
    end

    properties (Dependent)
        objectives  (:,:) double               % Frente de Pareto (nind x pfdim)
        parameters  (:,:) double               % Conjunto de Pareto (nind x psdim)
        maxpf       (1,:) double               % Máximos del frente
        minpf       (1,:) double               % Mínimos del frente
        maxps       (1,:) double               % Máximos del conjunto
        minps       (1,:) double               % Mínimos del conjunto
    end
    
    methods
        %% Constructor
        function obj = Concept(pf, ps, name)
            % Concept - Constructor de la clase
            %
            % Entradas:
            %   pf   - Matriz del frente de Pareto (nind x pfdim)
            %   ps   - Matriz del conjunto de Pareto (nind x psdim)
            %   name - (opcional) Nombre del concepto

            % Validar inputs
            obj.validateInputs(pf, ps);
            
            % Asignar datos
            obj.pfdim = size(pf, 2);
            obj.psdim = size(ps, 2);
            obj.nind  = size(pf, 1);
            obj.data  = [pf ps];
            
            % Nombre opcional
            if nargin >= 3
                obj.validateName(name);
                obj.name = name;
            end
            
            % Etiquetas por defecto
            obj.labels = obj.defaultLabels();
        end
        
        %% Setters
        function obj = set.name(obj, name)
            obj.validateName(name);
            obj.name = name;
        end
        
        function obj = set.labels(obj, labels)
            obj.validateLabels(labels);
            obj.labels = labels;
        end

        %% Getters de propiedades dependientes
        function val = get.objectives(obj)
            val = obj.data(:, 1:obj.pfdim);
        end
        
        function val = get.parameters(obj)
            val = obj.data(:, obj.pfdim+1:end);
        end
        
        function val = get.maxpf(obj)
            val = max(obj.objectives);
        end
        
        function val = get.minpf(obj)
            val = min(obj.objectives);
        end
        
        function val = get.maxps(obj)
            val = max(obj.parameters);
        end
        
        function val = get.minps(obj)
            val = min(obj.parameters);
        end

        %% Métodos públicos de utilidad
        function disp(obj)
            % Muestra información del concepto
            fprintf('Concept: %s\n', obj.name);
            fprintf('  Soluciones : %d\n',   obj.nind);
            fprintf('  Objetivos  : %d\n',   obj.pfdim);
            fprintf('  Parámetros : %d\n',   obj.psdim);
            fprintf('  Max frente : %s\n',   mat2str(obj.maxpf, 4));
            fprintf('  Min frente : %s\n',   mat2str(obj.minpf, 4));
            fprintf('  Max conjunto: %s\n',  mat2str(obj.maxps, 4));
            fprintf('  Min conjunto: %s\n',  mat2str(obj.minps, 4));
        end

        function bounds = autoBounds(obj)
            % Devuelve bounds automáticos a partir de los datos del concepto
            % bounds = [maxpf; minpf]
            bounds = [obj.maxpf; obj.minpf];
        end

        function bounds = mergeBounds(obj, other)
            % Combina bounds de dos conceptos para comparación
            % Útil cuando se superponen dos conceptos en Objectives
            %
            % Uso:
            %   bounds = c1.mergeBounds(c2)
            %   ld.addConcept(c1, bounds, 2)
            %   ld.addConcept(c2, bounds, 2)

            if obj.pfdim ~= other.pfdim
                error('Concept:mergeBounds:dimMismatch', ...
                      'Los conceptos deben tener la misma dimensión de frente de Pareto.');
            end
            bounds = [max([obj.maxpf; other.maxpf]);
                      min([obj.minpf; other.minpf])];
        end

        function subset = extractSubset(obj, idx)
            % Extrae un subconjunto de puntos por índice
            %
            % Uso:
            %   subset = c1.extractSubset(idx)
            %   subset = c1.extractSubset(logical_mask)

            % Validar índices
            if islogical(idx)
                if numel(idx) ~= obj.nind
                    error('Concept:extractSubset:dimMismatch', ...
                          'La máscara lógica debe tener %d elementos.', obj.nind);
                end
            else
                if any(idx < 1) || any(idx > obj.nind)
                    error('Concept:extractSubset:outOfRange', ...
                          'Índices fuera de rango [1, %d].', obj.nind);
                end
            end

            % Crear nuevo concepto con el subconjunto
            pf_sub = obj.objectives(idx, :);
            ps_sub = obj.parameters(idx, :);
            subset = Concept(pf_sub, ps_sub, [obj.name '_subset']);
            subset.labels = obj.labels;
        end
    end
    
    methods (Static)
        function bounds = mergeBoundsN(varargin)
            % Combina bounds de N conceptos para comparación
            % Útil cuando se superponen 3 o más conceptos en Objectives
            %
            % Uso:
            %   bounds = Concept.mergeBoundsN(c1, c2, c3)
            %   bounds = Concept.mergeBoundsN(c1, c2, c3, c4)
            %   bounds = Concept.mergeBoundsN({c1, c2, c3})

            % Aceptar cell array como primer argumento
            if numel(varargin) == 1 && iscell(varargin{1})
                concepts = varargin{1};
            else
                concepts = varargin;
            end

            if numel(concepts) < 2
                error('Concept:mergeBoundsN:tooFew', ...
                    'Se necesitan al menos 2 conceptos.');
            end

            pfdim = concepts{1}.pfdim;
            maxPF = concepts{1}.maxpf;
            minPF = concepts{1}.minpf;

            for k = 2:numel(concepts)
                if concepts{k}.pfdim ~= pfdim
                    error('Concept:mergeBoundsN:dimMismatch', ...
                        'Todos los conceptos deben tener la misma dimensión de frente.');
                end
                maxPF = max([maxPF; concepts{k}.maxpf]);
                minPF = min([minPF; concepts{k}.minpf]);
            end
            bounds = [maxPF; minPF];
        end
    end

    methods (Access = private)
        %% Validaciones
        function validateInputs(~, pf, ps)
            % Validar que pf y ps son matrices numéricas no vacías
            % con el mismo número de filas

            if ~isnumeric(pf) || ~ismatrix(pf) || isempty(pf)
                error('Concept:invalidInput', ...
                      'pf debe ser una matriz numérica no vacía.');
            end
            if ~isnumeric(ps) || ~ismatrix(ps) || isempty(ps)
                error('Concept:invalidInput', ...
                      'ps debe ser una matriz numérica no vacía.');
            end
            if size(pf, 1) ~= size(ps, 1)
                error('Concept:invalidInput', ...
                      'pf y ps deben tener el mismo número de filas (soluciones).');
            end
            if any(any(isnan(pf))) || any(any(isnan(ps)))
                error('Concept:invalidInput', ...
                      'pf y ps no pueden contener NaN.');
            end
            if any(any(isinf(pf))) || any(any(isinf(ps)))
                error('Concept:invalidInput', ...
                      'pf y ps no pueden contener Inf.');
            end
        end

        function validateName(~, name)
            % Validar que name es un identificador Matlab válido
            if ~ischar(name) && ~isstring(name)
                error('Concept:invalidName', ...
                      'El nombre debe ser un string.');
            end
            if ~isempty(name) && ~isvarname(name)
                error('Concept:invalidName', ...
                      '"%s" no es un identificador Matlab válido.', name);
            end
        end

        function validateLabels(obj, labels)
            % Validar estructura de etiquetas
            if ~isstruct(labels)
                error('Concept:invalidLabels', ...
                      'labels debe ser una estructura.');
            end
            if isfield(labels, 'objectives') && ...
               numel(labels.objectives) ~= obj.pfdim
                error('Concept:invalidLabels', ...
                      'labels.objectives debe tener %d elementos.', obj.pfdim);
            end
            if isfield(labels, 'parameters') && ...
               numel(labels.parameters) ~= obj.psdim
                error('Concept:invalidLabels', ...
                      'labels.parameters debe tener %d elementos.', obj.psdim);
            end
        end

        function labels = defaultLabels(obj)
            % Genera etiquetas por defecto
            labels.objectives = arrayfun(@(i) sprintf('f%d', i), ...
                                         1:obj.pfdim, ...
                                         'UniformOutput', false);
            labels.parameters = arrayfun(@(i) sprintf('x%d', i), ...
                                         1:obj.psdim, ...
                                         'UniformOutput', false);
        end
    end
end