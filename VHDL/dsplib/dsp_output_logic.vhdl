-------------------------------------------------------------------------------
--! @file       dsp_output_logic.vhdl
--! @author     Fixitfetish
--! @date       02/Jul/2017
--! @version    0.10
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library baselib;
  use baselib.ieee_extension.all;

--! @brief DSP cell output logic that supports right shift, rounding,
--! clipping/saturation and additional pipelining.  
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : dsp_output_logic
--! generic map(
--!   PIPELINE_STAGES    => natural,  -- number of pipeline registers
--!   OUTPUT_SHIFT_RIGHT => natural,  -- number of right shifts
--!   OUTPUT_ROUND       => boolean,  -- enable rounding half-up
--!   OUTPUT_CLIP        => boolean,  -- enable clipping
--!   OUTPUT_OVERFLOW    => boolean   -- enable overflow detection
--! )
--! port map (
--!   clk         => in  std_logic, -- clock
--!   rst         => in  std_logic, -- reset
--!   dsp_out     => in  signed,    -- input data
--!   dsp_out_vld => in  std_logic, -- input valid 
--!   result      => out signed,    -- output data
--!   result_vld  => out std_logic, -- output valid
--!   result_ovf  => out std_logic  -- output overflow
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--!

entity dsp_output_logic is
generic (
  --! @brief Number of additional logic pipeline registers after DSP cell output register.
  --! At least one pipeline register is recommended when logic for rounding,
  --! clipping and/or overflow detection is enabled.
  PIPELINE_STAGES : natural := 1;
  --! Number of bits by which the DSP output is shifted right.
  OUTPUT_SHIFT_RIGHT : natural := 0;
  --! @brief Round 'nearest' (half-up) of result output.
  --! This flag is only relevant when OUTPUT_SHIFT_RIGHT>0.
  --! If enabled then rounding in logic is implemented and it is recommended
  --! to have at least one pipeline register (after rounding and clipping).
  OUTPUT_ROUND : boolean := true;
  --! Enable clipping when right shifted result exceeds output range.
  OUTPUT_CLIP : boolean := true;
  --! Enable overflow/clipping detection 
  OUTPUT_OVERFLOW : boolean := true
);
port (
  --! Standard system clock
  clk         : in  std_logic;
  --! Reset result output (optional)
  rst         : in  std_logic := '0';
  --! DSP cell output data
  dsp_out     : in  signed;
  --! Valid signal for DSP output data, high-active
  dsp_out_vld : in  std_logic;
  --! Pipelined DSP cell output with optional right-shift, rounding and clipping.
  result      : out signed;
  --! Valid signal for result output, high-active
  result_vld  : out std_logic;
  --! Result output overflow/clipping detection
  result_ovf  : out std_logic
);
begin

  assert (not OUTPUT_ROUND) or (OUTPUT_SHIFT_RIGHT/=0)
    report "WARNING in " & dsp_output_logic'INSTANCE_NAME & ": " & 
           "Disabled rounding because OUTPUT_SHIFT_RIGHT is 0."
    severity warning;

  assert (OUTPUT_SHIFT_RIGHT<dsp_out'length)
    report "ERROR in " & dsp_output_logic'INSTANCE_NAME & ": " & 
           "Number of right shifts shall not exceed data input width."
    severity failure;

end entity;

-------------------------------------------------------------------------------

architecture rtl of dsp_output_logic is

  -- derived constants
  constant ROUND_ENABLE : boolean := OUTPUT_ROUND and (OUTPUT_SHIFT_RIGHT/=0);
  constant SHIFTED_WIDTH : natural := dsp_out'length - OUTPUT_SHIFT_RIGHT;
  constant OUTPUT_WIDTH : positive := result'length;

  -- right shifted DSP cell output
  signal dsp_out_shifted : signed(SHIFTED_WIDTH-1 downto 0) := (others=>'0');

  -- result register pipeline
  type r_result is
  record
    dat : signed(OUTPUT_WIDTH-1 downto 0);
    vld : std_logic;
    ovf : std_logic;
  end record;
  type array_result is array(integer range <>) of r_result;
  signal rslt : array_result(0 to PIPELINE_STAGES) := (others=>(dat=>(others=>'0'),vld|ovf=>'0'));

begin

  -- shift right but without rounding
  g_rnd_off : if (not ROUND_ENABLE) generate
    dsp_out_shifted <= RESIZE(SHIFT_RIGHT_ROUND(dsp_out, OUTPUT_SHIFT_RIGHT),SHIFTED_WIDTH);
  end generate;

  -- shift right and round
  g_rnd_on : if (ROUND_ENABLE) generate
    dsp_out_shifted <= RESIZE(SHIFT_RIGHT_ROUND(dsp_out, OUTPUT_SHIFT_RIGHT, nearest),SHIFTED_WIDTH);
  end generate;

  -- clipping
  p_out : process(dsp_out_shifted, dsp_out_vld)
    variable v_dat : signed(OUTPUT_WIDTH-1 downto 0);
    variable v_ovf : std_logic;
  begin
    RESIZE_CLIP(din=>dsp_out_shifted, dout=>v_dat, ovfl=>v_ovf, clip=>OUTPUT_CLIP);
    rslt(0).vld <= dsp_out_vld;
    rslt(0).dat <= v_dat;
    if OUTPUT_OVERFLOW then
      -- enable output overflow detection only for valid output data
      rslt(0).ovf <= v_ovf and dsp_out_vld;
    else
      rslt(0).ovf <= '0';
    end if;
  end process;

  -- pipeline registers always in logic
  g_out : if PIPELINE_STAGES>=1 generate
    g_loop : for n in 1 to PIPELINE_STAGES generate
      rslt(n).vld <= (rslt(n-1).vld and (not rst)) when rising_edge(clk);
      rslt(n).ovf <= (rslt(n-1).ovf and (not rst)) when rising_edge(clk);
      -- data is not reset to keep reset fan-out low
      rslt(n).dat <=  rslt(n-1).dat when rising_edge(clk);
    end generate;
  end generate;

  -- map result to output port
  result <= rslt(PIPELINE_STAGES).dat;
  result_vld <= rslt(PIPELINE_STAGES).vld;
  result_ovf <= rslt(PIPELINE_STAGES).ovf;

end architecture;
