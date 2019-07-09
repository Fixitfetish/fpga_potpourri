% Author     Fixitfetish
% Date       07/Jul/2019
% Version    0.10
% Note       Matlab / GNU Octave
% Copyright  <https://en.wikipedia.org/wiki/MIT_License>
%            <https://opensource.org/licenses/MIT>

% final variance in dB full scale
variance_dBfs = -15.0;

% overall resolution, number of bits
bits = 12;

% Gauss resolution and look-up (must be <bits)
bitsGauss = 4;

% number of additional adder stages
% Note: per adder stage +3.01dB PAPR
bitsAdder = 2;

% Sigma correction factor
corr = 0.996;

nRND = 1e8;


%----------------------------------------------------------------

N = noise(bits,variance_dBfs,bitsGauss,bitsAdder);
N.corr = corr;
N.simLength = nRND;

% plot CDF, PMF and bins
figure(1);
 N.gaussPlot();

binCDF = N.gaussBinLimit
binPMF = N.gaussBinSize

% Simulation
[S0,S] = N.sim();

% Histogram after Guass LUT
figure(2);
  bar(S0.ghx,S0.ghy);
  hold off;

% Histogram before adder stages
figure(3);
  bar(S0.hx,S0.hy/sum(S0.hy)/S0.binWidth,'facecolor','y');
  grid on; hold on;
  S0.ref.plot('pdf',[],'r');
  title(['Before adder stages (reference sigma = ',num2str(S0.ref.sigma),')']);
  xlim(S0.ref.sigma * [-4 4]);
  legend('simulated','reference');  
  hold off;

% Histogram after adder stages
figure(4);
  bar(S.hx,S.hy/sum(S.hy)/S.binWidth,'facecolor','y');
  grid on; hold on;
  S.ref.plot('pdf',[],'r');
  title(['After adder stages (reference sigma = ',num2str(S.ref.sigma),')']);
  xlim(S.ref.sigma * [-4 4]);
  legend('simulated','reference');  
  hold off;


disp(['Ref. Sigma [Integer] = ',num2str(S.ref.sigma)]);
disp(['Sim. Sigma [Integer] = ',num2str(S.simStd)]);
disp(['Sim. Mean [Integer] = ',num2str(S.simMean)]);
disp(['Sim. Peak Abs. [Integer] = ',num2str(S.simPeak)]);
disp(['Sim. PAPR [dBfs] = ',num2str(S.simPapr)]);
