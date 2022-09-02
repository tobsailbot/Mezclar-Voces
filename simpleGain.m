classdef simpleGain < audioPlugin
    
    properties
        nMuestras;
        retardo ;
    end

    methods
        
        function out=process(p,in)
            
            canalIzq(:,1) = [in(1:end-(p.nMuestras),1) ; p.retardo];
            
            canalDer(:,2) = [p.retardo; in(1:end-(p.nMuestras),2)];
            
            out = [canalIzq , canalDer];
        end
        
        function reset(p)
            p.retardo = zeros(5,1);
            p.nMuestras = 5;
        end
    end
    
end