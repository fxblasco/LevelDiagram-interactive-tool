%% Test 1: Crear conceptos
pf1 = rand(50, 4) * 100;
ps1 = rand(50, 3);
pf2 = rand(40, 4) * 100;
ps2 = rand(40, 2);
pf3 = rand(45, 4) * 100;
ps3 = rand(45, 4);

c1 = Concept(pf1, ps1, 'PID');c1.labels.objectives = {'IAE1', 'TV1','IAE2','TV2'};
c1.labels.parameters = {'Kp', 'Ti', 'Td'};


c2 = Concept(pf2, ps2, 'GPC');
c2.labels.objectives = {'IAE', 'TV','IAE','kk'};
c2.labels.parameters = {'N', 'Nu'};

c3 = Concept(pf3, ps3, 'MPC');
%c3.labels.objectives = {'IAE', 'TV','IAE2', 'TV3'};
c3.labels.parameters = {'Np', 'Nc', 'Q', 'R'};

%disp(c1); disp(c2); disp(c3)

%% Test 2: Crear Level Diagram - addConcept sin bounds
% Los bounds globales se calculan automáticamente
% y f_sync se recalcula para todos al añadir cada concepto
ld = LevelDiagram('ld1');
ld.addConcept(c1);   % bounds = c1.autoBounds, norma 2
ld.addConcept(c2);   % bounds = merge(c1,c2),  recalcula c1 y c2
ld.addConcept(c3);   % bounds = merge(c1,c2,c3), recalcula todos
ld.setSyncLabel('Norma 2');
disp(ld)

%% Test 3: Dibujar
ld.draw();

%% Test 3b: Etiqueta del eje de sincronizacion
ld.setSyncLabel('Norma 2');
ld.setSyncLabel('f_{sync}');  % restaurar por defecto

%% Test 4: Marcadores
ld.setMarker(c1, 'o');
ld.setMarker(c2, 's');
ld.setMarker(c3, '*');

%% Test 5: Colorear
ld.colorBy(c1, pf1(:,1));
ld.colorBy(c2, pf2(:,2), 'colormap', 'hot');
ld.colorBy(c3, pf3(:,1), 'colormap', 'cool');
ld.colorBy(c1, [1 0.5 0.1]);  % color único naranja

%% Test 6: Cambiar sincronización
% Norma p para TODOS los conceptos (bounds globales automáticos)
ld.syncByNorm(1);        % norma 1 para todos
ld.setSyncLabel('Norma 1');
ld.syncByNorm(inf);      % norma infinito para todos
ld.setSyncLabel('Norma \infty');
ld.syncByNorm(2);        % volver a norma 2
ld.setSyncLabel('Norma 2');

% Con bounds personalizados
myBounds = [120 20 120 20 ; 5 1 5 1];
ld.syncByNorm(2, myBounds);
ld.setSyncLabel('Norma 2 (bounds custom)');
% para ver bounds y norma actuales:
ld.globalBounds
ld.globalNorm
% Volver a bounds automáticos
ld.resetBounds();           % recalcula bounds y sync con norma actual
% o si además quieres cambiar la norma:
ld.resetBounds();
ld.syncByNorm(1);           % norma 1 con bounds automáticos restaurados

% Indicador externo para TODOS los conceptos (cell array)
QI_pid = rand(c1.nind, 1);
QI_gpc = rand(c2.nind, 1);
QI_mpc = rand(c3.nind, 1);
ld.syncBy({QI_pid, QI_gpc, QI_mpc});
ld.setSyncLabel('Quality Indicator');

%% Test 7: Callbacks por concepto
ld.onSelect(c1, @verPunto);   % callback para c1
% ld.onSelect(c2, @verPuntoGPC);  % callback diferente para c2
ld.clearCallbacks(c1);         % eliminar callback de c1
% ld.clearCallbacks();           % eliminar todos

%% Test 8: Exportar selección (seleccionar puntos primero)
% subset1 = ld.exportSelection(c1, 'subset_PID');
% subset2 = ld.exportSelection(2,  'subset_GPC');
% disp(subset1); disp(subset2)

%% Test 9: Tamaños
ld.setSize(c1, 80)
ld.setSize(c2, linspace(20, 200, c2.nind)')
tamanios = 20 + 250*(pf3(:,1)-min(pf3(:,1)))/(max(pf3(:,1))-min(pf3(:,1)));
ld.setSize(c3, tamanios)

%% Test 10: Eliminar un concepto
ld.removeConcept(c2);   % elimina c2, recalcula bounds y sync de c1 y c3
% Para añadirlo de nuevo:
% ld.addConcept(c2);
