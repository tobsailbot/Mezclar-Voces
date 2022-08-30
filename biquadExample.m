
% Impulse Response of Bi-quad
x = [1;zeros(4095,1)];

eq_ref = audioread('eq_impulse.wav');
eq_ref = eq_ref(1:48000);

% Filter Parameters
Fs = 48000;
f = 8800;    % Frequency in Hz
Q = 0.45;
dBGain = 3.2;

% FILTER TYPE >>> lpf,hpf,pkf,apf,nch,hsf,lsf,bp1,bp2
type = 'hsf';
form = 3; 

y = biquadFilter(x,Fs,f,Q,dBGain,type,form);

% HTF settigns
type = 'hpf';
f = 90;
Q = 0.66;
dBGain = 3;

y = biquadFilter(y,Fs,f,Q,dBGain,type,form);

% bell settigns
type = 'pkf';
f = 410;
Q = 0.7;
dBGain = -2.4;

y = biquadFilter(y,Fs,f,Q,dBGain,type,form);


subplot(2,1,1)
[h,w] = freqz(y,1,4096,Fs);
semilogx(w,20*log10(abs(h)));axis([20 20000 -20 15]);
xlabel('Frequency (Hz)'); ylabel('Amplitude (dB)');
grid on

H = fft(eq_ref);

f = 0:1:Fs-1;

subplot(2,1,2)
figure(1)
semilogx(f, 20*log10(abs(H)));
grid on
axis([20 20000 -20 15])
title('Respuesta en frecuencia del filtro')



