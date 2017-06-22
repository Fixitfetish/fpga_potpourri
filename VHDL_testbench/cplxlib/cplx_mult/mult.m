% mult example to test the entity "cplx_mult"
% element-wise complex vector multiplication

addpath('../'); % class cplx_interface

fname_x_stimuli = 'x_sti.txt';
fname_y_stimuli = 'y_sti.txt';
fname_result = 'result_log.txt';

% number of valid cycles (number of rows)
cycles = 219;

% length of complex vector X, i.e. number of columns
LX = 5;

% length of complex vector Y, i.e. number of columns
% (must be 1 or same length as X)
LY = 5;

% stimuli
rand('seed',1); % use always same seed 
x_data = (1+1i) - 2*(rand(cycles,LX) + 1i*rand(cycles,LX));
y_data = (1+1i) - 2*(rand(cycles,LY) + 1i*rand(cycles,LY));

% create CPLX stimuli file for input X
x_sti = cplx_interface(18,'frac');
x_sti = x_sti.append_reset(3,LX);
x_sti = x_sti.append_data(x_data);
x_sti = x_sti.append_invalid(10);
x_sti.write_file(fname_x_stimuli);

% create CPLX stimuli file for input Y
y_sti = cplx_interface(18,'frac');
y_sti = y_sti.append_reset(3,LY);
y_sti = y_sti.append_data(y_data);
y_sti = y_sti.append_invalid(10);
y_sti.write_file(fname_y_stimuli);

disp('');
disp(['Stimuli files "',fname_x_stimuli,'" and "',fname_y_stimuli,'" have been generated.']);
disp('Please run VHDL simulation.');
disp(['Press any key to start evaluation of simulation result file "',fname_result,'".']);
pause


% Evaluate CPLX result file
% (NOTE: result vector includes one additional reference column for delay detection)
res = cplx_interface(18,'int');
res = res.read_file(fname_result);
n_ovf = sum(sum(res.cplx.ovf(:,1:LX)));
disp(['Number of overflows detected: ',num2str(n_ovf)]);

% detect incorrect values
n_nan = isnan(res.cplx.rst(:,1:LX)) ...
      + isnan(res.cplx.vld(:,1:LX)) ...
      + isnan(res.cplx.ovf(:,1:LX)) ...
      + isnan(real(res.cplx.data(:,1:LX))) ...
      + isnan(imag(res.cplx.data(:,1:LX)));
n_nan = sum(sum(n_nan));
disp(['Number of incorrect values detected: ',num2str(n_nan)]);

% determine delay
delay = find(res.cplx.vld(:,1),1) - find(res.cplx.vld(:,LX+1),1);
disp(['Multiplier delay [cycles]: ',num2str(delay)]);

% extract valid result values (only result vector without delay reference)
R = res.cplx.data(:,1:LX);
R = R(res.cplx.vld(:,1:LX)==1); % ignore 0 and NAN
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

if (n_nan>0),
  disp('ERROR: Incorrect values in result file detected.');
elseif (max_err_re<1.5) && (max_err_im<1.5),
  % threshold 1.5 works independent of rounding enable/disable
  disp('OK: Difference is as expected, i.e. below 1.5 .');
else  
  disp('ERROR: Difference too big - check settings.');
end
disp('');
