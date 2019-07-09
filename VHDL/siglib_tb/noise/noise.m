% Author     Fixitfetish
% Date       07/Jul/2019
% Version    0.10
% Note       Matlab / GNU Octave
% Copyright  <https://en.wikipedia.org/wiki/MIT_License>
%            <https://opensource.org/licenses/MIT>

classdef noise
% description of this class
%
% Parmeters tested in simulation
% variance  bits  bits  depth   corr   Result
%           Gauss Adder
%  -14.00     4     2    1024  1.004
%  -15.00     4     2    1024  0.996
%  -15.05     4     2    1024  0.995
%  -16.00     4     2    1024  0.988
%  -17.00     4     2    1024  0.983

 properties
   % Output resolution in number of bits
   resolution = 12

   % Variance in dB full scale (dBfs)
   variance_dBfs = -15.0

   % Gauss resolution and look-up output (must be <resolution)
   % Number of initial signed MSB bits with Gauss/Normal distribution
   bitsGauss = 4

   % Number of additional adder stages.
   % * 0 : only 1 noise sample without accumulation
   % * 1 : 2 noise samples are accumulated
   % * 2 : 4 noise samples are accumulated
   % Note that per adder stage
   % * the PAPR will increase by +3.01dB
   % * the variance will decrease by -3.01dB relative to 0dBfs
   bitsAdder = 2

   % Number of LFSR bits required Gauss look-up
   bitsLUT = 10;

   % Sigma correction factor for approximation
   corr = 1.000;

   % simulation length in number of noise samples
   simLength = 1e8;

   % Simulation step size in number of noise samples influences the RAM usage.
   % (smaller step size => less RAM but more iterations are required)
   simStep = 1e7;

 end

 properties (Dependent)
   variance_lin % variance linear 
   sigma % standard deviation
   bitsUniform % resulting number of initial bits with uniform distribution
   gauss % object of class 'normalDist'
   gaussBinLimit % CDF weighted with 2^bitsLUT, sampled and rounded
   gaussBinSize % PMF weighted with 2^bitsLUT and rounded
   gaussLUT
 end

 methods
 
   function obj = noise(res,var,bitsG,bitsA)
   % class constructor
     if (nargin>=1), obj.resolution = res; end
     if (nargin>=2), obj.variance_dBfs = var; end
     if (nargin>=3), obj.bitsGauss = bitsG; end
     if (nargin>=4), obj.bitsAdder = bitsA; end
   end

   function v = get.variance_lin(obj)
     v = 10^(obj.variance_dBfs/10);
   end

   function s = get.sigma(obj)
     s = sqrt(obj.variance_lin);
   end

   function n = get.bitsUniform(obj)
     n = obj.resolution - obj.bitsGauss - obj.bitsAdder;
   end

   function g = get.gauss(obj)
     s = obj.corr * obj.sigma * sqrt(2^obj.bitsAdder);
     g = normalDist(s);
     g.xTick = 2 / (2^obj.bitsGauss);
     g.xLim = [-1 , +1];
   end

   function l = get.gaussBinLimit(obj)
     l = [round(obj.gauss.cdf * 2^obj.bitsLUT) , 2^obj.bitsLUT];
   end

   function s = get.gaussBinSize(obj)
     s = obj.gaussBinLimit - [0 , obj.gaussBinLimit(1:end-1)];
   end

   function L = get.gaussLUT(obj)
     L = zeros(1,2^obj.bitsLUT);
     c = obj.gaussBinLimit;
     low=1;
     for b=1:length(c),
       L(low:c(b)) = b-1-2^(obj.bitsGauss-1);
       low = c(b) + 1;
     end
   end

   function gaussPlot(obj)
     subplot(3,1,1);
       x = -1:0.01:1;
       obj.gauss.plot('cdf',x);
       grid on; hold on;
       obj.gauss.stem('cdf');
       hold off;
     subplot(3,1,2);
       obj.gauss.plot('pmf');
     subplot(3,1,3);
       bar(obj.gauss.xPMF,obj.gaussBinSize);
       title('Gauss PMF / Resulting bin sizes');
       grid on; hold off;
   end
 
   function [S0,R] = genStage0(obj,S0,n)
     % before first adder stage
     if ~exist('S0','var') || isempty(S0)
       % Initialization (clear histogram)
       S0.ref = normalDist( 2^(obj.resolution-obj.bitsAdder-1) ...
                              * sqrt(obj.variance_lin * 2^obj.bitsAdder));
       S0.ref.xLim = 2^(obj.resolution-obj.bitsAdder-1) * [-1 1];
       S0.ref.xTick = 1;
       S0.binWidth = 2^(obj.bitsUniform-3); % 8 bins per Gauss step
       S0.ghx = -2^(obj.bitsGauss-1) : 2^(obj.bitsGauss-1)-1;
       S0.ghy = zeros(1,length(S0.ghx)); % emtpy histogram
       S0.hx = S0.ref.xLim(1):S0.binWidth:S0.ref.xLim(end); % x-axis histogram
       S0.hy = zeros(1,length(S0.hx)); % emtpy histogram
     else
       % Generation
       % (overwrite variable R to reduce RAM usage and requirements)
       ROM = obj.gaussLUT;
       R = randi([1 2^obj.bitsLUT],1,n); % uniform random bits from LFSR
       R = ROM(R); % Gauss look-up
       S0.ghy = S0.ghy + hist(R,S0.ghx);
       R = R * 2^obj.bitsUniform + randi([0 2^obj.bitsUniform-1],1,n); % add LSB
       S0.hy = S0.hy + hist(R,S0.hx);
     end
   end
 
   function [S0,S] = sim(obj)
     [S0] = obj.genStage0(); % initialization

     % after adder stages
     S.ref = normalDist(obj.sigma * 2^(obj.resolution-1));
     S.ref.xLim = 2^(obj.resolution-1) * [-1 1];
     S.ref.xTick = 1;
     S.binWidth = round(S.ref.sigma/64); % split sigma range into 64 bins
     S.hx = S.ref.xLim(1):S.binWidth:S.ref.xLim(end); % x-axis histogram
     S.hy = zeros(1,length(S.hx)); % empty histogram
     S.simVal = 0;
     S.simMean = 0;
     S.simVar = 0;
     S.simPeak = 0;

     nRemain = obj.simLength;
     % loop to reduce RAM usage and requirements
     while (nRemain>0)
       nLoop = min(nRemain,obj.simStep);
       nRemain = nRemain - obj.simStep;

       [S0,R] = obj.genStage0(S0,nLoop * 2^obj.bitsAdder);

       % accumulation  
       if obj.bitsAdder>0
         R = sum(reshape(R,2^obj.bitsAdder,[]));
       end
       
       % one bit per accumulation step plus one Dither bit
       carryBits = 2^obj.bitsAdder-1+1;
       R = R + randi([0 carryBits],1,nLoop);

       S.hy = S.hy + hist(R,S.hx);
       S.simMean = (S.simVal*S.simMean + nLoop*mean(R) ) / (S.simVal+nLoop);
       S.simVar = (S.simVal*S.simVar + nLoop*var(R) ) / (S.simVal+nLoop);
       S.simVal = S.simVal+nLoop;
       S.simStd = sqrt(S.simVar);
       S.simPeak = max( S.simPeak , max(abs(R)) );
     end
     S.simPapr = 10*log10(S.simPeak^2 / S.simVar);
   end
 
 end %methods

end %classdef
