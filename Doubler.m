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
        EQ_2;
        Compressor;
        Crossover;
        Desser;
        Wet;
        
        pSampsDelay;
        pShifter_1;
        pShifter_2;
        pFaderGain;

        pRate_1;
        pPhaseStep_1;
        pRate_2;
        pPhaseStep_2;

        Phase1State_1;
        Phase2State_1;
        Phase1State_2;
        Phase2State_2;
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
                             'HighShelfGain',3.6); % 3.2

                plugin.Compressor = compressor(-24,12,... % tresh, ratio
                             'AttackTime',15e-3,...
                             'ReleaseTime',200e-3,...
                             'MakeUpGainMode','Property');

                plugin.Crossover = crossoverFilter( ...
                            'NumCrossovers',2, ...
                            'CrossoverFrequencies',[150,5600], ...
                            'CrossoverSlopes',48);

                plugin.Desser = compressor(-42,800,... % tresh, ratio
                             'AttackTime',3e-3,...
                             'ReleaseTime',20e-3,...
                             'MakeUpGainMode','Property');
                plugin.EQ_2 = multibandParametricEQ(...
                             'NumEQBands',1, ...
                             'Frequencies',410, ...
                             'QualityFactors',0.66, ...
                             'PeakGains',-1, ...
                             'HasHighpassFilter',true,...
                             'HighpassCutoff',80,...
                             'HighpassSlope',10,...
                             'HasHighShelfFilter',true, ...
                             'HighShelfCutoff',12000, ... &8800
                             'HighShelfSlope',0.45, ...
                             'HighShelfGain',6); % 3.2

                plugin.EQ.SampleRate = getSampleRate(plugin);
                plugin.EQ_2.SampleRate = getSampleRate(plugin);
                plugin.Compressor.SampleRate = getSampleRate(plugin);
                plugin.Crossover.SampleRate = getSampleRate(plugin);
                plugin.Desser.SampleRate = getSampleRate(plugin);
            end
                 
    end



    methods (Access = protected)
        
        function setupImpl(p,~)
            
            % Assume longest delay is 0.03ms and max Fs is 192 kHz
            pMaxDelaySamps = 192e3 * p.pMaxDelay;
            
            p.pShifter_1 = dsp.VariableFractionalDelay('MaximumDelay',pMaxDelaySamps,...
                'InterpolationMethod','farrow');

            p.pShifter_2 = dsp.VariableFractionalDelay('MaximumDelay',pMaxDelaySamps,...
                'InterpolationMethod','farrow');
            
            p.Phase1State_1 = 0;
            p.Phase2State_1 = (1 - p.Overlap);

            p.Phase1State_2 = 0;
            p.Phase2State_2 = (1 - p.Overlap);
            
        end
        
        
        % esta funcion reemplaza process
        function [y,delays,gains] = stepImpl(p,input)

            blockSize = size(input,1); % Number of samples in the input
            
            gains1_1 = zeros(blockSize,1); % Gain for first delay line
            gains2_1 = zeros(blockSize,1); % Gain for second delay line

            gains1_2 = zeros(blockSize,1); % Gain for first delay line
            gains2_2 = zeros(blockSize,1); % Gain for second delay line
            
            delays1_1 = zeros(blockSize,1); % Delay for first delay line
            delays2_1 = zeros(blockSize,1);

            delays1_2 = zeros(blockSize,1); % Delay for first delay line
            delays2_2 = zeros(blockSize,1);
            
            ph1_1   = p.Phase1State_1;
            ph2_1   = p.Phase2State_1;
            ph1_2   = p.Phase1State_2;
            ph2_2   = p.Phase2State_2;

            pstep_1 = p.pPhaseStep_1;
            pstep_2 = p.pPhaseStep_2;
            ovrlp = p.Overlap;
            sd    =  p.pSampsDelay;
            fgain = p.pFaderGain;


            for i = 1:blockSize
                
                ph1_1 = mod((ph1_1 + pstep_1),1);
                ph2_1 = mod((ph2_1 + pstep_1),1);
                
                ph1_2 = mod((ph1_2 + pstep_2),1);
                ph2_2 = mod((ph2_2 + pstep_2),1);
                

                if((ph1_1 < ovrlp) && (ph2_1 >= (1 - ovrlp)))
                    
                    delays1_1(i) = sd * ph1_1;
                    delays2_1(i) = sd * ph2_1;

                    gains1_1(i) = cos((1 - (ph1_1* fgain)) * pi/2);
                    gains2_1(i) = cos(((ph2_1 - (1 - ovrlp)) * fgain) * pi/2);
                    
                elseif((ph1_1 > ovrlp) && (ph1_1 < (1 - ovrlp)))
                    
                    ph2_1 = 0;
                    delays1_1(i) = sd * ph1_1;
                    
                    gains1_1(i) = 1;
                    gains2_1(i) = 0;
                    
                elseif((ph1_1 >= (1 - ovrlp)) && (ph2_1 < ovrlp))
                    
                    delays1_1(i) = sd * ph1_1;
                    delays2_1(i) = sd * ph2_1;

                    gains1_1(i) = cos(((ph1_1 - (1 - ovrlp)) * fgain) * pi/2);
                    gains2_1(i) = cos((1 - (ph2_1* fgain)) * pi/2);

                elseif((ph2_1 > ovrlp) && (ph2_1 < (1 - ovrlp)))
                    
                    ph1_1 = 0;
                    delays2_1(i) = sd * ph2_1;
                    
                    gains1_1(i) = 0;
                    gains2_1(i) = 1;
                    
                end
                

                if((ph1_2 < ovrlp) && (ph2_2 >= (1 - ovrlp)))
                    
                    delays1_2(i) = sd * ph1_2;
                    delays2_2(i) = sd * ph2_2;

                    gains1_2(i) = cos((1 - (ph1_2* fgain)) * pi/2);
                    gains2_2(i) = cos(((ph2_2 - (1 - ovrlp)) * fgain) * pi/2);
                    
                elseif((ph1_2 > ovrlp) && (ph1_2 < (1 - ovrlp)))
                    
                    ph2_2 = 0;
                    delays1_2(i) = sd * ph1_2;
                    
                    gains1_2(i) = 1;
                    gains2_2(i) = 0;
                    
                elseif((ph1_2 >= (1 - ovrlp)) && (ph2_2 < ovrlp))
                    
                    delays1_2(i) = sd * ph1_2;
                    delays2_2(i) = sd * ph2_2;

                    gains1_2(i) = cos(((ph1_2 - (1 - ovrlp)) * fgain) * pi/2);
                    gains2_2(i) = cos((1 - (ph2_2* fgain)) * pi/2);
                    
                elseif((ph2_2 > ovrlp) && (ph2_2 < (1 - ovrlp)))
                    
                    ph1_2 = 0;
                    delays2_2(i) = sd * ph2_2;
                    
                    gains1_2(i) = 0;
                    gains2_2(i) = 1;
                    
                end
            end

            
            p.Phase1State_1 = ph1_1;
            p.Phase2State_1 = ph2_1;
            
            % ------- Get delayed output for pitch 1
            dly_1 = zeros(blockSize,1,2);
            dly_1(:,:,1) = delays1_1;
            dly_1(:,:,2) = delays2_1;
            delayedOut_1 = p.pShifter_1(input,dly_1);
   
            for i = 1:size(input,2)
                delayedOut_1(:,i,1) = delayedOut_1(:,i,1) .* gains1_1;
                delayedOut_1(:,i,2) = delayedOut_1(:,i,2) .* gains2_1;
            end

            % ---Sum to create output for pitch 1
            pitch_1 = sum(delayedOut_1,3); % se multiplica por la ganancia
            pitch_left_1 = pitch_1(:,1);

            delays = [delays1_1,delays2_1] / getSampleRate(p);
            gains  = [gains1_1,gains2_1];
            
            
        %------------ el problema esta en este bloque --------------------
            p.Phase1State_2 = ph1_2;
            p.Phase2State_2 = ph2_2;

            % Get delayed output for pitch 2
            dly_2 = zeros(blockSize,1,2);
            dly_2(:,:,1) = delays1_2;
            dly_2(:,:,2) = delays2_2;
            delayedOut_2 = p.pShifter_2(input,dly_2);
   
            for i = 1:size(input,2)
                delayedOut_2(:,i,1) = delayedOut_2(:,i,1) .* gains1_2;
                delayedOut_2(:,i,2) = delayedOut_2(:,i,2) .* gains2_2;
            end

            pitch_2 = sum(delayedOut_2,3); % se multiplica por la ganancia
            pitch_right_2 = pitch_2(:,2);
 
            
        % ---------------------------------------------------------
            
            
            % u = input  -  u es la señal de entrada

          % -------- proceso mezcla voces ----------
            p.Wet = step(p.EQ, input); % 2. Aplica EQ
            p.Wet = step(p.Compressor, p.Wet(:,1:2)); % aplica compresion (:,1:2)) -> canal estereo
            [band1,band2,band3] = step(p.Crossover, p.Wet(:,1:2)); % crossover obtiene 3 bandas
            band3 = step(p.Desser, band3); % comprime la banda 3 , deesser
            p.Wet = (band1 + band2 + band3); % suma las bandas del crossover
            p.Wet = ((2/pi) * atan(p.Wet * 6))*0.6; % Drive soft clipping
            
            pitch_total = [pitch_left_1 , pitch_right_2] *0;
            p.Wet = p.Wet + pitch_total; % agrega el audio pitched
            p.Wet = step(p.EQ_2, p.Wet(:,1:2)); % aplica ultima ecualizacion EQ_2
            p.Wet = (p.Wet);
            % usar tecnica de wet dry del paneo por diferencia , usando
            % relacion radio
            d = p.Value; 
            wet = d*p.Wet;
            dry = (1-d)*input;
            
            y = wet + dry ;
            %y = pitch_total;
        end


        % esta funcion reemplaza reset
        function resetImpl(p)
            
            p.Phase1State_1 = 0;
            p.Phase2State_1 = (1 - p.Overlap);
            p.Phase1State_2 = 0;
            p.Phase2State_2 = (1 - p.Overlap);
            
            reset(p.pShifter_1);
            reset(p.pShifter_2);
            
            p.pSampsDelay = round(p.pMaxDelay * getSampleRate(p));

            p.pRate_1 = (1 - 2^((-0.2)/12)) / p.pMaxDelay;  % Valor de pitch shift !!!-----
            p.pPhaseStep_1 = p.pRate_1 / getSampleRate(p); % phase step 1

            p.pRate_2 = (1 - 2^((0.2)/12)) / p.pMaxDelay;  % Valor de pitch shift !!!-----
            p.pPhaseStep_2 = p.pRate_2 / getSampleRate(p); % phase step 2

            p.pFaderGain = 1 / p.Overlap; % gain for overlap fader

        end

    end
end