-------------------------------------------------------------------------------
--! @file       cplx_pipeline.vhdl
--! @author     Fixitfetish
--! @date       17/Feb/2018
--! @version    0.30
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Complex Delay Pipeline.
--!
--! See also : cplx_vector_pipeline
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_pipeline
--! generic map(
--!   NUM_PIPELINE_STAGES => integer, -- number of required pipeline stages
--!   MODE                => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- optional global reset
--!   din        => in  cplx, -- complex input
--!   dout       => out cplx  -- complex output
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_pipeline is
generic (
  --! @brief The number of pipeline stages (mandatory!). 
  --! If <=0 then bypass without any register pipeline stages. 
  NUM_PIPELINE_STAGES : integer;
  --! Supported operation mode is 'R', i.e. reset data when rst='1' or din.rst='1' .
  MODE : cplx_mode := "-"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! @brief Optional global reset of complete pipeline and output. Set OPEN or '0'
  --! to reduce global reset fanout and to only use the pipelined reset din.rst instead.  
  rst        : in  std_logic := '0';
  --! Complex data input of delay pipeline. Must have same data width as output.
  din        : in  cplx;
  --! Complex data output of delay pipeline. Must have same data width as input.
  dout       : out cplx
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (din.re'length=dout.re'length)
    report "ERROR in " & cplx_pipeline'INSTANCE_NAME & 
           " Real input and output must have same width."
    severity failure;
  assert (din.im'length=dout.im'length)
    report "ERROR in " & cplx_pipeline'INSTANCE_NAME & 
           " Imaginary input and output must have same width."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_pipeline is

  function N return natural is
  begin
    if NUM_PIPELINE_STAGES>0 then return NUM_PIPELINE_STAGES; else return 0; end if;
  end function;

  -- !NOTE! It is the intention to NOT use the CPLX record here. Hence, the
  -- following code is the same for any data width and for VHDL 1993 and 2008.

  type t_pipe_re is array(integer range <>) of signed(din.re'range);
  type t_pipe_im is array(integer range <>) of signed(din.im'range);

  signal pipe_rst : std_logic_vector(0 to N);
  signal pipe_vld : std_logic_vector(0 to N);
  signal pipe_ovf : std_logic_vector(0 to N);
  signal pipe_re : t_pipe_re(0 to N) := (others=>(others=>'-'));
  signal pipe_im : t_pipe_im(0 to N) := (others=>(others=>'-'));

begin

  -- map input ports to pipeline input (consider reset for N=0, i.e. bypass)
  pipe_rst(0) <= din.rst or rst;
  pipe_vld(0) <= din.vld and (not pipe_rst(0));
  pipe_ovf(0) <= din.ovf and (not pipe_rst(0));
  pipe_re(0) <= (others=>'0') when (MODE='R' and pipe_rst(0)='1') else din.re;
  pipe_im(0) <= (others=>'0') when (MODE='R' and pipe_rst(0)='1') else din.im;

  gn : if N>=1 generate
  begin
    p_pipe : process(clk)
    begin
      if rising_edge(clk) then
        -- always reset control bits
        if rst='1' then
          pipe_rst(1 to N) <= (others=>'1');
          pipe_vld(1 to N) <= (others=>'0');
          pipe_ovf(1 to N) <= (others=>'0');
        else
          pipe_rst(1 to N) <= pipe_rst(0 to N-1);
          pipe_vld(1 to N) <= pipe_vld(0 to N-1);
          pipe_ovf(1 to N) <= pipe_ovf(0 to N-1);
        end if;
        -- reset data only if really wanted
        if MODE='R' and rst='1' then
          pipe_re(1 to N) <= (others=>(others=>'0'));
          pipe_im(1 to N) <= (others=>(others=>'0'));
        else
          pipe_re(1 to N) <= pipe_re(0 to N-1);
          pipe_im(1 to N) <= pipe_im(0 to N-1);
        end if;
      end if;
    end process;
  end generate;

  -- map output of pipeline to output ports
  dout.rst <= pipe_rst(N);
  dout.vld <= pipe_vld(N);
  dout.ovf <= pipe_ovf(N);
  dout.re <= pipe_re(N);
  dout.im <= pipe_im(N);

end architecture;
