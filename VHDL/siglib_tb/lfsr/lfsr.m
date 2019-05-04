% Author     Fixitfetish
% Date       04/May/2019
% Version    0.50
% Note       Matlab / GNU Octave
% Copyright  <https://en.wikipedia.org/wiki/MIT_License>
%            <https://opensource.org/licenses/MIT>

classdef lfsr
% Linear Feedback Shift Register based on XOR primitive function with
% shift right register (row vector) and matrix multiplication.
% VHDL reference implementation

  properties
    taps; % Feedback polynomial exponents (taps). List of positive integers in descending order.
    fibonacci = false; % false=Galois, true=Fibonacci
    shiftsPerCycle = 1; % number of shifts/bits per cycle
    cycles = 20;
    offset = 0; % fast-forward bit shifts
    outputWidth = 0;
    transformSeed = false; % Galois<=>Fibonacci transform 
    seed = []; % Initial shift register contents, logical vector of length M, default is [0,..,0,1]
  end

  properties (Dependent)
    M; % standard shift register length 
    N; % number of shift register bits 
    X; % number of extension bits
    I; % resulting offset
    D; % resulting output width
    polynom; % logical row vector
    seedExt; % left-aligned seed with extension bits and optional Galois<=>Fibonacci transformation
    seedFF; % seed fast-forward, including offset
    sr; % shift (right) register, logical row vector
    srDec; % shift register decimal
    srBin; % shift register binary (char)
    srHex; % shift register hexadecimal (char)
    out; % output per cycle as logical matrix, rows=cycles, cols=shiftsPerCycle, rightmost bit first
    outDec; % output per cycle, decimal
    outBin; % output per cycle, binary (char)
    outHex; % output per cycle, hexadecimal (char)
    outAll; % output per cycle, binary + hexadecimal + decimal (char)
    seq; % complete bit sequence as logical vector
    cMat; % companion matrix (logical)
    oMat; % offset matrix (logical)
    sMat; % shift matrix (logical)
    tMat; % transform matrix Galois<=>Fibonacci (logical)
  end
 
 methods

  function obj = lfsr(tap,fibo)
  % class constructor
    if (nargin>=1), obj.taps = tap; end
    if (nargin>=2), obj.fibonacci = fibo; end
  end

  function obj = set.taps(obj,tap)
    obj.taps = sort(unique(round(tap)),'descend');
  end

  function obj = set.seed(obj,s)
    % seed
    obj.seed = false(1,obj.M);
    obj.seed(1:numel(s)) = logical(s(1:numel(s))); % convert to logical row vector
  end

  function s = get.seed(obj)
    s = obj.seed;
    if isempty(s)
      % seed incl. right-aligned extension bits
      s = false(1,obj.M);
      s(obj.M) = true;
    end
  end

  function s = get.seedExt(obj)
    % extended seed including ...
    % right-aligned extension bits
    s = false(1,obj.N);
    s(1:numel(obj.seed)) = obj.seed;
    % optional input transform logic
    if obj.transformSeed
      s = logical(mod(s*obj.tMat,2));
    end
  end

  function s = get.seedFF(obj)
    s = logical(mod(obj.seedExt*obj.oMat,2));
  end

  function s = get.sr(obj)
   s = false(obj.cycles+1,obj.N);
   s(1,:) = logical(mod(obj.seedExt*obj.oMat,2));
   if obj.cycles>=1
    for c=1:obj.cycles
      s(c+1,:) = logical(mod(s(c,:)*obj.sMat,2));
    end
   end
  end

  function s = get.srDec(obj)
   s = obj.sr * (2.^(obj.N-1:-1:0))';
  end
  
  function s = get.srHex(obj)
    s = dec2hex(obj.srDec,ceil(obj.N/4));
  end
  
  function s = get.srBin(obj)
    s = dec2bin(obj.srDec,obj.N);
  end
  
  function s = get.out(obj)
   s = [];
   if obj.cycles>0
     s = obj.sr(1:obj.cycles , end-obj.D+1:end);
   end
  end

  function s = get.outDec(obj)
    s = obj.out * (2.^(obj.D-1:-1:0))';
  end

  function s = get.outHex(obj)
    s = dec2hex(obj.outDec,ceil(obj.D/4));
  end
    
  function s = get.outBin(obj)
    s = dec2bin(obj.outDec,obj.D);
  end

  function s = get.outAll(obj)
    s = [obj.outBin , repmat(' ',obj.cycles,1), ...
         obj.outHex , repmat(' ',obj.cycles,1), ...
         num2str(obj.outDec) , repmat('   ',obj.cycles,1) ];
  end

  function s = get.seq(obj)
    s = reshape(fliplr(obj.out)',1,[]);
  end
  
  function m = get.M(obj)
    m = obj.taps(1);
  end
  
  function n = get.N(obj)
    n = max(obj.taps(1),obj.outputWidth);
  end

  function x = get.X(obj)
    x = max(obj.taps(1),obj.outputWidth) - obj.taps(1);
  end

  function n = get.I(obj)
    n = obj.offset + obj.X;
  end

  function d = get.D(obj)
    d = obj.outputWidth;
    if obj.outputWidth==0, d=obj.M; end
  end

  function p = get.polynom(obj)
    L = obj.taps(1);
    p = false(1,L);
    for t=obj.taps
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
    m = obj.cMatPow(obj.I);
  end

  function m = get.sMat(obj)
  % Shift Matrix
    m = obj.cMatPow(obj.shiftsPerCycle);
  end

  function m = get.tMat(obj)
  % Transform matrix (Galois <=> Fibonacci)
  % Transforms shift register values between Galois and Fibonacci representation
  % to compensate the sequence offset between both.
  % Considered are also shift registers which are extended by X bits to the right.
  % The R bits right of the smallest tap are the same for Galois and Fibonacci,
  % i.e. only the L bits left of the smallest tap must be transformed.
    R = obj.taps(end); % smallest tap
    L = obj.M - R;
    cm = obj.companionMatrixGalois();
    tm = logical(eye(obj.N));
    for n=1:L, tm=logical(mod(tm*cm,2)); end % shift L times
    m = logical(eye(obj.N));
    m(:,1:L) = tm(:,L+1:2*L); % replace first L columns  
  end

 end % methods

 methods (Access=private)
   
  function m = companionMatrixGalois(obj)
    m = false(obj.N,obj.N);
    % first N-1 rows have right-aligned identity matrix
    m(1:end-1,2:end) = logical(eye(obj.N-1));
    % Galois : polynomial left-aligned into M-th row
    m(obj.M,1:obj.M) = obj.polynom;
  end
   
  function m = companionMatrixFibonacci(obj)
    m = false(obj.N,obj.N);
    % first N-1 rows have right-aligned identity matrix
    m(1:end-1,2:end) = logical(eye(obj.N-1));
    % Fibonacci : mirrored polynomial top-aligned into first column
    m(1:obj.M,1) = flipud(obj.polynom');
  end

  % cMat raised to the power of n
  function m = cMatPow(obj,n)
    m = logical( eye(obj.N) );
    f = obj.cMat;
    nBin = fliplr(dec2bin(n));  
    for b=1:length(nBin) 
      if nBin(b)=='1', m=logical(mod(m*f,2)); end
      f = logical(mod(f*f,2));
    end
  end

 end % methods private
 
end %classdef
