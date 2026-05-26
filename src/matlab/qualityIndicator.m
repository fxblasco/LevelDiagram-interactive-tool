function [Q1, Q2] = qualityIndicator(Jp1, Jp2)
% qualityIndicator  Quality indicator Q for design-concept comparison.
%
%   [Q1, Q2] = qualityIndicator(Jp1, Jp2)
%
%   Computes, for each point in Jp1, its quality indicator relative to Jp2
%   and vice versa.  Based on Definition 4 / eq. (14)-(15) of:
%
%     Reynoso-Meza et al., "Comparison of design concepts in multi-criteria
%     decision-making using level diagrams",
%     Information Sciences 221 (2013) 124-141.
%
%   INPUTS
%     Jp1  (n1 x m)  Pareto front of concept 1 (rows = solutions)
%     Jp2  (n2 x m)  Pareto front of concept 2 (rows = solutions)
%
%   OUTPUTS
%     Q1   (n1 x 1)  Quality indicator for each point in Jp1 w.r.t. Jp2
%     Q2   (n2 x 1)  Quality indicator for each point in Jp2 w.r.t. Jp1
%
%   INTERPRETATION (Table 2 in the paper):
%     Q < 1  ->  point strictly improves upon at least one solution in the
%                other front (improvement factor = Q for all objectives)
%     Q = 1  ->  point is not comparable with any solution in the other
%                front (Pareto optimal in other front, or in uncovered region)
%     Q > 1  ->  point is strictly dominated by at least one solution in the
%                other front (dominated by factor Q in all objectives)
%
%   ALGORITHM
%     For each x in front i and front j:
%       1. Normalise both fronts jointly to [1,2] (footnote 8 in paper).
%       2. Compute the ratio-based epsilon indicator for x against each y:
%             epsilon(x, y) = max_l ( x_l / y_l )            (eq. 15)
%       3. q_val = min_{y in Jp_other} epsilon(x, y)         (eq. 14, "otherwise")
%          y*    = argmin_{y in Jp_other} epsilon(x, y)
%       4. If q_val > 1:
%            If epsilon(y*, x) > 1  -> Q = 1  (x and y* mutually non-comparable)
%            Else               -> Q = q_val  (x is dominated)
%          Else                 -> Q = q_val  (x dominates at least one y)

if nargin ~= 2
    error('qualityIndicator:nargin', 'Exactly two Pareto fronts are required.');
end
[n1, m1] = size(Jp1);
[n2, m2] = size(Jp2);
if m1 ~= m2
    error('qualityIndicator:dimMismatch', ...
        'Both fronts must have the same number of objectives (%d vs %d).', m1, m2);
end
if n1 == 0 || n2 == 0
    error('qualityIndicator:emptyFront', 'Pareto fronts must be non-empty.');
end

% Normalise jointly to [1,2] to handle mixed/zero objective values (footnote 8)
combined = [Jp1; Jp2];
J_min = min(combined);
J_max = max(combined);
rng_val = J_max - J_min;
rng_val(rng_val == 0) = 1;      % constant objective: keep normalised value at 1

Jp1n = 1 + bsxfun(@rdivide, bsxfun(@minus, Jp1, J_min), rng_val);
Jp2n = 1 + bsxfun(@rdivide, bsxfun(@minus, Jp2, J_min), rng_val);

Q1 = computeQ(Jp1n, Jp2n);
Q2 = computeQ(Jp2n, Jp1n);
end

% -------------------------------------------------------------------------
function Q = computeQ(Xn, Yn)
% computeQ  Per-point quality indicator of front Xn against front Yn.
n = size(Xn, 1);
Q = zeros(n, 1);
for i = 1:n
    x = Xn(i, :);

    % epsilon(x, y) = max_l(x_l / y_l) for all y in Yn  [vectorised]
    epsilon_xy = max(bsxfun(@rdivide, x, Yn), [], 2);   % (nY x 1)

    [q_val, k_star] = min(epsilon_xy);

    if q_val > 1
        % Check mutual non-comparability: epsilon(y*, x) > 1 as well?
        y_star = Yn(k_star, :);
        epsilon_yx = max(y_star ./ x);
        if epsilon_yx > 1
            Q(i) = 1;       % incomparable / uncovered region -> Q = 1
        else
            Q(i) = q_val;   % x is dominated
        end
    else
        Q(i) = q_val;       % x dominates (or matches) some solution in Yn
    end
end
end
