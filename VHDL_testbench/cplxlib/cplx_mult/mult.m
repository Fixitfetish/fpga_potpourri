% mult example to test the entity "cplx_mult"
% element-wise complex vector multiplication

fname_x_stimuli = 'mult_x_sti.txt';
fname_y_stimuli = 'mult_y_sti.txt';
fname_result = 'mult_log.txt';

% number of valid cycles (number of rows)
cycles = 219;

% length of complex vector X, i.e. number of columns
LX = 5;

% length of complex vector Y, i.e. number of columns
% (must be 1 or same length as X)
LY = 5;

% stimuli
rand("seed",1); % use always same seed 
x_data = (1+1i) - 2*(rand(cycles,LX) + 1i*rand(cycles,LX));
y_data = (1+1i) - 2*(rand(cycles,LY) + 1i*rand(cycles,LY));

addpath('../');

% create CPLX stimuli file
x_sti = cplx_interface(18,'frac');
x_sti = x_sti.appendReset(3,LX);
x_sti = x_sti.appendData(x_data);
x_sti = x_sti.appendInvalid(10);
x_sti.writeFile(fname_x_stimuli);

y_sti = cplx_interface(18,'frac');
y_sti = y_sti.appendReset(3,LY);
y_sti = y_sti.appendData(y_data);
y_sti = y_sti.appendInvalid(10);
y_sti.writeFile(fname_y_stimuli);

disp('');
disp(['Stimuli files "',fname_x_stimuli,'" and "',fname_y_stimuli,'" have been generated.']);
disp('Please run VHDL simulation.');
disp(['Press any key to start evaluation of simulation result file "',fname_result,'".']);
pause


% Evaluate CPLX result file
% (NOTE: result vector includes one additional reference column for delay detection)
res = cplx_interface(18,'int');
res = res.readFile(fname_result);
n_ovf = sum(sum(res.cplx.ovf(:,1:LX)));
disp(['Number of overflows detected: ',num2str(n_ovf)]);

% determine delay
delay = find(res.cplx.vld(:,1),1) - find(res.cplx.vld(:,LX+1),1);
disp(['Multiplier delay [cycles]: ',num2str(delay)]);

% extract valid result values (only result vector without delay reference)
R = res.cplx.data(:,1:LX);
R = R(logical(res.cplx.vld(:,1:LX)));
R = reshape(R,cycles,[]);

% reference
if LY==1,
  ref = x_data .* repmat(y_data,1,LX);
else
  ref = x_data .* y_data;
end
% convert to integer and consider one additional MSB guard bit
ref = (2^17) * ref / 2; 

% determine error 
err = R - ref;
max_err_re = max(max(abs(real(err))));
max_err_im = max(max(abs(imag(err))));
disp(['Maximum absolute error [integer diff]:  Re=',num2str(max_err_re),'  Im=',num2str(max_err_im)]);

if (max_err_re<1.5) && (max_err_im<1.5),
  % threshold 1.5 works independent of rounding enable/disable
  disp('OK: Difference is as expected, i.e. below 1.5 .');
else  
  disp('ERROR: Difference too big - check settings.');
end
disp('');
