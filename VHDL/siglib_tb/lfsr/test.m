A = lfsr([16,14,13,11],false);
A.bitsPerCycle = 8;
A.offset = 199;


% 3GPP
x1 = lfsr([31,28],true);
x1.bitsPerCycle = 16;
x1.offset = 1600;
%x1.seed = [1 0 1 1 1 1 0 0 1 0 0 1 0 0 0 0 1 0 1 1 0 0 0 0 1 0 0 0 0 0 0];

x2 = lfsr([31,30,29,28],true);
x2.bitsPerCycle = 16;
x2.offset = 1600;

seq = xor(x1.seq,x2.seq);
out = xor(x1.out,x2.out)
outDec = bitxor(x1.outDec,x2.outDec)
outHex = dec2hex(outDec)
