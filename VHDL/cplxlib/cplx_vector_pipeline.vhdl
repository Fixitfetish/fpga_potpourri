-------------------------------------------------------------------------------
--! @file       cplx_vector_pipeline.vhdl
--! @author     Fixitfetish
--! @date       15/May/2019
--! @version    0.20
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

--! @brief Complex Vector Delay Pipeline.
--!
--! See also : cplx_pipeline
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_vector_pipeline
--! generic map(
--!   NUM_PIPELINE_STAGES => integer, -- number of required pipeline stages
--!   MODE                => cplx_mode -- options
--! )
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- optional global reset
--!   clkena     => in  std_logic, -- clock enable
--!   din        => in  cplx_vector, -- complex vector input
--!   dout       => out cplx_vector  -- complex vector output
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!
entity cplx_vector_pipeline is
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
  --! Clock enable
  clkena     : in  std_logic := '1';
  --! Complex data vector input of delay pipeline. Must have same length as output.
  din        : in  cplx_vector;
  --! Complex data vector output of delay pipeline. Must have same length as input.
  dout       : out cplx_vector
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (din'length=dout'length)
    report "ERROR in " & cplx_vector_pipeline'INSTANCE_NAME & 
           " Input and output vector must have same length."
    severity failure;
  assert (din'ascending and dout'ascending)
    report "ERROR in " & cplx_vector_pipeline'INSTANCE_NAME & 
           " Input and output vector must have 'TO' range."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_vector_pipeline is
  
  constant LEN : positive := din'length; 

begin

  -- consider different range of input and output vector
  gn : for n in 0 to (LEN-1) generate

    i_pipe : entity cplxlib.cplx_pipeline
    generic map(
      NUM_PIPELINE_STAGES => NUM_PIPELINE_STAGES,
      MODE                => MODE
    )
    port map(
      clk        => clk,
      rst        => rst,
      clkena     => clkena,
      din        => din(din'left+n),
      dout       => dout(dout'left+n)
    );

  end generate;

end architecture;
