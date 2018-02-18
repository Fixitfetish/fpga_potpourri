% DFT8 example to test the entities
%  "cplx_mult_accu"
%  "cplx_mult_sum"

addpath('../');

fname_stimuli = 'dft8_sti.txt';
fname_result = 'result_log.txt';

% length of complex vector X, i.e. number of columns
LX = 2;

% first input
re      = [  67272, -53923,  57111,  23748, -44332, -71022,  66992, -81005 ]; 
im      = [  33774, -71192, -21872, -76892, -63453,  68615, -59628, -61097 ];
% second input (1 expected overflow)
re(2,:) = [  54047, -54236,  64216, -59296,  63667, -39001,  60444, -52812 ];
im(2,:) = [ -49662,  46228, -54892,  59853, -52268,  48211, -39079,  51888 ];
% third input (2 expected overflows)
re(3,:) = [ -52268,  -4860, -39079, 104958, -49662,  -6843, -54892, 112924 ];
im(3,:) = [  87830, -34948,  -8143, -40008,  97450, -19713, -11914, -33524 ];
% merge stimuli
data = (re + 1i*im).';

% create CPLX stimuli file
sti = cplx_interface(18,'int');
sti = sti.append_reset(3,LX);
sti = sti.append_data(repmat(data(:,1),1,LX));
sti = sti.append_invalid(1);
sti = sti.append_data(repmat(data(:,2),1,LX));
sti = sti.append_invalid(1);
sti = sti.append_data(repmat(data(:,3),1,LX));
sti = sti.append_invalid(30);
sti.write_file(fname_stimuli);


disp(['Stimuli file "',fname_stimuli,'" has been generated.'])
disp('Please run VHDL simulation.');
disp(['Press any key to start evaluation of simulation result file "',fname_result,'".']);
pause


% Evaluate CPLX result file
res = cplx_interface(18,'int');
res = res.read_file(fname_result);
n_ovf = sum(sum(res.cplx.ovf(~isnan(res.cplx.ovf))));
disp(['Number of overflows detected: ',num2str(n_ovf),' (Note that 6 overflows are expected!)']);
disp('');

% detect incorrect values
n_nan = isnan(res.cplx.rst(:,1:LX)) ...
      + isnan(res.cplx.vld(:,1:LX)) ...
      + isnan(res.cplx.ovf(:,1:LX)) ...
      + isnan(real(res.cplx.data(:,1:LX))) ...
      + isnan(imag(res.cplx.data(:,1:LX)));
n_nan = sum(sum(n_nan));
disp(['Number of NaN values detected in log: ',num2str(n_nan)]);

% extract valid result values
R = reshape(res.cplx.data(res.cplx.vld==1),8,[]);

% DFT version 1
R1 = R(:,1:3);
err1 = fix(R1-fft(data)/sqrt(8))

% DFT version 2
R2 = R(:,4:6);
err2 = fix(R2-fft(data)/sqrt(8))
