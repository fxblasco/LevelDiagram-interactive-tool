function verPunto(punto)
    fprintf(['--------------funcion que se ejecuta al hacer click -------------------------\n'], punto.concept);
    fprintf('Concepto: %s\n', punto.concept);
    fprintf('Índice: %d\n', punto.index);
    fprintf('Objetivos: %s\n', mat2str(punto.objectives, 4));
    fprintf('Parámetros: %s\n', mat2str(punto.parameters, 4));
    fprintf('Sync: %.4f\n', punto.sync);
end