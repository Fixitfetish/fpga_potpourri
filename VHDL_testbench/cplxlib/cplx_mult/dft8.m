% DFT8 example to test the entities
%  "cplx_mult_accu"
%  "cplx_mult_sum"

fname_stimuli = 'dft8_sti.txt';
fname_result = 'dft8_log.txt';

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
data = (re + i*im).';

addpath('../');

% create CPLX stimuli file
sti = cplx_interface(18,'int');
sti = sti.appendReset(3,2);
sti = sti.appendData(repmat(data(:,1),1,2));
sti = sti.appendInvalid(1);
sti = sti.appendData(repmat(data(:,2),1,2));
sti = sti.appendInvalid(1);
sti = sti.appendData(repmat(data(:,3),1,2));
sti = sti.appendInvalid(30);
sti.writeFile(fname_stimuli);


disp(['Stimuli file "',fname_stimuli,'" has been generated.'])
disp('Please run VHDL simulation.');
disp(['Press any key to start evaluation of simulation result file "',fname_result,'".']);
pause


% Evaluate CPLX result file
res = cplx_interface(18,'int');
res = res.readFile(fname_result);

% extract valid result values
R = reshape(res.cplx.data(logical(res.cplx.vld)),8,[]);

% DFT version 1
R1 = R(:,1:3);
err1 = fix(R1-fft(data)/sqrt(8))

% DFT version 2
R2 = R(:,4:6);
err2 = fix(R2-fft(data)/sqrt(8))
