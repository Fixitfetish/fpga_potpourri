% Author     Fixitfetish
% Date       07/Jul/2019
% Version    0.10
% Note       Matlab / GNU Octave
% Copyright  <https://en.wikipedia.org/wiki/MIT_License>
%            <https://opensource.org/licenses/MIT>
classdef normalDist
% description of this class

 properties
   sigma = 0.5 ;  % standard deviation
   mu = 0         % mean
   xTick = 0.125  % X-Axis tick, bin width (must be equidistant)
   xLim = [-1 1]  % X-Axis limits
 end

 properties (Dependent)
   variance
   variance_dBfs % variance dB full scale, i.e. releative to 1
   nBin % resulting number of bins
   x
   xPMF % PMF X-Axis, center of each bin 
 end

 methods
 
   function obj = normalDist(sigma,mu)
   % class constructor
     if (nargin>=1), obj.sigma = sigma; end
     if (nargin>=2), obj.mu = mu; end
   end

   function v = get.variance(obj)
     v = obj.sigma^2;
   end

   function v = get.variance_dBfs(obj)
     v = 10 * log10(obj.sigma^2);
   end

   function n = get.nBin(obj)
     n = numel(obj.xPMF);
   end

   function xx = get.x(obj)
     xx = obj.xLim(1)+obj.xTick : obj.xTick : obj.xLim(2)-obj.xTick;
   end

   function xx = get.xPMF(obj)
     xx = (obj.xLim(1)+obj.xTick : obj.xTick : obj.xLim(2)) - obj.xTick/2;
   end

   % probability density function
   function [g,gx] = pdf(obj,gx)
     if ~exist('gx','var'), gx=obj.x; end
     g = 1/sqrt(2*pi)/obj.sigma * exp(- ((gx-obj.mu).^2) / (2*obj.sigma^2)) ;
   end

   % cumulative distribution function
   function [c,cx] = cdf(obj,cx)
     if ~exist('cx','var'), cx=obj.x; end
     c = (1 + erf((cx-obj.mu)/sqrt(2*obj.sigma^2)) ) / 2 ;
   end

   % probability mass function
   % * probability in bins between two CDF samples points
   % * The most left and right limits of the PMF are -inf and inf. 
   % * Sum of result is always 1.
   function [p,px] = pmf(obj,xx)
     if ~exist('xx','var'), xx=obj.x; end
     c = obj.cdf(xx);
     if c(1)==0 && c(end)==1
       p = c(2:end) - c(1:end-1);
     elseif c(1)~=0 && c(end)==1
       p = c - [0 , c(1:end-1)];
     elseif c(1)==0 && c(end)~=1
       p = [c(2:end) , 1] - c;
     else
       p = [c(1:end) , 1] - [0 , c(1:end)];
       xxDiff = xx(2:end) - xx(1:end-1);
       xxDiff = [xxDiff(1) , xxDiff];
       px = [ xx-xxDiff/2 , xx(end)+xxDiff(end)/2 ];
     end
   end 

   function g = plot(obj,type,xx,color)
     if ~exist('xx','var') || isempty(xx),
       xx=obj.x;
       lim = obj.xLim;
     end
     if ~exist('color','var'), color='k'; end
     if strcmp(type,'pdf')
       plot(xx,obj.pdf(xx),color);
       hold on;
       ymax = max(obj.pdf(xx));
       line([-obj.sigma,-obj.sigma],[0 ymax],'Color','red');
       line([ obj.sigma, obj.sigma],[0 ymax],'Color','red');
       title(['Gauss PDF (sigma = ',num2str(obj.sigma),')']);
     elseif strcmp(type,'cdf')
       plot(xx,obj.cdf(xx),color);
       hold on;
       line([-obj.sigma,-obj.sigma],[0 1],'Color','red');
       line([ obj.sigma, obj.sigma],[0 1],'Color','red');
       title(['Gauss CDF (sigma = ',num2str(obj.sigma),')']);
     elseif strcmp(type,'pmf')
       [d,dx] = obj.pdf(lim(1):0.01:lim(end));
       [m,mx] = obj.pmf(xx);
       plot(dx,d*obj.xTick,color);
       hold on; grid on;
       ymax = max(d*obj.xTick);
       line([-obj.sigma,-obj.sigma],[0 ymax],'Color','red');
       line([ obj.sigma, obj.sigma],[0 ymax],'Color','red');
       stem(mx,m,color);
       hold off;
       title(['Approximate Gauss PMF (sigma = ',num2str(obj.sigma),')']);
     end
   end

   function g = stem(obj,type,xx,color)
     if ~exist('xx','var'), xx=obj.x; end
     if ~exist('color','var'), color='k'; end
     if strcmp(type,'pdf')
       stem(xx,obj.pdf(xx),color);
     elseif strcmp(type,'cdf')
       stem(xx,obj.cdf(xx),color);
     elseif strcmp(type,'pmf')
       [p,px] = obj.pmf(xx);
       stem(px,p,color);
     end
   end

   function g = bar(obj,type,xx,color)
     if ~exist('xx','var'), xx=obj.x; end
     if ~exist('color','var'), color='y'; end
     if strcmp(type,'pdf')
       bar(xx,obj.pdf(xx),'facecolor',color);
     elseif strcmp(type,'cdf')
       bar(xx,obj.cdf(xx),'facecolor',color);
     elseif strcmp(type,'pmf')
       [p,px] = obj.pmf(xx);
       bar(px,p,'facecolor',color);
     end
   end

 end %methods

end %classdef
