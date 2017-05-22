classdef cplx_stimuli
% description of this class

 properties (Access=public)
   Title = ''
   % matlab data format 'int' or 'frac' (double)
   %   'int'  = -2^(CplxWidth-1) .. 2^(CplxWidth-1)-1
   %   'frac' = -1.0000 .. +0.9999 
   Format = 'int'
 end

 properties (GetAccess=public, SetAccess=private)
   Length = 0 % length of data vector
   CplxWidth % width of signed real/imag data in bits
   CplxRst = logical([])
   CplxVld = logical([])
   CplxOvf = logical([])
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
 
   function obj = cplx_stimuli(width,format)
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
     % number of characters per line (3 bits + 2 signed + 10 spaces)
     ch = 3 + 2*obj.NumDigits + 10;
   end

   function obj = appendReset(obj,n)
     if (n<1 || n~=fix(n)),
       error('Number of reset cycles must be positive integer.');
     end
     obj.CplxRst  = [obj.CplxRst ; true(n,1)];
     obj.CplxVld  = [obj.CplxVld ; false(n,1)];
     obj.CplxOvf  = [obj.CplxOvf ; false(n,1)];
     obj.CplxData = [obj.CplxData; complex(zeros(n,1))];
     obj.Length = obj.Length + n;
   end

   function obj = appendInvalid(obj,n)
     if (n<1 || n~=fix(n)),
       error('Number of invalid cycles must be positive integer.');
     end
     obj.CplxRst  = [obj.CplxRst ; false(n,1)];
     obj.CplxVld  = [obj.CplxVld ; false(n,1)];
     obj.CplxOvf  = [obj.CplxOvf ; false(n,1)];
     obj.CplxData = [obj.CplxData; complex(zeros(n,1))];
     obj.Length = obj.Length + n;
   end

   function obj = appendData(obj,data,vld)
     n = length(data);
     if (isempty(data) || n~=numel(data)),
       error('Input data must be a complex row or column vector.');
     end
     % convert to column vector
     data = reshape(data,[],1);
     ovf = false(n,1);
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
       if length(vld)~=n,
         error('Input valid flags must have same length as input data.');
       end 
       vld = logical(reshape(vld,[],1)); % convert to column vector
     else
       vld = true(n,1);
     end

     obj.CplxRst  = [obj.CplxRst ; false(n,1) ];
     obj.CplxVld  = [obj.CplxVld ; vld ];
     obj.CplxOvf  = [obj.CplxOvf ; ovf ];
     obj.CplxData = [obj.CplxData; re+i*im ];
     obj.Length = obj.Length + n;
     
   end

   function m = get.CplxMat(obj)
     m = [ obj.CplxRst, obj.CplxVld, obj.CplxOvf, real(obj.CplxData), imag(obj.CplxData) ];
   end

   function c = get.CplxChar(obj)
     % cplx output format
     cformat = ['%',num2str(obj.NumDigits),'d'];
     cformat = ['%3d%4d%4d ',cformat,' ',cformat];
     % create character matrix
     c = repmat(' ',obj.Length,obj.NumChars);
     for n=1:obj.Length,
       c(n,:) = sprintf(cformat, obj.CplxRst(n), obj.CplxVld(n), obj.CplxOvf(n),...
                        real(obj.CplxData(n)), imag(obj.CplxData(n)) );
     end
     % add optional header when title available
     if ~isempty(obj.Title),
       hformat = ['RST VLD OVF %',num2str(obj.NumDigits),'s %',num2str(obj.NumDigits),'s'];
       h = [ sprintf(['%-',num2str(obj.NumChars),'s'],obj.Title) ;
             sprintf(hformat,'REAL','IMAG') ];
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
     obj.CplxRst = logical(x(:,1));
     obj.CplxVld = logical(x(:,2));
     obj.CplxOvf = logical(x(:,3));
     re = x(:,4);
     im = x(:,5);
     obj.CplxData = re + i*im;
     % derived width including sign bit
     obj.CplxWidth = ceil(log2( max(abs([re;im])) )) + 1; 
     % set length after width! (avoid unnecessary clipping)
     obj.Length = size(x,1);
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
