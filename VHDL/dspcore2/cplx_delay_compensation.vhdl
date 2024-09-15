-------------------------------------------------------------------------------
-- @file       cplx_delay_compensation.vhdl
-- @author     Fixitfetish
-- @date       15/Sep/2024
-- @note       VHDL-2008
-- @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Code comments are optimized for SIGASI.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

-- Complex Delay Compensation.
-- This entity shall be used for pure (local) delay compensation only.
-- The delay is provided as port (static or even dynamic) and not as generic parameter.
-- The module does not prohibit the use of SRLs intentionally.
-- For explicit pipelining across larger distances to improve timing use cplx_pipeline instead.
--
-- VHDL Instantiation Template:
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
-- I1 : entity work.cplx_delay_compensation
-- generic map(
--   MAX_PIPELINE_STAGES => positive, -- max number of pipeline stages
--   MODE                => cplx_mode -- options
-- )
-- port map(
--   clk        => in  std_logic, -- clock
--   rst        => in  std_logic, -- optional global reset
--   clkena     => in  std_logic, -- clock enable
--   delay      => in  natural, -- dynamic delay
--   din        => in  cplx, -- complex input
--   dout       => out cplx  -- complex output
-- );
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
entity cplx_delay_compensation is
generic (
  -- The number of maximum pipeline stages (mandatory!). 
  MAX_PIPELINE_STAGES : positive;
  -- Supported operation mode is 'R', i.e. reset data when rst='1' or din.rst='1' .
  MODE : cplx_mode := "-"
);
port (
  -- Clock
  clk        : in  std_logic;
  -- Optional synchronous reset insertion. Set OPEN or '0' to reduce global
  -- reset fanout and to only use the pipelined reset din.rst instead. 
  rst        : in  std_logic := '0';
  -- Clock enable
  clkena     : in  std_logic := '1';
  -- required delay in number of pipeline stages
  delay      : in  natural range 0 to MAX_PIPELINE_STAGES;
  -- Complex data input of delay pipeline. Must have same data width as output.
  din        : in  cplx;
  -- Complex data output of delay pipeline. Must have same data width as input.
  dout       : out cplx
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (MODE='-' or MODE='R')
    report cplx_delay_compensation'INSTANCE_NAME & ":: " &
           "Only mode 'R' is supported. Ignoring other modes ..."
    severity warning;
  assert (din.re'length=dout.re'length) and (din.im'length=dout.im'length)
    report cplx_delay_compensation'INSTANCE_NAME & ":: " &
           "Input and output data width must be the same."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_delay_compensation is

  type t_pipe_re is array(integer range <>) of signed(din.re'range);
  type t_pipe_im is array(integer range <>) of signed(din.im'range);

  signal pipe_rst : std_logic_vector(0 to MAX_PIPELINE_STAGES) := (others=>'0');
  signal pipe_vld : std_logic_vector(0 to MAX_PIPELINE_STAGES) := (others=>'0');
  signal pipe_ovf : std_logic_vector(0 to MAX_PIPELINE_STAGES) := (others=>'0');
  signal pipe_re : t_pipe_re(0 to MAX_PIPELINE_STAGES) := (others=>(others=>'-'));
  signal pipe_im : t_pipe_im(0 to MAX_PIPELINE_STAGES) := (others=>(others=>'-'));

begin

  -- map input ports to pipeline input (consider reset also for 0 pipeline stages, i.e. bypass)
  pipe_rst(0) <= din.rst or rst;
  pipe_vld(0) <= din.vld and (not pipe_rst(0));
  pipe_ovf(0) <= din.ovf and (not pipe_rst(0));
  pipe_re(0) <= (others=>'0') when (MODE='R' and pipe_rst(0)='1') else din.re;
  pipe_im(0) <= (others=>'0') when (MODE='R' and pipe_rst(0)='1') else din.im;

  p_pipe : process(clk)
  begin
    if rising_edge(clk) then
      if clkena='1' then
        pipe_rst(1 to MAX_PIPELINE_STAGES) <= pipe_rst(0 to MAX_PIPELINE_STAGES-1);
        pipe_vld(1 to MAX_PIPELINE_STAGES) <= pipe_vld(0 to MAX_PIPELINE_STAGES-1);
        pipe_ovf(1 to MAX_PIPELINE_STAGES) <= pipe_ovf(0 to MAX_PIPELINE_STAGES-1);
        pipe_re(1 to MAX_PIPELINE_STAGES)  <= pipe_re(0 to MAX_PIPELINE_STAGES-1);
        pipe_im(1 to MAX_PIPELINE_STAGES)  <= pipe_im(0 to MAX_PIPELINE_STAGES-1);
      end if;
    end if;
  end process;

  -- map output of pipeline to output ports
  dout.rst <= pipe_rst(delay);
  dout.vld <= pipe_vld(delay);
  dout.ovf <= pipe_ovf(delay);
  dout.re  <= pipe_re(delay);
  dout.im  <= pipe_im(delay);

end architecture;
