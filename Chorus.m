classdef Chorus < audioPlugin
%Chorus Add chorus effect to an audio signal.
%
%   CHORUS = audiopluginexample.Chorus() returns an object CHORUS with
%   properties set to their default values.
%
%   Chorus methods:
%
%   Y = process(CHORUS, X) adds chorus effect to the audio input X based on
%   the properties specified in the object CHORUS and returns it as output
%   Y. Each column of X is treated as individual input channels.
%
%   Chorus properties:
%
%   Delay       - Base delay in seconds
%   Depth1      - Amplitude of first sine wave modulator
%   Rate1       - Frequency of first sine wave modulator
%   Depth2      - Amplitude of second sine wave modulator
%   Rate2       - Frequency of second sine wave modulator
%   WetDryMix   - Wet to dry signal ratio
%
%   % Example 1: Simulate Chorus in MATLAB.
%   reader = dsp.AudioFileReader('RockDrums-44p1-stereo-11secs.mp3',...
%                                'SamplesPerFrame', 1024,...
%                                'PlayCount', 1);
%
%   player = audioDeviceWriter('SampleRate', reader.SampleRate);
%
%   chorus = audiopluginexample.Chorus;
%
%   while ~isDone(reader)
%       x = reader();
%       y = process(chorus, x);
%       player(y);
%   end
%   release(reader)
%   release(player)
%
%   % Example 2: Validate and generate a VST plugin
%   validateAudioPlugin audiopluginexample.Chorus
%   generateAudioPlugin audiopluginexample.Chorus
%
%   % Example 3: Launch a test bench for the Chorus object
%   chorus = audiopluginexample.Chorus;
%   audioTestBench(chorus);
%
%   See also: audiopluginexample.Echo, audiopluginexample.Flanger

