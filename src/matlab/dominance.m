function [x, y] = dominance(P, D)
% [ParetoFront, ParetoSet] = dominance(ObjFunValues, DecVarValues)
%   P  : Matrix with objective function values (each row is a solution)
%   D  : Matrix with decision variable values  (each row is a solution)
%   x  : Pareto Front (non-dominated solutions in objective space)
%   y  : Pareto Set   (non-dominated solutions in decision space)

N = size(P, 1);

if N == 0
    x = zeros(0, size(P, 2));
    y = zeros(0, size(D, 2));
    return;
end

if N == 1
    x = P;
    y = D;
    return;
end

% Threshold: use fully-vectorized 3D approach for moderate N,
% loop-based for large N to avoid excessive memory usage (~N*N*M doubles).
MEM_THRESHOLD = 1e7;   % elements (~80 MB)
if N * N * size(P, 2) <= MEM_THRESHOLD
    dominated = dominance_vectorized(P, N);
else
    dominated = dominance_loops(P, N);
end

x = P(~dominated, :);
y = D(~dominated, :);

%% --- Fully vectorized (no loops, uses 3D broadcasting) ---
function dominated = dominance_vectorized(P, N)
Pi = permute(P, [1, 3, 2]);   % N×1×M
Pj = permute(P, [3, 1, 2]);   % 1×N×M
worse  = Pi > Pj;              % N×N×M: i is worse than j on objective k
better = Pi < Pj;              % N×N×M: i is better than j on objective k
% i dominates j: never worse AND strictly better in at least one objective
dominates = ~any(worse, 3) & any(better, 3);  % N×N logical
dominated  = any(dominates, 1)';              % N×1 logical

%% --- Loop-based with vectorized pairwise comparison ---
function dominated = dominance_loops(P, N)
dominated = false(N, 1);
for i = 1:N-1
    if ~dominated(i)
        for j = i+1:N
            if ~dominated(j)
                d = P(i,:) - P(j,:);
                i_better = any(d < 0);  % i strictly better in some objective
                j_better = any(d > 0);  % j strictly better in some objective
                if i_better && ~j_better      % i dominates j (or equal -> j redundant)
                    dominated(j) = true;
                elseif j_better && ~i_better  % j dominates i
                    dominated(i) = true;
                    break;
                elseif ~i_better && ~j_better % equal: keep i, discard j
                    dominated(j) = true;
                end
                % i_better && j_better: neither dominates, keep both
            end
        end
    end
end
