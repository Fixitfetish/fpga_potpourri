-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_readme.txt
-- AUTHOR  : Fixitfetish
-- DATE    : 12/Nov/2016
-- VERSION : 0.1
-- LICENSE : MIT License  https://opensource.org/licenses/MIT
--                        https://en.wikipedia.org/wiki/MIT_License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------

The complex package "CPLX_PKG" includes basic types and functions for complex integer arithmetic 
that are used for e.g. digital signal processing. It supports FPGA developers to handle complex
data streams and pipelines in an easier and quicker way using a common complex data interface.
The package is based on the IEEE "numeric_std" package and also needs the "ieee_extension" package
that includes the required additional "signed" arithmetic and comes with this package. The CPLX_PKG
is available for VHDL-1993 and VHDL-2008. While the VHDL-1993 variant has limitations and might
need to be extended manually the VHDL-2008 variant has the full flexibility in terms of bit
resolution. Boths variants have been developed to be more or less compatible.

The main interface base type is the complex record "CPLX" which includes the most common signals
required for complex data streaming.

  -- general unconstrained complex type (VHDL-2008)
  type cplx is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or saturation/clipping)
    re  : signed; -- data real component ("downto" direction assumed)
    im  : signed; -- data imaginary component ("downto" direction assumed)
  end record;

An additional complex vector base type supports multiple parallel complex data streams.

  -- general unconstrained complex vector type (preferably "to" direction)
  type cplx_vector is array(integer range <>) of cplx; -- VHDL-2008

In VHDL-2008 subtypes with constrained data resolution are derived from the base types as follows:

  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));

Note that always the base types or subtypes of the base types must be used.
Signals can be declared as follows: 

  signal a16 : cplx(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal b16 : cplx16; -- use subtype (i.e. base type in VHDL-1993)

  signal vec_a16 : cplx_vector(0 to 3)(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal vec_b16 : cplx16_vector(0 to 3); -- use subtype (i.e. base type in VHDL-1993)

Since unconstrained arrays in records are not supported in VHDL-1993 only a limited set of types is
predefined. The VHDL-1993 variant can be extended to any wanted data resolution if needed.

