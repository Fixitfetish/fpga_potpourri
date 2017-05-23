
fname_stimuli = 'stimuli.txt';
fname_result = 'result_log.txt';

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

sti = cplx_stimuli(18,'int');
sti = sti.appendReset(3);
sti = sti.appendData(data(:,1));
sti = sti.appendInvalid(1);
sti = sti.appendData(data(:,2));
sti = sti.appendInvalid(1);
sti = sti.appendData(data(:,3));
%sti = sti.appendData(data(:,1));
sti = sti.appendInvalid(30);
%c.Title = 'LETS GO';
sti.writeFile(fname_stimuli);

disp(['Stimuli file "',fname_stimuli,'" has been generated.'])
disp('Run VHDL simulation and then press any key to start result evaluation ...');
pause

% result evaluation
res = cplx_stimuli(18,'int');
res = res.readFile(fname_result);

R = reshape(res.CplxData(res.CplxVld),8,[]);

err = R - fft(data)/sqrt(8)
