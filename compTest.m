clear;clc
% EXAMPLE 2: Attack and Release Time Demonstration
    % This example uses a simple rectangular pulse input to showcase the
    % compressor's attack and release times
    Fs = 44100; % Sample rate 
    drc = compressor(-10,5,...
                     'SampleRate',Fs,...
                     'AttackTime',50e-3,...
                     'ReleaseTime',200e-3,...
                     'MakeUpGainMode','Property');
    x = [ones(Fs,1);0.1*ones(Fs,1)];
    [y,g] = drc(x);
    t = (1/Fs)*(0:2*Fs-1);
    figure
    subplot(211)
    plot(t,x);
    hold on; grid on;
    plot(t,y,'r')
    ylabel('Amplitude')
    legend('Input','Compressed Output')
    subplot(212)
    plot(t,g)
    grid on
    legend('Compressor gain (dB)')
    xlabel('Time (s)')
    ylabel('Gain (dB)')