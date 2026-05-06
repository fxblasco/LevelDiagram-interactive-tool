function printPointInfo(punto)
% printPointInfo  onSelect callback: print details of a selected point.
%
%   Designed to be registered with LevelDiagram.onSelect:
%     ld.onSelect(c1, @printPointInfo)

fprintf('--- Selected point ---\n');
fprintf('Concept    : %s\n', punto.concept);
fprintf('Index      : %d\n', punto.index);
fprintf('Objectives : %s\n', mat2str(punto.objectives, 4));
fprintf('Parameters : %s\n', mat2str(punto.parameters, 4));
fprintf('Sync value : %.4f\n', punto.sync);
