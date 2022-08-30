clear;clc

[audio,fs] = audioread('VOZ SIN FX.wav');
dt = 1/fs;

t = 0:dt:(length(audio)-1)*dt; % vector de tiempo

crossFilt = crossoverFilter( ...
    'NumCrossovers',2, ...
    'CrossoverFrequencies',[150,5600], ...
    'CrossoverSlopes',48, ...
    'SampleRate',fs);

Compre = compressor(-42,125,... % tresh, ratio
                     'AttackTime',3e-3,...
                     'ReleaseTime',20e-3,...
                     'MakeUpGainMode','Property');

%visualize(crossFilt)

[band1,band2,band3] = crossFilt(audio);

band3 = Compre(band3);
%band2 = Compre(band2);

filtrado = band1 + band2 + band3;

figure(1)
sound(filtrado,fs);

plot(t,filtrado);

