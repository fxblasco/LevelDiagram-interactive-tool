% =========================================================
%  VISUALIZACIÓN DE FRENTES DE PARETO CON MUCHAS DIMENSIONES
%  Coordenadas Paralelas  |  Star Plot  |  Scatter Plot Matrix
% =========================================================
clear; clc; close all;

%% ---- Parámetros de fuente ----
fsTitle  = 20;
fsAxis   = 12;
fsTick   = 10;
fsLabel  = 11;

%% ---- Configuración del frente ----
nobj     = 5;
np       = 55;
objNames = {'J_1','J_2','J_3','J_4','J_5'};

%% ---- Frente de Pareto sintético (5 objetivos, minimización) ----
%  Puntos en el simplejo normalizado: w_i > 0, sum(w) = 1
%  Objetivo i: J_i = 1 - w_i  (cuanto mayor el peso, menor el objetivo)
%  Garantiza estructura de Pareto convexa genuina.
rng(42);
w = zeros(np, nobj);
for i = 1:np
    x     = -log(rand(1, nobj));   % Dirichlet por transformación exponencial
    w(i,:) = x / sum(x);
end
pf = 1 - w;                        % objetivos en [0,1]; menor = mejor

[pf, ~] = sortrows(pf, 1);         % ordenar por J_1 para mejor aspecto en coord. paralelas

%% ---- Mapeo de color: mejor solución → amarillo ----
quality  = sum(pf, 2);             % índice de calidad (menor = mejor)
[~, qi]  = sort(quality);          % qi(k) = índice de la k-ésima mejor solución
[~, ri]  = sort(qi);               % ri(i) = rango de la solución i  (1 = mejor)
cmap_raw = flipud(parula(np));     % rango 1 → amarillo brillante, rango np → azul oscuro
pt_col   = cmap_raw(ri, :);        % color por solución

%% ---- Crear figura ----
fig = figure('Name','Visualización Multidimensional del Frente de Pareto', ...
             'Color','w','Position',[50 50 1350 700]);

%% ================================================
%  COORDENADAS PARALELAS
%% ================================================
ax_pc = axes('Parent',fig,'Position',[0.06 0.57 0.86 0.37]);
hold(ax_pc,'on');

% Dibujar las peores soluciones primero (quedan debajo)
[~, draw_ord] = sort(quality,'descend');
for k = 1:np
    ii = draw_ord(k);
    plot(ax_pc, 1:nobj, pf(ii,:), '-', ...
         'Color',[pt_col(ii,:) 0.68], 'LineWidth',1.3);
end

% Ejes verticales sobre las líneas
for j = 1:nobj
    plot(ax_pc,[j j],[-0.02 1.02],'-','Color',[0.30 0.30 0.30],'LineWidth',1.8);
end

set(ax_pc, 'XTick',1:nobj, 'XTickLabel',objNames, ...
           'FontSize',fsTick, 'FontName','Times New Roman', ...
           'YGrid','on', 'GridAlpha',0.20);
xlim(ax_pc,[0.6 nobj+0.4]);
ylim(ax_pc,[-0.06 1.12]);
ylabel(ax_pc,'Valor normalizado','FontSize',fsAxis,'FontName','Times New Roman');
title(ax_pc,'Coordenadas Paralelas','FontSize',fsTitle, ...
      'FontName','Times New Roman','FontWeight','bold');
box(ax_pc,'on');

% Colorbar alineada con el mapeo: amarillo = menor calidad = mejor
colormap(ax_pc, flipud(parula));
clim(ax_pc, [min(quality) max(quality)]);
cb = colorbar(ax_pc,'eastoutside');
cb.Ticks = [];   % sin valores numéricos ni etiqueta en la barra

%% ================================================
%  STAR PLOT  (todas las soluciones, mismo color que los demás paneles)
%% ================================================
% Ángulos: J_1 en la cima (π/2), sentido horario
angles = pi/2 - (0:nobj-1) * 2*pi/nobj;

sp_l = 0.04;  sp_b = 0.08;  sp_sz = 0.37;   % cuadrado para mantener proporción
ax_s = axes('Parent',fig,'Position',[sp_l, sp_b, sp_sz, sp_sz]);
hold(ax_s,'on');