%   Copyright 2015-2020 The MathWorks, Inc.
%#codegen
    
    %----------------------------------------------------------------------
    % Public properties
    %----------------------------------------------------------------------
    properties
        %Delay Base delay
        %   Specify the base delay for chorus effect as positive scalar
        %   value in seconds. Base delay value must be in the range between
        %   0 and 0.1 seconds. The default value of this property is 0.02.
        Delay = 0.02
    end
        
    properties 
        %Depth1 Amplitude of first sine wave modulator
        %   Specify the amplitude of first modulating sine wave as a
        %   positive scalar value. The sinewave are added to the base delay
        %   value to make the delay sinusoidally modulating. This value
        %   must range between 0 to 10. The default value of this property
        %   is 0.01
        Depth1 = 0.01
        
        %Rate1 Frequency of first sine wave modulator
        %   Specify the frequency of the first sine wave as a positive
        %   scalar value in Hz. This property controls the chorus rate.
        %   This value must range from 0 to 10 Hz. The default value of
        %   this property is 0.01.
        Rate1 = 0.01
        
        %Depth2 Amplitude of second sine wave modulator
        %   Specify the amplitude of second modulating sine wave as a
        %   positive scalar value. The sinewave are added to the base delay
        %   value to make the delay sinusoidally modulating. This value
        %   must range between 0 to 10. The default value of this property
        %   is 0.03
        Depth2 = 0.03
        
        %Rate2 Frequency of second sine wave modulator
        %   Specify the frequency of the second sine wave as a positive
        %   scalar value in Hz. This property controls the chorus rate.
        %   This value must range from 0 to 10 Hz. The default value of
        %   this property is 0.02.
        Rate2 = 0.02
    end
    
    properties        
        %WetDryMix Wet/dry mix
        %   Specify the wet/dry mix ratio as a positive scalar. This value
        %   ranges from 0 to 1. For example, for a value of 0.6, the
        %   ratio will be 60% wet to 40% dry signal (Wet - Signal that has
        %   effect in it. Dry - Unaffected signal). The default value of
        %   this property is 0.5.
        WetDryMix = 0.5
    end
    
    properties (Constant)
        % audioPluginInterface manages the number of input/output channels
        % and uses audioPluginParameter to generate plugin UI parameters.
        PluginInterface = audioPluginInterface(...
            'InputChannels',2,...
            'OutputChannels',2,...
            'PluginName','Chorus',...
            'VendorName','',...
            'VendorVersion','3.1.4',...
            'UniqueId','ipsg',...
            audioPluginParameter('Delay','DisplayName','Base delay','Label','s','Mapping',{'lin' 0 0.2}, ...
            'Style', 'rotaryknob', 'Layout', [4 3]),...
            audioPluginParameter('Depth1','DisplayName','Depth 1','Label','','Mapping',{'lin' 0 10}, ...
            'Style', 'vslider', 'Layout', [1 1; 2 1]),...
            audioPluginParameter('Rate1','DisplayName','Rate 1','Label','Hz','Mapping',{'lin' 0 10}, ...
            'Style', 'rotaryknob', 'Layout', [4 1]),...
            audioPluginParameter('Depth2','DisplayName','Depth 2','Label','','Mapping',{'lin' 0 10}, ...
            'Style', 'vslider', 'Layout', [1 2; 2 2]),...
            audioPluginParameter('Rate2','DisplayName','Rate 2','Label','Hz','Mapping',{'lin' 0 10}, ...
            'Style', 'rotaryknob', 'Layout', [4 2]),...
            audioPluginParameter('WetDryMix','DisplayName','Wet/dry mix','Label','','Mapping',{'lin' 0 1}, ...
            'Style', 'rotaryknob', 'Layout', [2 3]), ...
            audioPluginGridLayout('RowHeight', [90 100 20 100 20], ...
            'ColumnWidth', [100 100 100], 'Padding', [10 10 10 30]), ...
            'BackgroundImage', audiopluginexample.private.mwatlogo);
    end
    
    %----------------------------------------------------------------------
    % Private properties
    %----------------------------------------------------------------------
    properties (Access = private, Hidden)
        %pFractionalDelay Delay Filter object for fractional delay with
        %linear interpolation
        pFractionalDelay

        %pSine1 and pSine2 Oscillators
        pSine1
        pSine2
        
        %pSR Sample rate
        pSR
    end
    
    %----------------------------------------------------------------------
    % public methods
    %----------------------------------------------------------------------
    methods
        function obj = Chorus
            fs = getSampleRate(obj);
            
            % Create the modulators
            obj.pSine1 = audioOscillator('Frequency', 0.01,...
                'Amplitude', 0.01, 'SampleRate', fs);
            obj.pSine2 = audioOscillator('Frequency', 0.02,...
                'Amplitude', 0.03, 'SampleRate', fs);
            
            % Create fractional delay
            obj.pFractionalDelay = dsp.VariableFractionalDelay(...
                'MaximumDelay',65000);
            
            obj.pSR = fs;
        end
        
        function set.Depth1(obj, val)
            obj.pSine1.Amplitude = val;%#ok<MCSUP>
        end
        function val = get.Depth1(obj)
            val = obj.pSine1.Amplitude;
        end
        
        function set.Rate1(obj, val)
            obj.pSine1.Frequency = val;%#ok<MCSUP>
        end
        function val = get.Rate1(obj)
            val = obj.pSine1.Frequency;
        end
        
        function set.Depth2(obj, val)
            obj.pSine2.Amplitude = val;%#ok<MCSUP>
        end
        function val = get.Depth2(obj)
            val = obj.pSine2.Amplitude;
        end
        
        function set.Rate2(obj, val)
            obj.pSine2.Frequency = val;%#ok<MCSUP>
        end
        function val = get.Rate2(obj)
            val = obj.pSine2.Frequency;
        end
        
        function reset(obj)
            % Reset sample rate
            fs = getSampleRate(obj);
            obj.pSR = fs;
            
            % Reset oscillators
            obj.pSine1.SampleRate = fs;
            obj.pSine2.SampleRate = fs;
            reset(obj.pSine1);
            reset(obj.pSine2);
            
            % Reset delay
            reset(obj.pFractionalDelay);  
        end
        
        function out = process(obj, x)
            
            fs = obj.pSR;
            oscillator1 = obj.pSine1;
            oscillator2 = obj.pSine2;
            
            numSamples = size(x,1);

            % Compute the base delay value in samples
            delayInSamples = obj.Delay*fs;
            
            % Set frame size of oscillator objects
            oscillator1.SamplesPerFrame = numSamples;
            oscillator2.SamplesPerFrame = numSamples;
            
            % Create modulated delay vectors
            [d1 , d2] = size(x);

            % Get delayed input
            delayVector = zeros(d1,d2,2);
            delayVector(:,:,1) = repmat(delayInSamples+oscillator1(),1,2);
            delayVector(:,:,2) = repmat(delayInSamples+oscillator2(),1,2);
            y = obj.pFractionalDelay(x,delayVector);

            % Calculating output by adding wet and dry signal in
            % appropriate ratio
            mix = obj.WetDryMix;
            out = ((1-mix).*x) + (mix.*sum(y,3));
        end
    end
end