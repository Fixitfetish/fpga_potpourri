% parameters
taps = [3,5];
shiftsPerCycle = 4;
cycles = 20;
offset = 0;
outputWidth = 8;

% Galois
G1 = lfsr(taps,false);
G1.shiftsPerCycle = shiftsPerCycle;
G1.cycles = cycles;
G1.offset = offset;
G1.outputWidth = outputWidth;

% Fibonacci
F1 = lfsr(taps,true);
F1.shiftsPerCycle = shiftsPerCycle;
F1.cycles = cycles;
F1.offset = offset;
F1.outputWidth = outputWidth;

% Fibonacci (with seed offset compensation, i.e. input transform matrix)
F2 = lfsr(taps,true);
F2.shiftsPerCycle = shiftsPerCycle;
F2.cycles = cycles;
F2.offset = offset;
F2.outputWidth = outputWidth;
F2.transformSeed = true;
%F2.seed = [0 1 0 0 1];

disp('Galois (left) and Fibonacci (right) - direct comparision with same settings');
disp([G1.outAll , F1.outAll ]);

disp(' ');
disp('Galois (left) and Fibonacci (right) - Fibonacci with input transform matrix');
disp([G1.outAll , F2.outAll ]);

