% parameters
taps = [5,3];
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

% Galois (with seed offset compensation, i.e. input transform matrix)
G2 = lfsr(taps,false);
G2.shiftsPerCycle = shiftsPerCycle;
G2.cycles = cycles;
G2.offset = offset;
G2.outputWidth = outputWidth;
G2.transformSeed = true;

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
disp('Galois (left) and Fibonacci (right) - Fibonacci with seed transform matrix');
disp([G1.outAll , F2.outAll ]);

disp(' ');
disp('Galois (left) and Fibonacci (right) - Galois with seed transform matrix');
disp([G2.outAll , F1.outAll ]);
