% =========================================================
%  VISUALIZACIÓN DE CONCEPTOS MULTIOBJETIVO
%  Decision Space (3D)  -->  Objectives Space (2D)
%  Conceptos: dominancia, frente de Pareto
% =========================================================
clear; clc; close all;

%% ---- Tamaño de fuente (ajustar aquí) ----
fsLabel = 22;   % etiquetas de puntos (theta^x, J(theta^x))
fsAxis  = 16;   % etiquetas de ejes
fsTitle = 17;   % títulos de paneles
fsAnnot = 22;   % texto de zona dominada y otros

%% ---- Soluciones en el espacio de decisión (3D, en [0,1]^3) ----
%  Modificar aquí para mover los puntos en el espacio de decisión
theta.a = [0.20, 0.75, 0.60];
theta.b = [0.50, 0.55, 0.30];
theta.c = [0.75, 0.30, 0.45];
theta.d = [0.8, 0.12, 0.88];
theta.e = [0.62, 0.78, 0.52];

%% ---- Valores en el espacio de objetivos (definir a mano) ----
%  Modificar aquí para mover los puntos en el espacio de objetivos.
%  Restricción de dominancia a mantener: J(b) domina J(e),
%  es decir J1(b) < J1(e)  Y  J2(b) < J2(e).
J.a = [0.20, 1.20];
J.b = [0.38, 0.52];
J.c = [0.72, 0.18];
J.d = [0.23, 0.80];
J.e = [0.58, 0.82];

%% ---- Offsets de etiquetas en espacio de decisión ----
%  [delta_theta1, delta_theta2, delta_theta3] desde el punto
offDec.a = [ 0.05,  0.04,  0.05];
offDec.b = [ 0.05,  0.04,  0.05];
offDec.c = [ 0.05,  0.04,  0.05];
offDec.d = [ 0.05,  0.04,  0.05];
offDec.e = [ 0.05,  0.04,  0.04];

%% ---- Offsets de etiquetas en espacio de objetivos ----
%  [delta_J1, delta_J2] desde el punto
offObj.a = [ 0.05,  0.05];
offObj.b = [ 0.05,  0.05];
offObj.c = [ 0.05,  0.05];
offObj.d = [ 0.05,  0.05];
offObj.e = [ 0.05,  0.05];

%% ---- Colores por solución ----
col.a = [0.20, 0.55, 0.90];
col.b = [0.90, 0.35, 0.25];
col.c = [0.25, 0.75, 0.45];
col.d = [0.85, 0.60, 0.10];
col.e = [0.55, 0.35, 0.75];

%% ---- Crear figura ----
fig = figure('Name','Optimización Multiobjetivo', ...
             'Color','w', 'Position',[80 80 1200 540]);

% Posiciones manuales: [left, bottom, width, height] en coordenadas normalizadas.
% Ajustar para controlar el espacio que ocupa cada panel.
pos1 = [0.09, 0.10, 0.38, 0.84];   % panel izquierdo (decisión) — margen izq. para zlabel
pos2 = [0.54, 0.13, 0.43, 0.81];   % panel derecho (objetivos) — margen inf. para xlabel

names = {'a','b','c','d','e'};

%% ========================
%  PANEL IZQUIERDO: Espacio de Decisión (3D)
%% ========================
ax1 = axes('Parent', fig, 'Position', pos1);
hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
set(ax1,'FontSize',fsAxis-2,'FontName','Times New Roman', ...
        'GridAlpha',0.25,'XColor',[.3 .3 .3], ...
        'YColor',[.3 .3 .3],'ZColor',[.3 .3 .3]);
xlim(ax1,[0 1]); ylim(ax1,[0 1]); zlim(ax1,[0 1]);
xlabel(ax1,'\theta_1','FontSize',fsAxis,'FontName','Times New Roman');
ylabel(ax1,'\theta_2','FontSize',fsAxis,'FontName','Times New Roman');
zlabel(ax1,'\theta_3','FontSize',fsAxis,'FontName','Times New Roman');
title(ax1,'Espacio de Decisión','FontSize',fsTitle, ...
     'FontName','Times New Roman','FontWeight','bold');
view(ax1, [-50, 22]);   % azimut más negativo → eje Z sale hacia la derecha, zlabel visible

