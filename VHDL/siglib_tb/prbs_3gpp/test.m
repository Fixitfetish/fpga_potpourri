addpath('../lfsr');

% parameters
shiftsPerCycle = 8;
outputWidth = 8;
offset = 1600;

% X1 Fibonacci-LFSR
x1 = lfsr([31,28],true);
x1.shiftsPerCycle = shiftsPerCycle;
x1.outputWidth = outputWidth;
x1.offset = offset;

% X2 Fibonacci-LFSR
x2 = lfsr([31,30,29,28],true);
x2.shiftsPerCycle = shiftsPerCycle;
x2.outputWidth = outputWidth;
x2.offset = offset;
% x2.seed = [1 0 1 1 1 1 0 0 1 0 0 1 0 0 0 0 1 0 1 1 0 0 0 0 1 0 0 0 0 0 0];

% Merge to Gold-Sequence
seq = xor(x1.seq,x2.seq)
out = xor(x1.out,x2.out)
outDec = bitxor(x1.outDec,x2.outDec)
outHex = dec2hex(outDec)
