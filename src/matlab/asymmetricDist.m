function d = asymmetricDist(x, y)
% asymmetricDist  Asymmetric distance d = norm(max(y - x, 0))
%
% Measures how much y needs to move to dominate x (component-wise).
%
% Cases supported:
%   x: (1 x p),  y: (1 x p)   -> d: scalar
%   x: (n x p),  y: (1 x p)   -> d: (n x 1)  distance from each row of x to point y
%   x: (1 x p),  y: (n x p)   -> d: (n x 1)  distance from point x to each row of y

if size(x, 2) ~= size(y, 2)
    error('asymmetricDist:dimMismatch', ...
        'x and y must have the same number of columns.');
end
if size(x, 1) > 1 && size(y, 1) > 1
    error('asymmetricDist:ambiguous', ...
        'Only one input can be a matrix. The other must be a row vector.');
end

d = sqrt(sum(max(y - x, 0).^2, 2));
end
