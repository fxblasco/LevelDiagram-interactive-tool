function displayGPPInfo(punto)
% displayGPPInfo  onSelect callback: print GPP index and class labels for a
%   selected solution.
%
%   Designed to be registered with LevelDiagram.onSelect:
%     ld.onSelect(c1, @displayGPPInfo)
%
%   The preference table and range labels are defined here and must be kept
%   consistent with those used in accBenchmarkExample.m.

pref = [-10 -0.01 -0.005 -0.001 -0.0005 -0.0001;
          0  0.85    0.9      1     1.5       2;
          0    14     20     30      35      40;
          0   0.5    0.9    1.2     1.4     1.5;
          0   0.5    0.7      1     1.5       2;
          0    10     11     15      20      25];
etiqPref = {'HD','D','T','U','HU'};

[valGPP, etiquetas] = gppl(punto.objectives, pref, etiqPref);

fprintf('----- GPP info -----\n');
fprintf('Concept : %s\n', punto.concept);
fprintf('Index   : %d\n', punto.index);
fprintf('GPP     : %s\n', mat2str(valGPP));
fprintf('Labels  : %s\n', etiquetas{1});
