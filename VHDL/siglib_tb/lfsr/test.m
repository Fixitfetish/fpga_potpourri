A = lfsr([16,14,13,11],false);
A.shiftsPerCycle = 8;
A.offset = 199;


% 3GPP
shiftsPerCycle3GPP = 16;
outputWidth3GPP = 32;
offset3GPP = 1600;

x1 = lfsr([31,28],true);
x1.shiftsPerCycle = shiftsPerCycle3GPP;
x1.outputWidth = outputWidth3GPP;
x1.offset = offset3GPP;
% x1.seed = [1 0 1 1 1 1 0 0 1 0 0 1 0 0 0 0 1 0 1 1 0 0 0 0 1 0 0 0 0 0 0];

x2 = lfsr([31,30,29,28],true);
x2.shiftsPerCycle = shiftsPerCycle3GPP;
x2.outputWidth = outputWidth3GPP;
x2.offset = offset3GPP;

seq = xor(x1.seq,x2.seq);
out = xor(x1.out,x2.out);
outDec = bitxor(x1.outDec,x2.outDec);
outHex = dec2hex(outDec)
