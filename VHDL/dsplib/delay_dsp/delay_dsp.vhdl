-------------------------------------------------------------------------------
--! @file       delay_dsp.vhdl
--! @author     Fixitfetish
--! @date       07/May/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
 use ieee.std_logic_1164.all;

--! @brief Use DSP cell internal registers for delay pipelines. 
--! 
--! This entity might be useful for short delay pipelines when logic and memory
--! elements run out and many DSP cells remain unused. 
--! Note that using DSP cells for delay pipelines only makes sense with modern
--! DSP cells which support at least 3 pipeline stages with a width of 36 bits
--! or more. The input should be reasonably wide to have a logic saving effect,
--! otherwise the logic saving effect is questionable.
--! Pure delay pipelines in logic typically only make use of the register
--! elements but not the LUT elements. Though modern FPGAs can use LUT and register
--! elements independently it can be an advantage to move register into DSP cells.
--! 
--! Advantages
--! * uses wide registers within unused DSP cells instead single registers in logic elements
--! * routing resources between pipeline registers are not required because of fixed DSP internal routing
--! * fan-out reduction of reset and clock enable signal (only a few signals per DSP cell required)
--! * reset values other than 0 can be achieved without additional logic (in most cases)
--!
--! Disadvantages
--! * only a few registers stages are reasonable, otherwise this approach is not recommended
--! * pipeline registers can not be distributed within FPGA (e.g. to solve timing issues)
--! * higher power consumption because whole DSP cell must be active
--! * wrapper required to map any signals to generic port of the delay entity 

entity delay_dsp is
generic (
  --! The number of pipeline stages >= 2 (mandatory!)
  NUM_PIPELINE_STAGES : positive range 2 to integer'high ;
  --! @brief Enable the flushing reset feature with a reset value of same width
  --! as the data input. If the flushing reset is disabled (FLUSH_RESET_VALUE="0")
  --! then the reset value (others=>'0') is applied to the output immediately.
  FLUSH_RESET_VALUE : std_logic_vector;
  --! @brief Flush pipeline only when reset and clock enable are '1'.
  --! By default the pipeline is flushed with every clock cycle when rst='1'.
  --! If FLUSH_WITH_CLKENA is enabled then not only the reset but also the
  --! clock enable must be '1' to flush the pipeline.
  --! This generic is only relevant when the flushing reset feature is enabled.
  FLUSH_WITH_CLKENA : boolean := false
);
port (
  --! Standard system clock
  clk        : in  std_logic;
  --! Reset pipeline and output (optional)
  rst        : in  std_logic := '0';
  --! Clock enable (optional)
  clkena     : in  std_logic := '1';
  --! Data input of delay pipeline (any width >=2)
  din        : in  std_logic_vector;
  --! Data output of delay pipeline (same width as input)
  dout       : out std_logic_vector
);
begin

  assert (dout'length=din'length)
    report "ERROR in " & delay_dsp'INSTANCE_NAME & 
           " Input and output vector must have same width."
    severity failure;
  
  assert (FLUSH_RESET_VALUE'length=1 or FLUSH_RESET_VALUE'length=din'length)
    report "ERROR in " & delay_dsp'INSTANCE_NAME & 
           " Width of generic FLUSH_RESET_VALUE must be 1 or same as input din."
    severity failure;
  
end entity;