% Rejilla circular
for r = 0.25:0.25:1.0
    xg = r * cos([angles angles(1)]);
    yg = r * sin([angles angles(1)]);
    plot(ax_s, xg, yg, '-', 'Color',[0.82 0.82 0.82], 'LineWidth',0.6);
end
% Radios
for k = 1:nobj
    plot(ax_s,[0 cos(angles(k))],[0 sin(angles(k))], ...
         '-','Color',[0.72 0.72 0.72],'LineWidth',0.6);
end

% Todas las soluciones: peores primero, mejores encima
[~, draw_ord_s] = sort(quality,'descend');
for k = 1:np
    ii = draw_ord_s(k);
    pt = pf(ii,:);
    xd = pt .* cos(angles);
    yd = pt .* sin(angles);
    plot(ax_s, [xd xd(1)], [yd yd(1)], '-', ...
         'Color',[pt_col(ii,:) 0.65], 'LineWidth',1.2);
end

% Etiquetas de ejes radiales
r_lab = 1.22;
for k = 1:nobj
    text(ax_s, r_lab*cos(angles(k)), r_lab*sin(angles(k)), objNames{k}, ...
         'HorizontalAlignment','center','VerticalAlignment','middle', ...
         'FontSize',fsAxis,'FontName','Times New Roman');
end

axis(ax_s,'equal','off');
xlim(ax_s,[-1.5 1.5]);  ylim(ax_s,[-1.5 1.5]);

annotation('textbox',[sp_l, sp_b+sp_sz+0.004, sp_sz, 0.042], ...
    'String','Star Plot', 'FontSize',fsTitle, 'FontName','Times New Roman', ...
    'FontWeight','bold', 'EdgeColor','none', 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'Color',[0.15 0.15 0.15]);

%% ================================================
%  SCATTER PLOT MATRIX  (5 × 5)
%% ================================================
sm_l = 0.48;  sm_b = 0.07;
sm_W = 0.50;  sm_H = 0.40;
cw   = sm_W / nobj;
ch   = sm_H / nobj;
pad  = 0.004;

for i = 1:nobj
    for j = 1:nobj
        l_ij = sm_l + (j-1)*cw + pad;
        b_ij = sm_b + (nobj-i)*ch + pad;
        w_ij = cw - 2*pad;
        h_ij = ch - 2*pad;

        ax_ij = axes('Parent',fig,'Position',[l_ij, b_ij, w_ij, h_ij]);
        hold(ax_ij,'on');

        if i == j
            % Diagonal: nombre del objetivo
            set(ax_ij,'XLim',[0 1],'YLim',[0 1],'Color',[0.91 0.91 0.96]);
            text(ax_ij, 0.5, 0.5, objNames{i}, ...
                 'HorizontalAlignment','center','VerticalAlignment','middle', ...
                 'FontSize',fsAxis,'FontName','Times New Roman','FontWeight','bold');
        else
            % Fuera de la diagonal: scatter del par (J_j, J_i)
            scatter(ax_ij, pf(:,j), pf(:,i), 14, pt_col, 'filled', ...
                    'MarkerFaceAlpha',0.78,'MarkerEdgeColor','none');
            colormap(ax_ij, flipud(parula));
            xlim(ax_ij,[0 1]);  ylim(ax_ij,[0 1]);
        end

        set(ax_ij,'XTick',[],'YTick',[]);
        box(ax_ij,'on');

        if i == nobj
            xlabel(ax_ij, objNames{j}, 'FontSize',fsLabel, 'FontName','Times New Roman');
        end
        if j == 1
            ylabel(ax_ij, objNames{i}, 'FontSize',fsLabel, 'FontName','Times New Roman');
        end
    end
end

annotation('textbox',[sm_l, sm_b+sm_H+0.004, sm_W, 0.042], ...
    'String','Scatter Plot Matrix', 'FontSize',fsTitle, 'FontName','Times New Roman', ...
    'FontWeight','bold', 'EdgeColor','none', 'HorizontalAlignment','center', ...
    'VerticalAlignment','middle', 'Color',[0.15 0.15 0.15]);

%% ---- Exportar ----
exportgraphics(fig,'pareto_dimensiones.png','Resolution',200);
fprintf('Figura guardada como pareto_dimensiones.png\n');
