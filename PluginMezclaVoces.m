classdef PluginMezclaVoces < audioPlugin 
    
    properties
        Value = 0;
    end
    
    properties (Access = private)
        EQ;
        Compressor;
        Crossover;
        Desser;
        Wet;
        lockPhase = true;
    end
    
    properties(Constant)
        PluginInterface = ... % Interfaz gráfica
        audioPluginInterface( ...
        ...
        audioPluginParameter('Value', ...
        'DisplayName','Dry / Wet', ...
        'Mapping',{'lin', 0, 1}))
    end
    
    methods
    function out = process(p, in)
        p.Wet = step(p.EQ, in); % 2. Aplica EQ
        p.Wet = step(p.Compressor, p.Wet(:,1:2)); % aplica compresion (:,1:2)) -> canal estereo
        [band1,band2,band3] = step(p.Crossover, p.Wet(:,1:2)); % crossover obtiene 3 bandas
        band3 = step(p.Desser, band3); % comprime la banda 3 , deesser
        p.Wet = (band1 + band2 + band3)*1.85; % suma las bandas 
        
        % usar tecnica de wet dry del paneo por diferencia , usando
        % relacion radio
        d = p.Value; 
        wet = d*p.Wet;
        dry = (1-d)*in;
        
        out = wet + dry ;

    end
    
    function plugin = PluginMezclaVoces % Creación del objeto EQ
        plugin.EQ = multibandParametricEQ(...
                     'NumEQBands',1, ...
                     'Frequencies',410, ...
                     'QualityFactors',0.66, ...
                     'PeakGains',-2.4, ...
                     ...
                     'HasHighpassFilter',true,...
                     'HighpassCutoff',95,...
                     'HighpassSlope',10,...
                     ...
                     'HasHighShelfFilter',true, ...
                     'HighShelfCutoff',8800, ...
                     'HighShelfSlope',0.45, ...
                     'HighShelfGain',3.2);

        plugin.Compressor = compressor(-22,8,... % tresh, ratio
                     'AttackTime',25e-3,...
                     'ReleaseTime',200e-3,...
                     'MakeUpGainMode','Property');
                 
        plugin.Crossover = crossoverFilter( ...
                    'NumCrossovers',2, ...
                    'CrossoverFrequencies',[150,5600], ...
                    'CrossoverSlopes',48);
                
        plugin.Desser = compressor(-42,125,... % tresh, ratio
                     'AttackTime',3e-3,...
                     'ReleaseTime',20e-3,...
                     'MakeUpGainMode','Property');
    end
 
    
    function reset(plugin)
        plugin.EQ.SampleRate = getSampleRate(plugin);
        plugin.Compressor.SampleRate = getSampleRate(plugin);
        plugin.Crossover.SampleRate = getSampleRate(plugin);
        plugin.Desser.SampleRate = getSampleRate(plugin);
    end
    
    
    end
end