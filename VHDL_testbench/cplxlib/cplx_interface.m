classdef cplx_interface
% description of this class

 properties (Access=public)
   Title = ''
   % matlab data format 'int' or 'frac' (double)
   %   'int'  = -2^(CplxWidth-1) .. 2^(CplxWidth-1)-1
   %   'frac' = -1.0000 .. +0.9999 
   Format = 'int'
 end

 properties (GetAccess=public, SetAccess=private)
   Length = 0 % length of data vector (cycles = rows)
   VecNum = 0 % number of data vectors (colums)
   CplxWidth % width of signed real/imag data in bits
   CplxRst = []
   CplxVld = []
   CplxOvf = []
   CplxData = complex([])
 % CplxFormat  decimal/hexadecimal/binary in file ...  TODO  
 end

 properties (Dependent)
   NumDigits % max number of decimal digits of real/imag including sign
   NumChars % number of chars per line in file
   CplxMat % CPLX flags and data as double matrix
   CplxChar % CPLX flags and data in character matrix (e.g. for TXT file export)
 end

 methods (Access=public)
 
   function obj = cplx_interface(width,format)
   % class constructor
     if (nargin>=1), obj.CplxWidth = width; end
     if (nargin>=2), obj.Format = format; end
   end

   function obj = set.Format(obj,f)
     if ~strcmp(f,'int') && ~strcmp(f,'frac'),
       error('Input data format must be "int" or "frac".');
     end
     obj.Format = f;
   end

   function obj = set.Title(obj,t)
     if ~strcmp(class(t),'char'),
       error('Data title must be a character string.');
     end
     if length(t)>10,
       error('Data title is too long.');
     end
     obj.Title = t;
   end

   function d = get.NumDigits(obj)
     d = ceil(log10(2^(obj.CplxWidth-1))) + 1;
   end

   function ch = get.NumChars(obj)
     % number of characters per line (3 bits + 2 signed + 12 spaces)
     ch = 3 + 2*obj.NumDigits + 12;
   end

   function obj = appendReset(obj,L,N)
     if (L<1 || L~=fix(L)),
       error('Number of reset cycles L must be positive integer.');
     end
     if nargin<=2,
       if obj.VecNum==0,
         error('Number of data vectors N required with first append.');
       end
     elseif (N<1 || N~=fix(N)),
       error('Number of data vectors must be positive integer.');
     elseif obj.VecNum==0, % first call of an 'append' function
       obj.VecNum = N;
     elseif N~=obj.VecNum,
       % consequent call of an 'append' function 
       error(['Number of data vectors N has already been defined to be ',...
              num2str(obj.VecNum)]);
     end
     obj.CplxRst  = [obj.CplxRst ; ones(L,obj.VecNum)];
     obj.CplxVld  = [obj.CplxVld ; zeros(L,obj.VecNum)];
     obj.CplxOvf  = [obj.CplxOvf ; zeros(L,obj.VecNum)];
     obj.CplxData = [obj.CplxData; complex(zeros(L,obj.VecNum))];
     obj.Length = obj.Length + L;
   end

   function obj = appendInvalid(obj,L,N)
     if (L<1 || L~=fix(L)),
       error('Number of invalid cycles L must be positive integer.');
     end
     if nargin<=2,
       if obj.VecNum==0,
         error('Number of data vectors N required with first append.');
       end
     elseif (N<1 || N~=fix(N)),
       error('Number of data vectors N must be positive integer.');
     elseif obj.VecNum==0, % first call of an 'append' function
       obj.VecNum = N;
     elseif N~=obj.VecNum,
       % consequent call of an 'append' function 
       error(['Number of data vectors N has already been defined to be ',...
              num2str(obj.VecNum)]);
     end
     obj.CplxRst  = [obj.CplxRst ; zeros(L,obj.VecNum)];
     obj.CplxVld  = [obj.CplxVld ; zeros(L,obj.VecNum)];
     obj.CplxOvf  = [obj.CplxOvf ; zeros(L,obj.VecNum)];
     obj.CplxData = [obj.CplxData; complex(zeros(L,obj.VecNum))];
     obj.Length = obj.Length + L;
   end

   function obj = appendData(obj,data,vld)
     [L,N] = size(data);
     if ( isempty(data) || (L*N)~=numel(data) ),
       error('Input data must be a complex column or row vector or a 2-dim matrix.');
     end
     if obj.VecNum==0, % first call of an 'append' function
       obj.VecNum = N;
     elseif N~=obj.VecNum,
       % consequent call of an 'append' function 
       error(['Number of data vectors N has already been defined to be ',...
              num2str(obj.VecNum)]);
     end
     ovf = false(L,N);
     % convert to integer and round
     if strcmp(obj.Format,'frac'),
       re = round(2^(obj.CplxWidth-1) * real(data));
       im = round(2^(obj.CplxWidth-1) * imag(data));
     else
       re = round(real(data));
       im = round(imag(data));
     end

     % positive clipping
     re_clip = re > (2^(obj.CplxWidth-1)-1);
     im_clip = im > (2^(obj.CplxWidth-1)-1);
     re(re_clip) = 2^(obj.CplxWidth-1)-1;
     im(im_clip) = 2^(obj.CplxWidth-1)-1;
     ovf = ovf | re_clip | im_clip;

     % negative clipping
     re_clip = re < -2^(obj.CplxWidth-1);
     im_clip = im < -2^(obj.CplxWidth-1);
     re(re_clip) = -2^(obj.CplxWidth-1);
     im(im_clip) = -2^(obj.CplxWidth-1);
     ovf = ovf | re_clip | im_clip;

     % valid flags
     if exist('vld','var'),
       if size(vld)~=[L,N],
         error('Input valid flags must have same size as input data.');
       end 
     else
       vld = ones(L,N); % all true
     end

     obj.CplxRst  = [obj.CplxRst ; zeros(L,N) ];
     obj.CplxVld  = [obj.CplxVld ; vld ];
     obj.CplxOvf  = [obj.CplxOvf ; ovf ];
     obj.CplxData = [obj.CplxData; re+i*im ];
     obj.Length = obj.Length + L;
     
   end

   function m = get.CplxMat(obj)
     if obj.Length>=1,
       m = zeros(obj.Length, 5, obj.VecNum);
       for n=1:obj.VecNum,
         m(:,:,n) = [ obj.CplxRst(:,n), obj.CplxVld(:,n), obj.CplxOvf(:,n), ...
                      real(obj.CplxData(:,n)), imag(obj.CplxData(:,n)) ];
       end
     else
       m = [];
     end
   end

   function c = get.CplxChar(obj)
     % cplx output format
     cformat = ['%',num2str(obj.NumDigits),'d'];
     cformat = ['%3d%4d%4d ',cformat,' ',cformat,'  '];
     % create character matrix
     c = repmat(' ', obj.Length, obj.VecNum*obj.NumChars);
     for n=1:(obj.VecNum),
       crange = (n-1)*obj.NumChars + (1:obj.NumChars);
       for l=1:obj.Length,
         c(l,crange) = ...
           sprintf(cformat, obj.CplxRst(l,n), obj.CplxVld(l,n), obj.CplxOvf(l,n),...
                   real(obj.CplxData(l,n)), imag(obj.CplxData(l,n)) );
       end
     end
     % add optional header when title available
     if ~isempty(obj.Title),
       hformat = ['%',num2str(obj.NumDigits),'s'];
       hformat = ['RST VLD OVF ',hformat,' ',hformat,'  '];
       h = repmat(' ', 2, obj.VecNum*obj.NumChars);
       for n=0:(obj.VecNum-1),
         hrange = n*obj.NumChars + (1:obj.NumChars);
         h(:,hrange) = ...
          [ sprintf(['%-',num2str(obj.NumChars),'s'],[obj.Title,' ',num2str(n)]) ;
            sprintf(hformat,'REAL','IMAG') ];
       end
       c = [ h ; c ];
     end
   end %get.CplxChar

   function writeFile(obj,fname)
     dlmwrite(fname,obj.CplxChar,'');
   end

   function obj = readFile(obj,fname)
     x = dlmread(fname,'','emptyvalue',NaN);
     t = ''; % default title
     % check for header (second row are the column names)
     if all(isnan(x(2,:))),
       x = x(3:end,:);
       % title = file name
       [folder,t,ext] = fileparts(fname);
     end
     [L,N] = size(x);
     N = N/5; % 5 columns per cplx
     obj.CplxRst = x(:,1:5:end);
     obj.CplxVld = x(:,2:5:end);
     obj.CplxOvf = x(:,3:5:end);
     re = x(:,4:5:end);
     im = x(:,5:5:end);
     obj.CplxData = re + i*im;
     % derived width including sign bit
     obj.CplxWidth = ceil(log2( max(max(abs([re;im]))) )) + 1; 
     % set length after width! (avoid unnecessary clipping)
     obj.Length = L;
     obj.VecNum = N;
     obj.Title = t;
   end
 
 end %methods

 methods (Access=private)

   function obj = set.CplxWidth(obj,width)
     if (width<0 || width~=fix(width)),
       error('Width in bits must be positive integer.');
     end
     if width<4,
       error('Data width of less than 4 bits is not supported.');
     end
     % run clipping when width shrinks
     if (obj.Length>0) && (width < obj.CplxWidth),
       % TODO ... run clipping
     end
     obj.CplxWidth = width;
   end

 end %methods

end %classdef
