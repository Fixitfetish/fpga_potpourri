-------------------------------------------------------------------------------
--! @file       cplx_pipeline.vhdl
--! @author     Fixitfetish
--! @date       16/Jun/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
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

entity cplx_pipeline is
generic (
  --! The number of pipeline stages >=1 (mandatory!)
  NUM_PIPELINE_STAGES : positive;
  --! Supported operation modes are 'X' and 'R', i.e. reset data when rst='1'
  MODE : cplx_mode := "-"
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset pipeline and output (optional)
  rst        : in  std_logic := '0';
  --! Complex data input of delay pipeline
  din        : in  cplx;
  --! Complex data output of delay pipeline
  dout       : out cplx
);
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_pipeline is

  alias N is NUM_PIPELINE_STAGES;

  -- !NOTE! It is the intention to NOT use the CPLX record here. Hence, the
  -- following code is the same for any data width and for VHDL 1993 and 2008.

  type t_pipe_re is array(integer range <>) of signed(din.re'range);
  type t_pipe_im is array(integer range <>) of signed(din.im'range);

  signal pipe_rst : std_logic_vector(0 to N);
  signal pipe_vld : std_logic_vector(0 to N);
  signal pipe_ovf : std_logic_vector(0 to N);
  signal pipe_re : t_pipe_re(0 to N);
  signal pipe_im : t_pipe_im(0 to N);

begin

  -- map input ports to pipeline input
  pipe_rst(0) <= din.rst;
  pipe_vld(0) <= din.vld;
  pipe_ovf(0) <= '0' when MODE='X' else din.ovf;
  pipe_re(0) <= din.re;
  pipe_im(0) <= din.im;

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

  -- map output of pipeline to output ports
  dout.rst <= pipe_rst(N);
  dout.vld <= pipe_vld(N);
  dout.ovf <= pipe_ovf(N);
  dout.re <= pipe_re(N);
  dout.im <= pipe_im(N);

end architecture;
