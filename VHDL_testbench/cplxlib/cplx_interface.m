classdef cplx_interface
% description of this class

 properties (Access=public)
   Title = ''
   % matlab data format 'int' or 'frac' (both of class double)
   %   'int'  = -2^(DataWidth-1) .. 2^(DataWidth-1)-1
   %   'frac' = -1.0000 .. +0.9999 
   Format = 'int'
 end

 properties (GetAccess=public, SetAccess=private)
   Length = 0 % length of data stream (number of cycles = rows)
   Streams = 0 % number of data stream = vector width (number of columns)
   DataWidth % width of signed real/imag data in bits
   DataFormat = 'dec' % data format in text file ... TODO ... 'dec', 'hex', 'bin'
   cplx = struct('rst', [],...
                 'vld', [],...
                 'ovf', [],...
                 'data', complex([])); 
 end

 properties (Dependent)
   NumDigits % max number of decimal digits of real/imag including sign
   NumChars % number of chars per line in file
   MatrixDouble % CPLX flags and data as double matrix
   MatrixChar % CPLX flags and data in character matrix (e.g. for TXT file export)
 end

 methods (Access=public)
 
   function obj = cplx_interface(width,format)
   % class constructor
     if (nargin>=1), obj.DataWidth = width; end
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
     if strcmp(obj.DataFormat,'dec'),
       d = ceil(log10(2^(obj.DataWidth-1))) + 1;
     elseif strcmp(obj.DataFormat,'hex'),
       d = ceil(obj.DataWidth/4);
     elseif strcmp(obj.DataFormat,'bin'),
       d = obj.DataWidth;
     end
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
       if obj.Streams==0,
         error('Number of data streams N required with first append.');
       end
     elseif (N<1 || N~=fix(N)),
       error('Number of data streams N must be positive integer.');
     elseif obj.Streams==0, % first call of an 'append' function
       obj.Streams = N;
     elseif N~=obj.Streams,
       % consequent call of an 'append' function 
       error(['Number of data streams N has already been defined to be ',...
              num2str(obj.Streams)]);
     end
     obj.cplx.rst  = [obj.cplx.rst ; ones(L,obj.Streams)];
     obj.cplx.vld  = [obj.cplx.vld ; zeros(L,obj.Streams)];
     obj.cplx.ovf  = [obj.cplx.ovf ; zeros(L,obj.Streams)];
     obj.cplx.data = [obj.cplx.data; complex(zeros(L,obj.Streams))];
     obj.Length = obj.Length + L;
   end

   function obj = appendInvalid(obj,L,N)
     if (L<1 || L~=fix(L)),
       error('Number of invalid cycles L must be positive integer.');
     end
     if nargin<=2,
       if obj.Streams==0,
         error('Number of data streams N required with first append.');
       end
     elseif (N<1 || N~=fix(N)),
       error('Number of data streams N must be positive integer.');
     elseif obj.Streams==0, % first call of an 'append' function
       obj.Streams = N;
     elseif N~=obj.Streams,
       % consequent call of an 'append' function 
       error(['Number of data streams N has already been defined to be ',...
              num2str(obj.Streams)]);
     end
     obj.cplx.rst  = [obj.cplx.rst ; zeros(L,obj.Streams)];
     obj.cplx.vld  = [obj.cplx.vld ; zeros(L,obj.Streams)];
     obj.cplx.ovf  = [obj.cplx.ovf ; zeros(L,obj.Streams)];
     obj.cplx.data = [obj.cplx.data; complex(zeros(L,obj.Streams))];
     obj.Length = obj.Length + L;
   end

   function obj = appendData(obj,data,vld)
     [L,N] = size(data);
     if ( isempty(data) || (L*N)~=numel(data) ),
       error('Input data must be a complex column or row vector or a 2-dim matrix.');
     end
     if obj.Streams==0, % first call of an 'append' function
       obj.Streams = N;
     elseif N~=obj.Streams,
       % consequent call of an 'append' function 
       error(['Number of data streams N has already been defined to be ',...
              num2str(obj.Streams)]);
     end
     ovf = false(L,N);
     % convert to integer and round
     if strcmp(obj.Format,'frac'),
       re = round(2^(obj.DataWidth-1) * real(data));
       im = round(2^(obj.DataWidth-1) * imag(data));
     else
       re = round(real(data));
       im = round(imag(data));
     end

     % positive clipping
     re_clip = re > (2^(obj.DataWidth-1)-1);
     im_clip = im > (2^(obj.DataWidth-1)-1);
     re(re_clip) = 2^(obj.DataWidth-1)-1;
     im(im_clip) = 2^(obj.DataWidth-1)-1;
     ovf = ovf | re_clip | im_clip;

     % negative clipping
     re_clip = re < -2^(obj.DataWidth-1);
     im_clip = im < -2^(obj.DataWidth-1);
     re(re_clip) = -2^(obj.DataWidth-1);
     im(im_clip) = -2^(obj.DataWidth-1);
     ovf = ovf | re_clip | im_clip;

     % valid flags
     if exist('vld','var'),
       if size(vld)~=[L,N],
         error('Input valid flags must have same size as input data.');
       end 
     else
       vld = ones(L,N); % all true
     end

     obj.cplx.rst  = [obj.cplx.rst ; zeros(L,N) ];
     obj.cplx.vld  = [obj.cplx.vld ; vld ];
     obj.cplx.ovf  = [obj.cplx.ovf ; ovf ];
     obj.cplx.data = [obj.cplx.data; re+i*im ];
     obj.Length = obj.Length + L;
     
   end

   function m = get.MatrixDouble(obj)
     if obj.Length>=1,
       m = zeros(obj.Length, 5, obj.Streams);
       for n=1:obj.Streams,
         m(:,:,n) = [ obj.cplx.rst(:,n), obj.cplx.vld(:,n), obj.cplx.ovf(:,n), ...
                      real(obj.cplx.data(:,n)), imag(obj.cplx.data(:,n)) ];
       end
     else
       m = [];
     end
   end

   function c = get.MatrixChar(obj)
     % cplx output format
     cformat = ['%',num2str(obj.NumDigits),'d'];
     cformat = ['%3d%4d%4d ',cformat,' ',cformat,'  '];
     % create character matrix
     c = repmat(' ', obj.Length, obj.Streams*obj.NumChars);
     for n=1:(obj.Streams),
       crange = (n-1)*obj.NumChars + (1:obj.NumChars);
       for l=1:obj.Length,
         c(l,crange) = ...
           sprintf(cformat, obj.cplx.rst(l,n), obj.cplx.vld(l,n), obj.cplx.ovf(l,n),...
                   real(obj.cplx.data(l,n)), imag(obj.cplx.data(l,n)) );
       end
     end
     % add optional header when title available
     if ~isempty(obj.Title),
       hformat = ['%',num2str(obj.NumDigits),'s'];
       hformat = ['RST VLD OVF ',hformat,' ',hformat,'  '];
       h = repmat(' ', 2, obj.Streams*obj.NumChars);
       for n=0:(obj.Streams-1),
         hrange = n*obj.NumChars + (1:obj.NumChars);
         h(:,hrange) = ...
          [ sprintf(['%-',num2str(obj.NumChars),'s'],[obj.Title,' ',num2str(n)]) ;
            sprintf(hformat,'REAL','IMAG') ];
       end
       c = [ h ; c ];
     end
   end %get.MatrixChar

   function writeFile(obj,fname)
     dlmwrite(fname,obj.MatrixChar,'');
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
     obj.cplx.rst = x(:,1:5:end);
     obj.cplx.vld = x(:,2:5:end);
     obj.cplx.ovf = x(:,3:5:end);
     re = x(:,4:5:end);
     im = x(:,5:5:end);
     obj.cplx.data = re + i*im;
     % derived width including sign bit
     obj.DataWidth = ceil(log2( max(max(abs([re;im]))) )) + 1; 
     % set length after width! (avoid unnecessary clipping)
     obj.Length = L;
     obj.Streams = N;
     obj.Title = t;
   end
 
 end %methods

 methods (Access=private)

   function obj = set.DataWidth(obj,width)
     if (width<0 || width~=fix(width)),
       error('Width in bits must be positive integer.');
     end
     if width<4,
       error('Data width of less than 4 bits is not supported.');
     end
     % run clipping when width shrinks
     if (obj.Length>0) && (width < obj.DataWidth),
       % TODO ... run clipping
     end
     obj.DataWidth = width;
   end

 end %methods

end %classdef
