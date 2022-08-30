function [b, a] = vocalFilter(fc, fs)

    q = 0.707; % Q del filtro
    w0 = 2*pi*fc/fs; % Frecuencia angular (rad/s)
    alpha = sin(w0)/(2*q); % Ancho del filtro
    
    b0 =  (1 + cos(w0))/2;
    b1 = -(1 + cos(w0));
    b2 =  (1 + cos(w0))/2;
    
    a0 =   1 + alpha;
    a1 =  -2*cos(w0);
    a2 =   1 - alpha;
    
    b = [b0 ,b1, b2];
    a = [a0, a1, a2];
    
end