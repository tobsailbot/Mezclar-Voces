classdef Doubler < audioPlugin & matlab.System

    properties
        Value = 0;
    end

   properties (Nontunable, Access = protected)
        pMaxDelay = 0.03;
        Overlap = 0.3;
    end

    properties (Access = private)
        EQ;
        Compressor;
        Crossover;
        Desser;
        Wet;
        lockPhase = true;

        pRate;
        pSampsDelay;
        pShifter;
        pPhaseStep;
        pFaderGain;
        Phase1State;
        Phase2State;
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
            function plugin = Doubler % Creación del objeto EQ
                plugin.EQ = multibandParametricEQ(...
                             'NumEQBands',1, ...
                             'Frequencies',410, ...
                             'QualityFactors',0.66, ...
                             'PeakGains',-2.4, ...
                             'HasHighpassFilter',true,...
                             'HighpassCutoff',95,...
                             'HighpassSlope',10,...
                             'HasHighShelfFilter',true, ...
                             'HighShelfCutoff',8800, ... &8800
                             'HighShelfSlope',0.45, ...
                             'HighShelfGain',5); % 3.2

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
                         
                plugin.EQ.SampleRate = getSampleRate(plugin);
                plugin.Compressor.SampleRate = getSampleRate(plugin);
                plugin.Crossover.SampleRate = getSampleRate(plugin);
                plugin.Desser.SampleRate = getSampleRate(plugin);
            end
                 
    end
    
    

    methods (Access = protected)
        
        function setupImpl(obj,~)
            
            % Assume longest delay is 0.03ms and max Fs is 192 kHz
            pMaxDelaySamps = 192e3 * obj.pMaxDelay;
            
            obj.pShifter = dsp.VariableFractionalDelay('MaximumDelay',pMaxDelaySamps,...
                'InterpolationMethod','farrow');
            
            obj.Phase1State = 0;
            obj.Phase2State = (1 - obj.Overlap);
            
        end
        
        
        % esta funcion reemplaza process
        function [y,delays,gains] = stepImpl(p,u)

            blockSize = size(u,1); % Number of samples in the input
            
            gains1 = zeros(blockSize,1); % Gain for first delay line
            gains2 = zeros(blockSize,1); % Gain for second delay line
            
            delays1 = zeros(blockSize,1); % Delay for first delay line
            delays2 = zeros(blockSize,1);
            
            if(p.pRate == 0) 
                y = u;
                delays = [delays1,delays2];
                gains  = [gains1,gains2];
                return;
            end
            
            ph1   = p.Phase1State;
            ph2   = p.Phase2State;
            pstep = p.pPhaseStep;
            ovrlp = p.Overlap;
            sd    =  p.pSampsDelay;
            fgain = p.pFaderGain;
            
            for i = 1:blockSize
                
                ph1 = mod((ph1 + pstep),1);
                ph2 = mod((ph2 + pstep),1);
                
                % delayline2 is approaching its end. fade in delayline1
                if((ph1 < ovrlp) && (ph2 >= (1 - ovrlp)))
                    
                    delays1(i) = sd * ph1;
                    delays2(i) = sd * ph2;

                    gains1(i) = cos((1 - (ph1* fgain)) * pi/2);
                    gains2(i) = cos(((ph2 - (1 - ovrlp)) * fgain) * pi/2);
                    
                    % delayline1 is active
                elseif((ph1 > ovrlp) && (ph1 < (1 - ovrlp)))
                    
                    % delayline2 shouldn't move while delayline1 is active
                    ph2 = 0;
                    
                    delays1(i) = sd * ph1;
                    
                    gains1(i) = 1;
                    gains2(i) = 0;
                    
                    % delayline1 is approaching its end. fade in delayline2
                elseif((ph1 >= (1 - ovrlp)) && (ph2 < ovrlp))
                    
                    delays1(i) = sd * ph1;
                    delays2(i) = sd * ph2;

                    gains1(i) = cos(((ph1 - (1 - ovrlp)) * fgain) * pi/2);
                    gains2(i) = cos((1 - (ph2* fgain)) * pi/2);
                    
                    % delayline2 is active
                elseif((ph2 > ovrlp) && (ph2 < (1 - ovrlp)))
                    
                    % delayline1 shouldn't move while delayline2 is active
                    ph1 = 0;
                    
                    delays2(i) = sd * ph2;
                    
                    gains1(i) = 0;
                    gains2(i) = 1;
                    
                end
            end
            
            p.Phase1State = ph1;
            p.Phase2State = ph2;
            
            % Get delayed output
            dly = zeros(blockSize,1,2);
            dly(:,:,1) = delays1;
            dly(:,:,2) = delays2;
            delayedOut = p.pShifter(u,dly);
   
            for i = 1:size(u,2)
                delayedOut(:,i,1) = delayedOut(:,i,1) .* gains1;
                delayedOut(:,i,2) = delayedOut(:,i,2) .* gains2;
            end
            
            % Sum to create output
            pitch = sum(delayedOut,3) * 0.1; % se reduce la señal a la mitad
            y = pitch;
            delays = [delays1,delays2] / getSampleRate(p);
            gains  = [gains1,gains2];

            %y = u;
            % u = input  -  u es la señal de entrada
            
        % -------- proceso mezcla voces ----------
            p.Wet = step(p.EQ, u); % 2. Aplica EQ
            p.Wet = step(p.Compressor, p.Wet(:,1:2)); % aplica compresion (:,1:2)) -> canal estereo
            [band1,band2,band3] = step(p.Crossover, p.Wet(:,1:2)); % crossover obtiene 3 bandas
            band3 = step(p.Desser, band3); % comprime la banda 3 , deesser
            p.Wet = (band1 + band2 + band3)*1.85; % suma las bandas 
            p.Wet = p.Wet + pitch;
            % usar tecnica de wet dry del paneo por diferencia , usando
            % relacion radio
            d = p.Value; 
            wet = d*p.Wet;
            dry = (1-d)*u;
            
            y = wet + dry ;
            
            %y = pitch;
        end


        % esta funcion reemplaza reset
        function resetImpl(p)
            
            p.Phase1State = 0;
            p.Phase2State = (1 - p.Overlap);
            reset(p.pShifter);
            
            p.pSampsDelay = round(p.pMaxDelay * getSampleRate(p));

            p.pRate = (1 - 2^((-3)/12)) / p.pMaxDelay;  % Valor de pitch shift !!!-----
            p.pPhaseStep = p.pRate / getSampleRate(p); % phase step
            p.pFaderGain = 1 / p.Overlap; % gain for overlap fader

        end

    end
end