%% EJEMPLO 1: Uso básico
% Datos sintéticos: 50 puntos, 2 objetivos, 3 parámetros
pf = rand(50, 2);
ps = rand(50, 3);

c1 = Concept(pf, ps);
disp(c1)
% Esperado:
% Concept: 
%   Soluciones : 50
%   Objetivos  : 2
%   Parámetros : 3
%   Max frente : [0.998 0.995]
%   Min frente : [0.002 0.001]
%   ...

%% EJEMPLO 2: Con nombre y etiquetas personalizadas
c2 = Concept(pf, ps, 'PIDesign');
c2.labels.objectives = {'IAE', 'TV'};
c2.labels.parameters = {'Kp', 'Ti', 'Td'};
disp(c2)
% Esperado:
% Concept: PIDesign
%   Soluciones : 50
%   Objetivos  : 2
%   Parámetros : 3
%   ...

%% EJEMPLO 3: Verificar etiquetas por defecto
c3 = Concept(pf, ps, 'GPCDesign');
disp(c3.labels.objectives)
% Esperado: {'f1'  'f2'}
disp(c3.labels.parameters)
% Esperado: {'x1'  'x2'  'x3'}

%% EJEMPLO 4: Propiedades dependientes
c4 = Concept(pf, ps, 'test');
disp(c4.objectives)   % debe devolver pf original (50 x 2)
disp(c4.parameters)   % debe devolver ps original (50 x 3)
disp(c4.maxpf)        % debe devolver max de cada columna de pf (1 x 2)
disp(c4.minpf)        % debe devolver min de cada columna de pf (1 x 2)
disp(c4.maxps)        % debe devolver max de cada columna de ps (1 x 3)
disp(c4.minps)        % debe devolver min de cada columna de ps (1 x 3)

%% EJEMPLO 5 corregido: mergeBounds entre dos conceptos
pf1 = [10 4; 50 6; 100 8];   % frente PID - 3 soluciones, 2 objetivos
ps1 = [0.5 2; 1.0 3; 2.0 4]; % conjunto PID - 3 soluciones, 2 parámetros

pf2 = [20 3; 60 5; 110 9];   % frente GPC - 3 soluciones, 2 objetivos
ps2 = [100 0.1; 200 0.2; 300 0.3]; % conjunto GPC - 3 soluciones, 2 parámetros

c_pid = Concept(pf1, ps1, 'PID');
c_gpc = Concept(pf2, ps2, 'GPC');

bounds = c_pid.mergeBounds(c_gpc);
disp(bounds)
% Esperado:
% bounds(1,:) = [110  9]   <- max de ambos maxpf
% bounds(2,:) = [10   3]   <- min de ambos minpf

%% EJEMPLO 6: extractSubset por índices
c5 = Concept(pf, ps, 'test');
subset1 = c5.extractSubset([1 5 10 20]);   % por índices
disp(subset1.nind)    % debe ser 4
disp(subset1.name)    % debe ser 'test_subset'

mask = pf(:,1) < 0.3;                      % por máscara lógica
subset2 = c5.extractSubset(mask);
disp(subset2.nind)    % debe ser el número de puntos con f1 < 0.3

%% EJEMPLO 7: Validaciones - deben lanzar errores claros
% Distinto número de filas
try
    c_err = Concept(rand(10,2), rand(15,3));
catch e
    disp(e.message)
    % Esperado: 'pf y ps deben tener el mismo número de filas (soluciones).'
end

% Nombre inválido
try
    c_err = Concept(pf, ps, 'mi concepto');  % espacio no permitido
catch e
    disp(e.message)
    % Esperado: '"mi concepto" no es un identificador Matlab válido.'
end

% Etiquetas con dimensión incorrecta
try
    c5 = Concept(pf, ps, 'test');
    c5.labels.objectives = {'f1', 'f2', 'f3'};  % pf tiene 2 cols, no 3
catch e
    disp(e.message)
    % Esperado: 'labels.objectives debe tener 2 elementos.'
end

% NaN en los datos
try
    pf_nan = pf;
    pf_nan(1,1) = NaN;
    c_err = Concept(pf_nan, ps);
catch e
    disp(e.message)
    % Esperado: 'pf y ps no pueden contener NaN.'
end