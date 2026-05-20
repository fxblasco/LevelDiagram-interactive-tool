function drawPrefBands(fig, mode, varargin)
% drawPrefBands  Draw preference sectors/bands on a Level Diagram figure.
%
%   OBJECTIVES figure  — staircase sectors (reach down to x-axis):
%     drawPrefBands(fig, 'obj', pref, offsets)
%     drawPrefBands(fig, 'obj', pref, offsets, labels)
%
%       pref    : (nobj x nI) preference table (col x = vertex of hypercube x,
%                 most preferred col 1 to least preferred col nI)
%       offsets : (nI x 1) Y-axis offsets from composedNorm (offsets(1)=0)
%       labels  : (1 x nI) cell of strings — optional band labels drawn
%                 vertically on the left of each sector
%
%   PARAMETERS figure  — full-width horizontal bands:
%     drawPrefBands(fig, 'par', offsets)
%
% Example:
%   [dn, offsets] = composedNorm(pf, pref);
%   ld.syncBy({dn});
%   figObj = findobj(groot, 'Type', 'figure', 'Name', 'myLD - Objectives');
%   figPar = findobj(groot, 'Type', 'figure', 'Name', 'myLD - c1');
%   drawPrefBands(figObj, 'obj', pref, offsets, {'Preferred','Tolerable','Undesirable'})
%   drawPrefBands(figPar, 'par', offsets)

TAG = 'PrefBand';

axList = findobj(fig, 'Type', 'axes');
axList = flipud(axList);   % tiledlayout stores axes in reverse order

switch lower(mode)

    %% ---- OBJECTIVES: staircase sectors ----------------------------------
    case 'obj'
        pref    = varargin{1};
        offsets = varargin{2}(:);
        labels  = {};
        if numel(varargin) >= 3
            labels = varargin{3};
        end

        nI = size(pref, 2);

        for k = 1:numel(axList)
            ax = axList(k);
            if k > size(pref, 1); continue; end
            hold(ax, 'on');

            xLims = ax.XLim;  yLims = ax.YLim;
            ax.XLimMode = 'manual';  ax.YLimMode = 'manual';

            yBounds = [offsets; yLims(2)];

            % Each sector x is drawn as an L-shape (two non-overlapping
            % rectangles) so FaceAlpha does not accumulate across sectors:
            %   Rect A: new X strip  [xBound(x-1), xBound(x)] × [yLims(1), yBounds(x+1)]
            %   Rect B: extra Y band [xLims(1),    xBound(x-1)] × [yBounds(x), yBounds(x+1)]
            % Sector 1 is a plain rectangle (no predecessor).
            for x = 1:nI
                if x < nI
                    xRight = min(pref(k, x+1), xLims(2));
                else
                    xRight = xLims(2);
                end
                yTop = min(yBounds(x + 1), yLims(2));
                fc   = grayShade(x, nI);

                if x == 1
                    % Plain rectangle from x-axis up
                    patch(ax, [xLims(1) xRight  xRight   xLims(1)], ...
                              [yLims(1) yLims(1) yTop     yTop    ], ...
                        fc, 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
                        'Tag', TAG, 'HandleVisibility', 'off');
                else
                    xPrev = min(pref(k, x), xLims(2));   % right edge of sector x-1
                    yBot  = yBounds(x);

                    % Rect A: right vertical strip (full height from x-axis)
                    if xRight > xPrev
                        patch(ax, [xPrev  xRight xRight xPrev ], ...
                                  [yLims(1) yLims(1) yTop yTop], ...
                            fc, 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
                            'Tag', TAG, 'HandleVisibility', 'off');
                    end

                    % Rect B: extra Y band above previous sector
                    if yTop > yBot && xPrev > xLims(1)
                        patch(ax, [xLims(1) xPrev  xPrev   xLims(1)], ...
                                  [yBot     yBot   yTop    yTop    ], ...
                            fc, 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
                            'Tag', TAG, 'HandleVisibility', 'off');
                    end
                end
            end

            % Frame each sector: top horizontal + right vertical (L-shape)
            for x = 1:nI-1
                xRight = min(pref(k, x+1), xLims(2));
                yTop   = min(yBounds(x + 1), yLims(2));

                % Top edge of sector x
                plot(ax, [xLims(1) xRight], [yTop yTop], '--', ...
                    'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, ...
                    'Tag', TAG, 'HandleVisibility', 'off');

                % Right edge from x-axis to yTop
                if xRight > xLims(1) && xRight < xLims(2)
                    plot(ax, [xRight xRight], [yLims(1) yTop], '--', ...
                        'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, ...
                        'Tag', TAG, 'HandleVisibility', 'off');
                end
            end

            uistack(findobj(ax, 'Type', 'scatter'), 'top');

            % Band labels only on the rightmost subplot, placed outside the
            % right edge with Clipping=off.
            if ~isempty(labels) && k == numel(axList)
                xPos = xLims(2) + 0.015 * (xLims(2) - xLims(1));
                for x = 1:nI
                    if x > numel(labels); continue; end
                    yBot = yBounds(x);
                    yTop = min(yBounds(x + 1), yLims(2));
                    yMid = (yBot + yTop) / 2;
                    if yMid < yLims(1) || yMid > yLims(2); continue; end
                    text(ax, xPos, yMid, labels{x}, ...
                        'Rotation', 0, ...
                        'HorizontalAlignment', 'left', ...
                        'VerticalAlignment', 'middle', ...
                        'FontSize', 9, ...
                        'FontWeight', 'bold', ...
                        'Color', [0.10 0.10 0.10], ...
                        'Tag', TAG, ...
                        'HandleVisibility', 'off', ...
                        'HitTest', 'off', ...
                        'PickableParts', 'none', ...
                        'Clipping', 'off');
                end
            end
        end

    %% ---- PARAMETERS: horizontal bands -----------------------------------
    case 'par'
        offsets = varargin{1}(:);

        nI = numel(offsets);

        for k = 1:numel(axList)
            ax = axList(k);
            hold(ax, 'on');

            xLims = ax.XLim;  yLims = ax.YLim;
            ax.XLimMode = 'manual';  ax.YLimMode = 'manual';

            yBounds = [offsets; yLims(2)];

            for x = 1:nI
                yBot = yBounds(x);
                yTop = yBounds(x + 1);
                if yBot >= yTop; continue; end

                fc = grayShade(x, nI);
                patch(ax, ...
                    [xLims(1) xLims(2) xLims(2) xLims(1)], ...
                    [yBot     yBot     yTop      yTop    ], ...
                    fc, 'EdgeColor', 'none', 'FaceAlpha', 0.35, ...
                    'Tag', TAG, 'HandleVisibility', 'off');

                if x > 1
                    plot(ax, xLims, [offsets(x) offsets(x)], '--', ...
                        'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, ...
                        'Tag', TAG, 'HandleVisibility', 'off');
                end
            end

            uistack(findobj(ax, 'Type', 'scatter'), 'top');
        end

    otherwise
        error('drawPrefBands:unknownMode', ...
            'mode must be ''obj'' or ''par''. Got: ''%s''.', mode);
end
end

%% -------------------------------------------------------------------------
function c = grayShade(x, nTotal)
gMin = 0.3;
gMax = 0.95;
t = (x - 1) / max(nTotal - 1, 1);
g = gMax - t * (gMax - gMin);
c = [g g g];
end
