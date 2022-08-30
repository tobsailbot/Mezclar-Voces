classdef distorConEQ < audioPlugin
    
    properties% Parámetros controlados por el usuario
    gain = 1;
    level = 1;
    fEQ = 1000;
    gainEQ = 0;
    end
    
    properties(Constant)
    PluginInterface = ... % Interfaz gráfica
    audioPluginInterface( ...
    ...
    audioPluginParameter('gain', ...
    'DisplayName','Drive', ...
    'Mapping',{'lin', 1, 10}), ...
    ...
    audioPluginParameter('fEQ', ...
    'DisplayName','Frequency', ...
    'Mapping',{'log', 80, 16000}), ...
    ...
    audioPluginParameter('gainEQ', ...
    'DisplayName','Frequency gain', ...
    'Mapping',{'lin', -12, 12}), ...
    ...
    audioPluginParameter('level', ...
    'DisplayName','Master level', ...
    'Mapping',{'lin', 0, 2}));
    end
    
    properties (Access = private)
    EQ;
    end
    
    methods
    function out = process(plugin, in)
    out = ((2/pi) * atan(in * plugin.gain)); % 1. Soft clipping
    out = step(plugin.EQ, out); % 2. Aplica EQ
    out = out * plugin.level; % 3. Nivel de salida
    end
    
    function plugin = distorConEQ % Creación del objeto EQ
    plugin.EQ = multibandParametricEQ('NumEQBands',1,'EQOrder',2);
    end
    
    function set.fEQ(plugin,fEQ) % Al detectar un cambio en
    plugin.fEQ = fEQ; % el fader, actualiza la
    plugin.EQ.Frequencies(1) = fEQ; % frecuencia en el EQ
    end
    
    function set.gainEQ(plugin,gainEQ) % Al detectar un cambio en
    plugin.gainEQ = gainEQ; % el fader, actualiza el
    plugin.EQ.PeakGains(1) = gainEQ; % pico de amplitud en el EQ
    end
    
    function reset(plugin)
    plugin.EQ.SampleRate = getSampleRate(plugin);
    end
    
    end
end