for i = 1:numel(names)
    nm = names{i};
    pt = theta.(nm);
    c  = col.(nm);
    scatter3(ax1, pt(1), pt(2), pt(3), 140, c, 'filled', ...
             'MarkerEdgeColor','k','LineWidth',1.2);
    off = offDec.(nm);
    text(ax1, pt(1)+off(1), pt(2)+off(2), pt(3)+off(3), ...
         ['\theta^' nm], 'FontSize',fsLabel, ...
         'FontName','Times New Roman','Color',c*0.75,'FontWeight','bold');
end

%% ========================
%  PANEL DERECHO: Espacio de Objetivos
%% ========================
ax2 = axes('Parent', fig, 'Position', pos2);
hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
set(ax2,'FontSize',fsAxis-2,'FontName','Times New Roman', ...
        'GridAlpha',0.25,'XColor',[.3 .3 .3],'YColor',[.3 .3 .3]);
xlabel(ax2,'J_1(\theta)','FontSize',fsAxis,'FontName','Times New Roman');
ylabel(ax2,'J_2(\theta)','FontSize',fsAxis,'FontName','Times New Roman');
title(ax2,'Espacio de Objetivos','FontSize',fsTitle, ...
     'FontName','Times New Roman','FontWeight','bold');

% Zona dominada por J(theta^b) — región donde J1 >= J1(b) y J2 >= J2(b)
Jb    = J.b;
xMax  = 1.9;
yMax  = 1.9;
fill(ax2, [Jb(1) xMax xMax Jb(1)], [Jb(2) Jb(2) yMax yMax], ...
     [1.00 0.85 0.85], 'EdgeColor','none','FaceAlpha',0.55);
text(ax2, Jb(1)+0.50, Jb(2)+0.7, ...
     {'Zona dominada','por J(\theta^b)'}, ...
     'FontSize',fsAnnot,'FontName','Times New Roman', ...
     'Color',[0.70 0.15 0.15]);

% Líneas de frontera de dominancia
plot(ax2,[Jb(1) Jb(1)],[Jb(2) yMax],'--','Color',[0.85 0.3 0.3],'LineWidth',1.4);
plot(ax2,[Jb(1) xMax],[Jb(2) Jb(2)],'--','Color',[0.85 0.3 0.3],'LineWidth',1.4);

% Puntos en el espacio de objetivos
for i = 1:numel(names)
    nm  = names{i};
    Jpt = J.(nm);
    c   = col.(nm);
    scatter(ax2, Jpt(1), Jpt(2), 140, c, 'filled', ...
            'MarkerEdgeColor','k','LineWidth',1.2);
    off = offObj.(nm);
    text(ax2, Jpt(1)+off(1), Jpt(2)+off(2), ...
         ['J(\theta^' nm ')'], 'FontSize',fsLabel, ...
         'FontName','Times New Roman','Color',c*0.75,'FontWeight','bold');
end

% Límites del eje
allJ = [J.a; J.b; J.c; J.d; J.e];
xlim(ax2,[min(allJ(:,1))-0.15, xMax]);
ylim(ax2,[min(allJ(:,2))-0.15, yMax]);

%% ---- Mapeo entre paneles: J(.) + flecha gruesa ----
% Posición horizontal centrada en el hueco entre paneles (pos1 y pos2)
xGapCenter = (pos1(1)+pos1(3) + pos2(1)) / 2;   % centro del hueco
xArrowHalf = 0.02;                                % semilongitud de la flecha
yArrow     = 0.10;                                % altura de la flecha (bajar si solapa)
yLabel     = 0.10;                                % altura del texto J(.)

annotation('textbox',[xGapCenter-0.055 yLabel 0.11 0.08], ...
    'String','J(\cdot)', ...
    'FontSize',fsAnnot+2,'FontName','Times New Roman','EdgeColor','none', ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Color',[0.3 0.3 0.3]);

annotation('arrow', ...
    [xGapCenter-xArrowHalf, xGapCenter+xArrowHalf], [yArrow, yArrow], ...
    'LineWidth',3, 'HeadWidth',18, 'HeadLength',12, ...
    'Color',[0.4 0.4 0.4]);

%% ---- Exportar figura ----
exportgraphics(fig,'multiobjetivo_MO.png','Resolution',200);
fprintf('Figura guardada como multiobjetivo_MO.png\n');
