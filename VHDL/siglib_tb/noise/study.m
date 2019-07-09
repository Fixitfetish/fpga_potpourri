% Study : central limit theorem
bits = 8;
adderStages = 5;
samples = 1e7; % number of uniform samples
mu= 0; % TODO

% Starting point : Probability Mass Function (PMF) of uniform distribution
P{1} = ones(1,2^bits) / (2^bits);

% Random samples with uniform distribution
R = struct();
R.val = randi([-2^(bits-1) 2^(bits-1)-1],1,samples);
R.mean = mean(R.val); 
R.var = var(R.val);
R.std = std(R.val);
R.varRef = ((2^bits)^2 - 1) / 12;
R.stdRef = sqrt(R.varRef);

for n=1:adderStages,
  P{n+1} = conv(P{n},P{n});
  % every adder stage requires an additional bit
  R(n+1).val = sum(reshape(R(n).val,2,[])); % adder stage
  R(n+1).val = R(n+1).val + randi([0 1],1,numel(R(n+1).val)); % mean correction
  R(n+1).mean = mean(R(n+1).val); 
  R(n+1).var = var(R(n+1).val);
  R(n+1).std = std(R(n+1).val);
  R(n+1).varRef = R(n).varRef * 2; % every adder stage doubles the variance
  R(n+1).stdRef = sqrt(R(n+1).varRef);
end

% overview plot
for n=1:adderStages+1,
  figure(n);
  xmin = -floor(length(P{n})/2);
  xmax = floor(length(P{n})/2-0.1);
  binWidth = round(R(n).stdRef / 8); % split sigma range into 8 bins
  [H,HX] = hist(R(n).val,xmin:binWidth:xmax);
  bar(HX,H/sum(H)/binWidth,'facecolor','y');
  grid on;
  hold on;
  % Expected PMF
  x = xmin:xmax;
  plot(x,P{n}/sum(P{n}),'b');
  % Gauss reference
  g = ( 1/sqrt(2*pi)/R(n).std * exp(- ((x-mu).^2) / (2*R(n).std^2)) );
  plot(x,g,'r');
  line([-R(n).stdRef,-R(n).stdRef],[0 max(g)],'Color','red');
  line([ R(n).stdRef, R(n).stdRef],[0 max(g)],'Color','red');

  title(['After adder stage ',num2str(n-1),' : reference standard deviation = ',num2str(R(n).stdRef)]);
  xlim([-3*R(n).stdRef 3*R(n).stdRef]);
  xlabel(['simulated : mean=',num2str(R(n).mean),', standard deviation=',num2str(R(n).std)]);
  legend('simulated','expected','reference');  
  hold off;
end
