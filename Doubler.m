classdef Doubler < audioPlugin & matlab.System

    
    properties (DiscreteState)
        Phase1State;
        Phase2State;
    end
    
    properties (Nontunable, Access = protected)
        pMaxDelay = 0.03;
        Overlap = 0.3;
    end
    
    properties (Access = private)
        pRate;
        pSampsDelay;
        pShifter;
        pPhaseStep;
        pFaderGain;
    end
    


    methods
        function plugin = Doubler(varargin)
            setProperties(plugin, nargin, varargin{:});
        end
    end
    


    methods (Access = protected)
        

        function setupImpl(p,~)
            
            % Assume longest delay is 0.03ms and max Fs is 192 kHz
            pMaxDelaySamps = 192e3 * p.pMaxDelay;
            
            p.pShifter = dsp.VariableFractionalDelay('MaximumDelay',pMaxDelaySamps,...
                'InterpolationMethod','farrow');
            
            p.Phase1State = 0;
            p.Phase2State = (1 - p.Overlap);
            
            tuneParameters(p)
        end
        

        function tuneParameters(p)
                        
            p.pRate = (1 - 2^((-5)/12)) / p.pMaxDelay;  % Valor de pitch shift !!!-----
            p.pPhaseStep = p.pRate / getSampleRate(p); % phase step
            p.pFaderGain = 1 / p.Overlap; % gain for overlap fader
        end
        

        function processTunedPropertiesImpl(p)
            tuneParameters(p);
        end
        

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
            y = sum(delayedOut,3);
            delays = [delays1,delays2] / getSampleRate(p);
            gains  = [gains1,gains2];
            
        end
        

        function resetImpl(p)
            p.Phase1State = 0;
            p.Phase2State = (1 - p.Overlap);
            reset(p.pShifter);
            
            p.pSampsDelay = round(p.pMaxDelay * getSampleRate(p));

            tuneParameters(p);
        end

    end
end