function Md = dominanceCone(M)
% dominanceCone  Compute the dominance cone matrix from preference directions.
%
%   Md = dominanceCone(M)
%
%   Given a set of preference directions M (one per column), computes the
%   dominance cone matrix Md whose columns are the dominance vectors dual
%   to the preference directions. The dominance cone defines a generalised
%   dominance relation in objective space aligned with the decision-maker's
%   preferences.
%
%   Each dominance vector vd_i is orthogonal to all preference directions
%   except v_i, and is oriented so that vd_i · v_i > 0 (same half-space).
%   All dominance vectors are unit-normalised.
%
%   Inputs
%   ------
%   M  : (nobj x nobj) matrix of preference directions.
%        Each column is a preference direction vector v_i.
%        The columns must be linearly independent.
%
%   Output
%   ------
%   Md : (nobj x nobj) dominance cone matrix.
%        Each column vd_i is the dominance vector associated with v_i.
%
%   Usage
%   -----
%   Once Md is obtained, express the objective matrix J in the dominance
%   cone basis by applying the inverse change of basis:
%
%       Md   = dominanceCone(M);
%       J_dc = (Md \ J')';      % (ns x nobj) — J in the cone basis
%                               % equivalent to (inv(Md) * J')'
%
%   Reference
%   ---------
%   Blasco, X., Herrero, J.M., Reynoso-Meza, G., Ramos, C. (2021).
%   Preference-based multi-objective engineering design problems through
%   a new preference model. Application to a Level Diagram-based decision
%   support system.
%   Engineering Applications of Artificial Intelligence, 100, 104152.
%   https://doi.org/10.1016/j.engappai.2021.104152
%
%   (c) 2018 CPOH - Universitat Politecnica de Valencia
%   cpoh.upv.es

n  = size(M, 1);
Md = zeros(n, n);

for i = 1:n
    % Remove the i-th column to build the complementary subspace
    Maux = M;
    Maux(:, i) = [];
    vi = M(:, i)';   % i-th preference direction (row vector)

    % Build a (n x n) system whose solution is orthogonal to all columns of
    % Maux. A pivot row is added to avoid a singular matrix (det = 0).
    for ii = 1:n
        A        = [Maux'; zeros(1, n)];
        A(end, ii) = 1;
        if det(A) ~= 0
            break;
        end
    end
    B      = zeros(n, 1);
    B(end) = 1;

    % Solve A * vd = B
    vaux1 = (A \ B)';

    % Choose the orientation consistent with vi (vd · vi > 0)
    vaux2 = -vaux1;
    if (vaux1 * vi') > (vaux2 * vi')
        Md(:, i) = vaux1' / norm(vaux1);
    else
        Md(:, i) = vaux2' / norm(vaux2);
    end
end
end
