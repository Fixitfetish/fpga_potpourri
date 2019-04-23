classdef lfsr
% Linear Feedback Shift Register based on XOR primitive function with
% shift right register (row vector) and matrix multiplication.

  properties
    exponents; % Feedback polynomial exponents (taps). List of positive integers in descending order.
    fibonacci = false; % false=Galois, true=Fibonacci
    bitsPerCycle = 1; % number of shifts/bits per cycle
    cycles = 20;
    offset = 0; % fast-forward bit shifts
    seed = []; % Initial shift register contents, default is [0,..,0,1]
  end

  properties (Dependent)
    M; % number of shift register bits 
    polynom; % logical row vector
    seedFF; % seed fast-forward, including offset
    seedTransformed; % transformed seed, Galois<=>Fibonacci
    sr; % shift (right) register, logical row vector
    srDec; % shift register decimal
    srBin; % shift register binary (char)
    srHex; % shift register hexadecimal (char)
    out; % output per cycle as logical matrix, rows=cycles, cols=bitsPerCycle, rightmost bit first
    outDec; % output per cycle, decimal
    outBin; % output per cycle, binary (char)
    outHex; % output per cycle, hexadecimal (char)
    seq; % complete bit sequence as logical vector
    cMat; % companion matrix (logical)
    oMat; % offset matrix (logical)
    sMat; % shift matrix (logical)
    tMat; % transform matrix Galois<=>Fibonacci (logical)
  end
 
 methods

  function obj = lfsr(exp,fibo)
  % class constructor
    if (nargin>=1), obj.exponents = exp; end
    if (nargin>=2), obj.fibonacci = fibo; end
  end

  function obj = set.exponents(obj,exp)
    obj.exponents = sort(unique(round(exp)),'descend');
  end

  function obj = set.seed(obj,s)
    obj.seed = logical(s(1:numel(s))); % convert to logical row vector
  end
  
  function s = get.seed(obj)
    s = obj.seed;
    if isempty(s)
      s = false(1,obj.M);
      s(obj.M) = true;
    end
  end
  
  function s = get.seedFF(obj)
    s = logical(mod(obj.seed*obj.oMat,2));
  end
  
  function s = get.seedTransformed(obj)
    s = logical(mod(obj.seed*obj.tMat,2));
  end
  
  function s = get.sr(obj)
   s = false(obj.cycles+1,obj.M);
   s(1,:) = logical(mod(obj.seed*obj.oMat,2));
   if obj.cycles>=1
    for c=1:obj.cycles
      s(c+1,:) = logical(mod(s(c,:)*obj.sMat,2));
    end
   end
  end

  function s = get.srDec(obj)
   s = obj.sr * (2.^(obj.M-1:-1:0))';
  end
  
  function s = get.srHex(obj)
    s = dec2hex(obj.srDec,ceil(obj.M/4));
  end
  
  function s = get.srBin(obj)
    s = dec2bin(obj.srDec,obj.M);
  end
  
  function s = get.out(obj)
   s = [];
   if obj.cycles>0
     s = obj.sr(1:obj.cycles , end-obj.bitsPerCycle+1:end);
   end
  end

  function s = get.outDec(obj)
    s = obj.out * (2.^(obj.bitsPerCycle-1:-1:0))';
  end

  function s = get.outHex(obj)
    s = dec2hex(obj.outDec,ceil(obj.bitsPerCycle/4));
  end
    
  function s = get.outBin(obj)
    s = dec2bin(obj.outDec,obj.M);
  end

  function s = get.seq(obj)
    s = reshape(fliplr(obj.out)',1,[]);
  end
  
  function m = get.M(obj)
    m = obj.exponents(1);
  end
  
  function p = get.polynom(obj)
    L = obj.exponents(1);
    p = false(1,L);
    for t=obj.exponents
      p(L-t+1) = true;
    end
  end
  
  function m = get.cMat(obj)
  % Companion Matrix
    if obj.fibonacci
      m = obj.companionMatrixFibonacci();
    else
      m = obj.companionMatrixGalois();
    end
  end

  function m = get.oMat(obj)
  % Offset Matrix
    m = obj.cMatPow(obj.offset);
  end

  function m = get.sMat(obj)
  % Shift Matrix
    m = obj.cMatPow(obj.bitsPerCycle);
  end

  function m = get.tMat(obj)
  % Transform Matrix (Galois <=> Fibonacci)
  % Transforms shift register values between galois and fibonacci representation
  % to compensate the sequence offset.
  % The R seed bits right of the smallest tap are the same for galois and fibonacci,
  % i.e. only the L bits left of the smallest tap must be transformed.
    R = obj.exponents(end); % smallest tap
    L = obj.M - R;
    cm = obj.companionMatrixGalois();
    tm = logical(eye(obj.M));
    for n=1:L, tm=logical(mod(tm*cm,2)); end % shift
    m = [ tm(:,L+1:2*L) , [false(L,R);logical(eye(R))] ]; 
  end

 end % methods

 methods (Access=private)
   
  function m = companionMatrixGalois(obj)
    m = logical( [[ zeros(obj.M-1,1),eye(obj.M-1)];obj.polynom] );
  end
   
  function m = companionMatrixFibonacci(obj)
    m = logical( [flipud(obj.polynom'),[eye(obj.M-1);zeros(1,obj.M-1)]] );
  end

  % cMat raised to the power of n
  function m = cMatPow(obj,n)
    m = logical( eye(obj.M) );
    f = obj.cMat;
    nBin = fliplr(dec2bin(n));  
    for b=1:length(nBin) 
      if nBin(b)=='1', m=logical(mod(m*f,2)); end
      f = logical(mod(f*f,2));
    end
  end

 end % methods private
 
end %classdef
