% import result file of VHDL simulation
a = importdata('result_log.txt');
vld = (a.data(:,2)==1);
re = a.data(vld,4);
im = a.data(vld,5);
sincos = re + 1i*im;

% Reference
A_ld = log2(max(re));
A = 2^ceil(A_ld);
N = length(sincos);
x = (0:N-1)' * 2*pi/N;
ref = A * exp(1i*x);

% Error
err = sincos - ref;
err_mag = 20*log10(abs(err)/A);
err_phase = abs(angle(sincos)-angle(ref))/pi*180;

figure(1);
subplot(1,2,1);
hRef=plot(ref,'b');
grid; hold;
hSim=plot(sincos,'r');
title('Generator versus Reference');
legend([hRef,hSim],'Reference','Simulation');
hold off;
subplot(1,2,2);
hReal=plot(0:N-1,real(err),'b');
hold
hImag=plot(0:N-1,imag(err),'r');
grid;
title('Real and Imaginary Amplitude Error');
legend([hReal,hImag],'Real','Imaginary');
hold off;

figure(2);
subplot(1,2,1);
plot(0:N-1,err_mag,'b');
ymax = floor(max(err_mag))+5;
axis([0 N-1 ymax-40 ymax]);
ylabel('Magnitude Error [dB]')
grid;
subplot(1,2,2);
plot(0:N-1,err_phase,'b');
ymax = 1.2 * max(err_phase);
axis([0 N-1 0 ymax]);
ylabel('Phase Error [Degree]')
grid;
